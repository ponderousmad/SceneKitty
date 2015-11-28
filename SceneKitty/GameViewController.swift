//
//  GameViewController.swift
//  SceneKitty
//
//  Created by Adrian Smith on 2015-11-23.
//  Copyright (c) 2015 Adrian Smith. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit
import GLKit
import CoreMotion

class GameViewController: UIViewController {
    
    let motionManager = CMMotionManager()
    let unworldNode = SCNNode()
    let xAccel = SCNNode()
    let yAccel = SCNNode()
    let zAccel = SCNNode()
    let accels = SCNNode()
    let gravity = SCNNode()
    let accelsTarget = SCNNode()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create a new scene
        let scene = SCNScene(named: "art.scnassets/Kitty.dae")!
        
        scene.rootNode.addChildNode(unworldNode)
        scene.rootNode.addChildNode(accels)
        
        // create and add a camera to the scene
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        
        unworldNode.addChildNode(cameraNode)
        unworldNode.position = SCNVector3(x: 0, y: 5, z: 0)
        
        // place the camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 0)
        
        cameraNode.addChildNode(accelsTarget)
        accelsTarget.position = SCNVector3(x: 0, y: 0, z: -3)
        
        // create and add a light to the scene
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = SCNLightTypeOmni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = SCNLightTypeAmbient
        ambientLightNode.light!.color = UIColor.darkGrayColor()
        scene.rootNode.addChildNode(ambientLightNode)
             
        constructArrow(xAccel, direction: SCNVector3(1,0,0))
        constructArrow(yAccel, direction: SCNVector3(0,1,0))
        constructArrow(zAccel, direction: SCNVector3(0,0,1))
        
        // retrieve the cat node
        let cat = scene.rootNode.childNodeWithName("kitty", recursively: true)!
        cat.position = SCNVector3(x: 5, y: 0, z: 5)
        
        // animate the 3d object
        //cat.runAction(SCNAction.repeatActionForever(SCNAction.rotateByX(0, y: 2, z: 0, duration: 1)))
        
        debugHeirarchy(cat)
        
        let compassScene = SCNScene(named: "art.scnassets/Compass.scn")!
        let compass = compassScene.rootNode.childNodeWithName("compass", recursively: true)!
        scene.rootNode.addChildNode(compass)
        
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        
        // set the scene to the view
        scnView.scene = scene
        
        // allows the user to manipulate the camera
        //scnView.allowsCameraControl = true
        
        // show statistics such as fps and timing information
        scnView.showsStatistics = true
        
        // configure the view
        scnView.backgroundColor = UIColor.blackColor()
        
        // add a tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: "handleTap:")
        scnView.addGestureRecognizer(tapGesture)
        
        motionManager.startDeviceMotionUpdatesUsingReferenceFrame(
            CMAttitudeReferenceFrame.XMagneticNorthZVertical,
            toQueue: NSOperationQueue.currentQueue()!,
            withHandler:handleMotion
        )
    }
    
    func constructArrow(node: SCNNode, direction: SCNVector3) {
        let color = UIColor(red: CGFloat(direction.x), green: CGFloat(direction.y), blue: CGFloat(direction.z), alpha: 1)
        accels.addChildNode(node)
        
        let point = SCNNode()
        point.geometry = SCNCone(topRadius: 0,bottomRadius: 0.2,height: 0.4)
        point.eulerAngles = SCNVector3(direction.z > 0 ? M_PI_2 : 0, 0, direction.x > 0 ? -M_PI_2 : 0)
        point.position = direction
        point.geometry?.firstMaterial?.diffuse.contents = color
        node.addChildNode(point)
        
        let line = SCNNode()
        line.geometry = SCNCylinder(radius: 0.1,height: 1)
        line.eulerAngles = point.eulerAngles
        line.position = SCNVector3(direction.x * 0.5, direction.y * 0.5, direction.z * 0.5)
        line.geometry?.firstMaterial?.diffuse.contents = color
        node.addChildNode(line)
    }
    
    func handleMotion(motion: CMDeviceMotion?, error: NSError?)
    {
        if let attitude = motion?.attitude {
            let orientation = GLKQuaternionMake(
                Float(attitude.quaternion.x),
                Float(attitude.quaternion.y),
                Float(attitude.quaternion.z),
                Float(attitude.quaternion.w)
            )
            let yUp = GLKQuaternionMakeWithAngleAndAxis(-Float(M_PI_2), 1, 0, 0)
            let product = GLKQuaternionMultiply(yUp, orientation)
            unworldNode.orientation = SCNQuaternion(product.x, product.y, product.z, product.w)
            
            let userAccel = motion!.userAcceleration
            let accel = GLKVector3Make(Float(userAccel.x), Float(userAccel.y), Float(userAccel.z))
            let worldAccel = GLKQuaternionRotateVector3(product, accel)
            xAccel.scale = SCNVector3(worldAccel.x, 1, 1)
            yAccel.scale = SCNVector3(1, worldAccel.y, 1)
            zAccel.scale = SCNVector3(1, 1, worldAccel.z)
            
            accels.position = accelsTarget.convertPosition(SCNVector3(0,0,0), toNode: unworldNode.parentNode!)
        }
    }
    
    func handleTap(gestureRecognize: UIGestureRecognizer) {
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        
        // check what nodes are tapped
        let p = gestureRecognize.locationInView(scnView)
        let hitResults = scnView.hitTest(p, options: nil)
        // check that we clicked on at least one object
        if hitResults.count > 0 {
            // retrieved the first clicked object
            let result: AnyObject! = hitResults[0]
            
            // get its material
            let material = result.node!.geometry!.firstMaterial!
            
            // highlight it
            SCNTransaction.begin()
            SCNTransaction.setAnimationDuration(0.5)
            
            // on completion - unhighlight
            SCNTransaction.setCompletionBlock {
                SCNTransaction.begin()
                SCNTransaction.setAnimationDuration(0.5)
                
                material.emission.contents = UIColor.blackColor()
                
                SCNTransaction.commit()
            }
            
            material.emission.contents = UIColor.redColor()
            
            SCNTransaction.commit()
        }
    }
    
    func debugHeirarchy(node: SCNNode, indent: String = "")
    {
        print(indent + (node.name ?? "unnamed"))
        for child in node.childNodes {
            debugHeirarchy(child, indent: indent + "  ")
        }
    }
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
            return .AllButUpsideDown
        } else {
            return .All
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

}
