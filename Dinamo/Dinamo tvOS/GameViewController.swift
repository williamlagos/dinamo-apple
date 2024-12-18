//
//  GameViewController.swift
//  Dinamo tvOS
//
//  Created by William Oliveira de Lagos on 15.11.24.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let skView = self.view as? SKView {
            if let scene = SKScene(fileNamed: "GameScene") {
                scene.scaleMode = .aspectFill
                skView.presentScene(scene)
            }
        }

        // Add swipe gesture recognizers
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
    }

    @objc func handleSwipe(_ sender: UISwipeGestureRecognizer) {
        if let skView = view as? SKView, let scene = skView.scene as? GameScene {
            switch sender.direction {
            case .left:
                scene.handleSwipe(direction: .left)
            case .right:
                scene.handleSwipe(direction: .right)
            default:
                break
            }
        }
    }
}
