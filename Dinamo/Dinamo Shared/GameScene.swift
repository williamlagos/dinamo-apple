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
        setupGame()
    }
    
    func setupGame() {
        // Remove all existing children to ensure a clean restart
        removeAllChildren()
        
        score = 0
        
        // Add player
        player = SKSpriteNode(color: .red, size: CGSize(width: 32, height: 32))
        player.name = "Player"
        player.position = CGPoint(x: 0, y: -size.height / 4)
        addChild(player)

        // Add score label
        scoreLabel = SKLabelNode(text: "Score: \(score)")
        scoreLabel.name = "Score"
        scoreLabel.position = CGPoint(x: 0, y: size.height / 2 - 50)
        addChild(scoreLabel)

        // Start spawning obstacles
        run(SKAction.repeatForever(SKAction.sequence([
            SKAction.run(spawnObstacle),
            SKAction.wait(forDuration: 1.0)
        ])), withKey: "spawnObstacles")
        
        // Resume game
        isPaused = false
    }

    func spawnObstacle() {
        let obstacle = SKSpriteNode(color: .white, size: CGSize(width: 32, height: 32))
        obstacle.position = CGPoint(x: CGFloat.random(in: -size.width/2...size.width/2), y: size.height)

        addChild(obstacle)

        let moveDown = SKAction.moveBy(x: 0, y: -size.height*2, duration: 5.0)
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
        // Stop spawning obstacles and pause the game
        isPaused = true
        removeAction(forKey: "spawnObstacles")
        
        // Update score label to show "Game Over" message
        scoreLabel.text = "Game Over! Score: \(score)"
        
        // Allow user to restart the game with a tap
        let restartLabel = SKLabelNode(text: "Tap anywhere to restart")
        restartLabel.position = CGPoint(x: 0, y: -50)
        restartLabel.name = "RestartLabel"
        addChild(restartLabel)
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
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isPaused {
            // Restart the game on touch if the game is paused
            setupGame()
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
        if isPaused {
            setupGame()
        } else {
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
        
    }

    override func keyUp(with event: NSEvent) {
        // Handle key release if needed, such as stopping movement
    }
    
    override func mouseDown(with event: NSEvent) {
        if isPaused {
            setupGame()
        } else {
            let location = event.location(in: self)
            player.position = location
        }
        
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = event.location(in: self)
        player.position = location
    }
}
#endif

