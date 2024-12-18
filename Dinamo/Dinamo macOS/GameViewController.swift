//
//  GameViewController.swift
//  Dinamo macOS
//
//  Created by William Oliveira de Lagos on 15.11.24.
//

import Cocoa
import SpriteKit
import GameplayKit

class GameViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Cast the view to SKView
        if let skView = self.view as? SKView {
            // Load the GameScene
//            let scene = GameScene(size: CGSize(width: 800, height: 600))
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

}

