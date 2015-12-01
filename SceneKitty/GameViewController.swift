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
    var accelTotal = SCNNode()
    let accels = SCNNode()
    let gravity = SCNNode()
    let accelsTarget = SCNNode()
    
    let velocities = SCNNode()
    var location = SCNNode();
    var position = SCNVector3(0,0,0)
    var velocity = SCNVector3(0,0,0)
    var lastTime = NSDate()

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
        
        accels.addChildNode(accelTotal)
        accels.addChildNode(constructArrow(xAccel, direction: SCNVector3(1,0,0)))
        accels.addChildNode(constructArrow(yAccel, direction: SCNVector3(0,1,0)))
        accels.addChildNode(constructArrow(zAccel, direction: SCNVector3(0,0,1)))
        
        // retrieve the cat node
        let cat = scene.rootNode.childNodeWithName("kitty", recursively: true)!
        cat.position = SCNVector3(x: 5, y: 0, z: 5)
        
        // animate the 3d object
        //cat.runAction(SCNAction.repeatActionForever(SCNAction.rotateByX(0, y: 2, z: 0, duration: 1)))
        
        debugHeirarchy(cat)
        
        let compassScene = SCNScene(named: "art.scnassets/Compass.scn")!
        let compass = compassScene.rootNode.childNodeWithName("compass", recursively: true)!
        scene.rootNode.addChildNode(compass)
        
        scene.rootNode.addChildNode(velocities)
        scene.rootNode.addChildNode(location)
        
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
        
        lastTime = NSDate()
        motionManager.startDeviceMotionUpdatesUsingReferenceFrame(
            CMAttitudeReferenceFrame.XMagneticNorthZVertical,
            toQueue: NSOperationQueue.currentQueue()!,
            withHandler:handleMotion
        )
    }
    
    func constructArrow(direction: SCNVector3) -> SCNNode
    {
        let node = SCNNode()
        return constructArrow(node, direction: direction)    }
    
    func constructArrow(node: SCNNode, direction: SCNVector3) -> SCNNode {
        let color = UIColor(red: CGFloat(direction.x), green: CGFloat(direction.y), blue: CGFloat(direction.z), alpha: 1)
        
        let point = SCNNode()
        point.geometry = SCNCone(topRadius: 0,bottomRadius: 0.2,height: 0.4)
        point.position = SCNVector3(0, 1, 0)
        point.geometry?.firstMaterial?.diffuse.contents = color
        node.addChildNode(point)
        
        let line = SCNNode()
        line.geometry = SCNCylinder(radius: 0.1,height: 1)
        line.position = SCNVector3(0, 0.5, 0)
        line.geometry?.firstMaterial?.diffuse.contents = color
        node.addChildNode(line)
        
        let up = GLKVector3Make(0, 1, 0)
        let glDir = SCNVector3ToGLKVector3(direction)
        let angle = acos(GLKVector3DotProduct(up, glDir))
        if angle == Float(M_PI) {
            let orientation = GLKQuaternionMakeWithAngleAndVector3Axis(Float(M_PI), GLKVector3Make(1, 0, 0))
            node.orientation = SCNQuaternion(orientation.x, orientation.y, orientation.z, orientation.w)
        }
        else if angle > 0 {
            let cross = GLKVector3CrossProduct(up, glDir)
            let orientation = GLKQuaternionMakeWithAngleAndVector3Axis(angle, cross)
            node.orientation = SCNQuaternion(orientation.x, orientation.y, orientation.z, orientation.w)
        }
        return node
    }
    
    func length(vector : SCNVector3) -> Float {
        return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z);
    }
    
    func multiply(vector : SCNVector3, by scale: Float) -> SCNVector3 {
        return SCNVector3Make(vector.x * scale, vector.y * scale, vector.z * scale)
    }
    
    func add(a : SCNVector3,_ b : SCNVector3) -> SCNVector3 {
        return SCNVector3Make(a.x + b.x, a.y + b.y, a.z + b.z)
    }
    
    func sub(a : SCNVector3, minus b : SCNVector3) -> SCNVector3 {
        return SCNVector3Make(a.x + b.x, a.y + b.y, a.z + b.z)
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
            let worldAccel = SCNVector3FromGLKVector3(GLKQuaternionRotateVector3(product, accel))
            
            xAccel.scale.y = worldAccel.x
            yAccel.scale.y = worldAccel.y
            zAccel.scale.y = worldAccel.z
            
            let total = constructArrow(worldAccel)
            total.scale.y = length(worldAccel)
            accels.replaceChildNode(accelTotal, with: total)
            accelTotal = total
            
            let now = NSDate()
            let elapsed = Float(now.timeIntervalSinceDate(lastTime))
            lastTime = now
            
            velocity = add(velocity, multiply(worldAccel, by: elapsed))
            let speed = length(velocity)
            if speed != 0 {
                let newVelocity = constructArrow(multiply(velocity, by: 1 / speed))
                
                newVelocity.scale.y = speed
                if velocities.childNodes.count > 0 {
                    velocities.childNodes[0].removeFromParentNode()
                }
                velocities.addChildNode(newVelocity)
            }
            
            accels.position = accelsTarget.convertPosition(SCNVector3(0,0,0), toNode: unworldNode.parentNode!)
            velocities.position = accels.position
            position = add(position, multiply(velocity, by: elapsed))
            let step = constructArrow(position)
            step.scale.y = length(position)
            let root = location.parentNode
            location.removeFromParentNode()
            root?.addChildNode(step)
            location = step        }
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
