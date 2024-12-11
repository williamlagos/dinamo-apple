//
//  GameScene.swift
//  Dinamo Shared
//
//  Created by William Oliveira de Lagos on 15.11.24.
//

import SpriteKit

class GameScene: SKScene {
    
    var player: SKSpriteNode!
    var scoreLabel: SKLabelNode!
    var score = 0

    override func didMove(to view: SKView) {
       backgroundColor = .blue

       // Add player
       player = SKSpriteNode(color: .red, size: CGSize(width: 50, height: 50))
       player.position = CGPoint(x: size.width / 2, y: 100)
       addChild(player)

       // Add score label
       scoreLabel = SKLabelNode(fontNamed: "Chalkduster")
       scoreLabel.text = "Score: 0"
       scoreLabel.fontSize = 24
       scoreLabel.fontColor = .white
       scoreLabel.position = CGPoint(x: size.width / 2, y: size.height - 50)
       addChild(scoreLabel)

       // Start spawning obstacles
       run(SKAction.repeatForever(SKAction.sequence([
           SKAction.run(spawnObstacle),
           SKAction.wait(forDuration: 1.0)
       ])))
    }

    func spawnObstacle() {
       let obstacle = SKSpriteNode(color: .black, size: CGSize(width: 30, height: 30))
       obstacle.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height)
       addChild(obstacle)

       let moveDown = SKAction.moveBy(x: 0, y: -size.height, duration: 5.0)
       let remove = SKAction.removeFromParent()
       obstacle.run(SKAction.sequence([moveDown, remove]))
    }

    override func update(_ currentTime: TimeInterval) {
       for node in children {
           if node != player && node != scoreLabel && player.frame.intersects(node.frame) {
               gameOver()
           }
       }
    }

    func gameOver() {
       isPaused = true
       scoreLabel.text = "Game Over! Score: \(score)"
    }
}

#if os(iOS) || os(tvOS)
enum SwipeDirection {
    case left
    case right
}

// Touch-based event handling
extension GameScene {
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: self)
            player.position.x = location.x
        }
    }

    func handleSwipe(direction: SwipeDirection) {
        switch direction {
        case .left:
            player.position.x -= 50
        case .right:
            player.position.x += 50
        }
    }
}
#endif

#if os(OSX)
// Mouse-based event handling
extension GameScene {
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123: // Left arrow key
            player.position.x -= 20
        case 124: // Right arrow key
            player.position.x += 20
        case 125: // Down arrow key
            player.position.y -= 20
        case 126: // Up arrow key
            player.position.y += 20
        default:
            break
        }
    }

    override func keyUp(with event: NSEvent) {
        // Handle key release if needed, such as stopping movement
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        player.position = location
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = event.location(in: self)
        player.position = location
    }
}
#endif

