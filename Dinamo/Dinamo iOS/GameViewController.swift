//
//  GameViewController.swift
//  Dinamo iOS
//
//  Created by William Oliveira de Lagos on 15.11.24.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Cast the view to SKView
        if let skView = self.view as? SKView {
            // Load the GameScene
            if let scene = SKScene(fileNamed: "GameScene") {
                // Configure the scene
                scene.scaleMode = .resizeFill
                
                // Present the scene in the SKView
                skView.presentScene(scene)
            }
            
            // Optional: Debugging options
            skView.ignoresSiblingOrder = true
            skView.showsFPS = true
            skView.showsNodeCount = true
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    // Hide the status bar for full-screen gaming
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
