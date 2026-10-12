//
//  GameScene.swift
//  Dinamo Shared
//
//  Galaga 1981 Retro Arcade Engine for Apple Platforms (iOS, macOS, tvOS)
//

import SpriteKit
import AVFoundation

#if canImport(GameController)
import GameController
#endif

// MARK: - Enums & Data Structures

enum EnemyType {
    case bee
    case butterfly
    case boss
}

enum EnemyState {
    case entering
    case formation
    case diving
    case returning
}

#if os(iOS) || os(tvOS)
enum SwipeDirection {
    case left
    case right
}
#endif

class EnemyNode: SKSpriteNode {
    var enemyType: EnemyType = .bee
    var state: EnemyState = .entering
    var targetSlot: CGPoint = .zero
    var health: Int = 1
    var hasFired: Bool = false
    var frameIndex: Int = 1
    var diveTargetX: CGFloat = 0
}

// MARK: - Procedural Retro Sound Engine
class SoundEngine {
    static let shared = SoundEngine()
    var isMuted = false
    private var audioEngine = AVAudioEngine()
    private var isEngineRunning = false

    init() {
        setupAudio()
    }

    private func setupAudio() {
        #if os(iOS) || os(tvOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioSession setup error: \(error)")
        }
        #endif
    }

    // Generate short sound waveform in memory and play via AVAudioPlayer
    func playTone(freqStart: Double, freqEnd: Double, duration: Double, isNoise: Bool = false) {
        guard !isMuted else { return }

        DispatchQueue.global(qos: .userInteractive).async {
            let sampleRate = 44100.0
            let numSamples = Int(sampleRate * duration)
            var samples = [Float](repeating: 0, count: numSamples)

            if isNoise {
                // White noise burst with decay
                for i in 0..<numSamples {
                    let progress = Double(i) / Double(numSamples)
                    let decay = Float(exp(-progress * 6.0))
                    let raw = Float.random(in: -1.0...1.0)
                    samples[i] = raw * decay * 0.4
                }
            } else {
                // Pitch slide (chirp / laser / swoop)
                var phase = 0.0
                for i in 0..<numSamples {
                    let progress = Double(i) / Double(numSamples)
                    let currentFreq = freqStart + (freqEnd - freqStart) * progress
                    let decay = Float(exp(-progress * 4.0))
                    phase += 2.0 * Double.pi * currentFreq / sampleRate
                    let wave = Float(sin(phase) > 0 ? 0.3 : -0.3) // Square wave for 8-bit sound
                    samples[i] = wave * decay
                }
            }

            // Create WAV format data
            guard let wavData = self.createWavData(samples: samples, sampleRate: Int(sampleRate)) else { return }

            DispatchQueue.main.async {
                do {
                    let player = try AVAudioPlayer(data: wavData)
                    player.play()
                    // Retain player until completion
                    objc_setAssociatedObject(self, "audio_\(arc4random())", player, .OBJC_ASSOCIATION_RETAIN)
                } catch {
                    // Fallback silently if audio player fails
                }
            }
        }
    }

    func playLaser() {
        playTone(freqStart: 900, freqEnd: 150, duration: 0.12)
    }

    func playExplosion() {
        playTone(freqStart: 0, freqEnd: 0, duration: 0.28, isNoise: true)
    }

    func playDive() {
        playTone(freqStart: 580, freqEnd: 280, duration: 0.35)
    }

    func playPlayerDeath() {
        playTone(freqStart: 0, freqEnd: 0, duration: 0.55, isNoise: true)
    }

    private func createWavData(samples: [Float], sampleRate: Int) -> Data? {
        var data = Data()
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate: Int32 = Int32(sampleRate * Int(numChannels) * Int(bitsPerSample / 8))
        let blockAlign: Int16 = numChannels * (bitsPerSample / 8)
        let subChunk2Size: Int32 = Int32(samples.count * Int(bitsPerSample / 8))
        let chunkSize: Int32 = 36 + subChunk2Size

        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)

        let subChunk1Size: Int32 = 16
        let audioFormat: Int16 = 1 // PCM
        data.append(contentsOf: withUnsafeBytes(of: subChunk1Size.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: audioFormat.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: Int32(sampleRate).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: subChunk2Size.littleEndian) { Array($0) })

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let intSample = Int16(clamped * 32767.0)
            data.append(contentsOf: withUnsafeBytes(of: intSample.littleEndian) { Array($0) })
        }

        return data
    }
}

// MARK: - Procedural Texture Generator
class RetroTextures {
    static let shared = RetroTextures()

    var player: SKTexture!
    var playerMini: SKTexture!
    var bee1: SKTexture!
    var bee2: SKTexture!
    var butterfly1: SKTexture!
    var butterfly2: SKTexture!
    var bossGreen1: SKTexture!
    var bossGreen2: SKTexture!
    var bossBlue1: SKTexture!
    var bossBlue2: SKTexture!
    var playerLaser: SKTexture!
    var alienBullet: SKTexture!
    var explosions: [SKTexture] = []

    init() {
        generateAll()
    }

    private func createTexture(width: Int, height: Int, pixels: [String], colors: [Character: (CGFloat, CGFloat, CGFloat)], scale: Int = 2) -> SKTexture {
        let outW = width * scale
        let outH = height * scale
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(data: nil, width: outW, height: outH, bitsPerComponent: 8, bytesPerRow: outW * 4, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return SKTexture()
        }

        context.setAllowsAntialiasing(false)
        context.interpolationQuality = .none

        for y in 0..<height {
            let rowIdx = height - 1 - y // Flip vertically for CGContext
            guard rowIdx < pixels.count else { continue }
            let row = Array(pixels[rowIdx])

            for x in 0..<width {
                guard x < row.count else { continue }
                let char = row[x]
                if let rgb = colors[char] {
                    context.setFillColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1.0)
                    context.fill(CGRect(x: x * scale, y: y * scale, width: scale, height: scale))
                }
            }
        }

        guard let cgImage = context.makeImage() else { return SKTexture() }
        let tex = SKTexture(cgImage: cgImage)
        tex.filteringMode = .nearest
        return tex
    }

    private func generateAll() {
        let colors: [Character: (CGFloat, CGFloat, CGFloat)] = [
            "W": (1.0, 1.0, 1.0),
            "R": (1.0, 0.15, 0.15),
            "B": (0.15, 0.5, 1.0),
            "Y": (1.0, 0.88, 0.0),
            "G": (0.0, 0.88, 0.25),
            "C": (0.15, 1.0, 1.0),
            "O": (1.0, 0.55, 0.0),
        ]

        let playerPixels = [
            "       W       ",
            "       W       ",
            "      BWB      ",
            "      BWB      ",
            "     WWBWB     ",
            "     WWWWW     ",
            "    WWWWWWW    ",
            "    WWWRWWW    ",
            " R WWWWWWWWWR  ",
            "RR WWWWWWWWWRR ",
            "RR WWWRRRWWW RR",
            "RRWWWW   WWWW RR",
            " RRR       RRR ",
            " R           R ",
            "               ",
            "               ",
        ]
        player = createTexture(width: 15, height: 16, pixels: playerPixels, colors: colors, scale: 2)
        playerMini = createTexture(width: 15, height: 16, pixels: playerPixels, colors: colors, scale: 1)

        let bee1Pixels = [
            "      YYYY      ",
            "    YYRRRRYY    ",
            "   YYYRRRRYYY   ",
            "   YY RRRR YY   ",
            "  YYYYYYYYYYYY  ",
            " YYYYYYWWYYYYYY ",
            " YYY YYYYYY YYY ",
            "YYYY YY  YY YYYY",
            "YYYY   YY   YYYY",
            " YYYY  YY  YYYY ",
            "  YYYYYYYYYYYY  ",
            "   YYRRRRYY     ",
            "    YYRRYY      ",
            "     YYYY       ",
            "      YY        ",
            "                ",
        ]
        let bee2Pixels = [
            "      YYYY      ",
            "    YYRRRRYY    ",
            "  YYYYRRRRYYYY  ",
            " YYYY RRRR YYYY ",
            " YYYYYYYYYYYYYY ",
            "  YYYYYWWYYYYY  ",
            "  YY YYYYYY YY  ",
            "   Y YY  YY Y   ",
            "   Y   YY   Y   ",
            "   YY  YY  YY   ",
            "  YYYYYYYYYYYY  ",
            "   YYRRRRYY     ",
            "    YYRRYY      ",
            "     YYYY       ",
            "      YY        ",
            "                ",
        ]
        bee1 = createTexture(width: 16, height: 16, pixels: bee1Pixels, colors: colors, scale: 2)
        bee2 = createTexture(width: 16, height: 16, pixels: bee2Pixels, colors: colors, scale: 2)

        let bfly1Pixels = [
            "      CCCC      ",
            "    CCRRRRCC    ",
            "   CCCRRRRCCC   ",
            "  CCCCRRRRCCCC  ",
            " CCCCCRRRRCCCCC ",
            " CCCCCWWWWCCCCC ",
            " CCCCCRRRRCCCCC ",
            "  CC RRRRRR CC  ",
            "   RRR    RRR   ",
            "  RRRR    RRRR  ",
            " RRRRR    RRRRR ",
            " RRR        RRR ",
            "  RR        RR  ",
            "   R        R   ",
            "                ",
            "                ",
        ]
        let bfly2Pixels = [
            "      CCCC      ",
            "    CCRRRRCC    ",
            "  CCCCRRRRCCCC  ",
            " CCC CCRRCC CCC ",
            "CCCC CCRRCC CCCC",
            "CCCC CWWWWCC CCCC",
            " CCC CCRRCC CCC ",
            "  CC RRRRRR CC  ",
            "  RRRR    RRRR  ",
            " RRRRR    RRRRR ",
            " RRR        RRR ",
            "  RR        RR  ",
            "   R        R   ",
            "                ",
            "                ",
            "                ",
        ]
        butterfly1 = createTexture(width: 16, height: 16, pixels: bfly1Pixels, colors: colors, scale: 2)
        butterfly2 = createTexture(width: 16, height: 16, pixels: bfly2Pixels, colors: colors, scale: 2)

        let bossG1Pixels = [
            "      GGGG      ",
            "    GGYYYYGG    ",
            "   GGGYYYYGGG   ",
            "  GGGGYYYYGGGG  ",
            " GGGGGGGGGGGGGG ",
            " GGGGYYWWYYGGGG ",
            " GGG GGGGGG GGG ",
            "GGG  GG  GG  GGG",
            "GG   GGGGGG   GG",
            "GG   GGGGGG   GG",
            " GGG  GGGG  GGG ",
            "  GGGG    GGGG  ",
            "   GGG    GGG   ",
            "    GG    GG    ",
            "     G    G     ",
            "                ",
        ]
        let bossG2Pixels = [
            "      GGGG      ",
            "    GGYYYYGG    ",
            "  GGGGYYYYGGGG  ",
            " GGG GYYYYG GGG ",
            "GGGG GGGGGG GGGG",
            "GGGG YYWWYY GGGG",
            " GGG GGGGGG GGG ",
            " GGG GG  GG GGG ",
            "  GG GGGGGG GG  ",
            "  GG GGGGGG GG  ",
            "   GG GGGG GG   ",
            "   GG      GG   ",
            "    G      G    ",
            "                ",
            "                ",
            "                ",
        ]
        bossGreen1 = createTexture(width: 16, height: 16, pixels: bossG1Pixels, colors: colors, scale: 2)
        bossGreen2 = createTexture(width: 16, height: 16, pixels: bossG2Pixels, colors: colors, scale: 2)

        let bossB1Pixels = bossG1Pixels.map { $0.replacingOccurrences(of: "G", with: "B") }
        let bossB2Pixels = bossG2Pixels.map { $0.replacingOccurrences(of: "G", with: "B") }
        bossBlue1 = createTexture(width: 16, height: 16, pixels: bossB1Pixels, colors: colors, scale: 2)
        bossBlue2 = createTexture(width: 16, height: 16, pixels: bossB2Pixels, colors: colors, scale: 2)

        let laserPixels = ["R R", "Y Y", "Y Y", "W W", "W W", "Y Y", "Y Y", "R R"]
        playerLaser = createTexture(width: 3, height: 8, pixels: laserPixels, colors: colors, scale: 2)

        let bulletPixels = [" O ", "OOO", "OWO", "OOO", " O "]
        alienBullet = createTexture(width: 3, height: 5, pixels: bulletPixels, colors: colors, scale: 2)

        let exp1 = ["  W  "]
        let exp2 = ["  Y  ", " YWY ", "  Y  "]
        let exp3 = [" R O R ", "  YWY  ", "OW W WO", "  YWY  ", " R O R "]
        let exp4 = ["R  O  R", " Y   Y ", "O  W  O", " Y   Y ", "R  O  R"]
        explosions = [
            createTexture(width: 5, height: 1, pixels: exp1, colors: colors, scale: 3),
            createTexture(width: 5, height: 3, pixels: exp2, colors: colors, scale: 3),
            createTexture(width: 7, height: 5, pixels: exp3, colors: colors, scale: 3),
            createTexture(width: 7, height: 5, pixels: exp4, colors: colors, scale: 3),
        ]
    }
}

// MARK: - GameScene Main Class

class GameScene: SKScene {

    // Scene & Display Layers
    private var starLayer = SKNode()
    private var gameLayer = SKNode()
    private var hudLayer = SKNode()

    // Entities
    private var player: SKSpriteNode!
    private var enemies: [EnemyNode] = []
    private var playerMissiles: [SKSpriteNode] = []
    private var alienBullets: [SKSpriteNode] = []
    private var lifeIcons: [SKSpriteNode] = []

    // HUD Labels
    private var scoreLabel: SKLabelNode!
    private var highScoreLabel: SKLabelNode!
    private var stageLabel: SKLabelNode!
    private var messageLabel: SKLabelNode!

    // State Variables
    private var score = 0
    private var highScore = 20000
    private var lives = 3
    private var stage = 1
    private var isGameOverState = false
    private var isStageIntro = false
    private var isPlayerDead = false
    private var invulnerableTime: TimeInterval = 0
    private var formationTime: TimeInterval = 0
    private var diveTimer: TimeInterval = 0
    private var wingFlapTimer: TimeInterval = 0
    private var currentWingFrame = 1

    // Controls
    private var moveLeft = false
    private var moveRight = false
    private var isFiring = false
    private var fireCooldown: TimeInterval = 0

    // Wave Entrance Queue
    private struct WaveSpawn {
        let type: EnemyType
        let row: Int
        let col: Int
        let pathType: String
        let delay: TimeInterval
    }
    private var waveQueue: [WaveSpawn] = []
    private var spawnTimer: TimeInterval = 0

    // Stars
    private var stars: [(node: SKShapeNode, speed: CGFloat)] = []

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = SKColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0)

        // Setup Scene Layers
        addChild(starLayer)
        addChild(gameLayer)
        addChild(hudLayer)

        setupStarfield()
        setupHUD()
        setupPlayer()
        setupGameControllers()

        startNewGame()
    }

    private func setupStarfield() {
        starLayer.removeAllChildren()
        stars.removeAll()

        let colors: [SKColor] = [.white, .cyan, .yellow, .red]
        for _ in 0..<80 {
            let size: CGFloat = CGFloat.random(in: 1.0...2.5)
            let star = SKShapeNode(rectOf: CGSize(width: size, height: size))
            star.fillColor = colors.randomElement() ?? .white
            star.strokeColor = .clear
            star.position = CGPoint(
                x: CGFloat.random(in: -sizeWidth / 2...sizeWidth / 2),
                y: CGFloat.random(in: -sizeHeight / 2...sizeHeight / 2)
            )
            starLayer.addChild(star)
            stars.append((node: star, speed: CGFloat.random(in: 40...160)))
        }
    }

    private var sizeWidth: CGFloat {
        return size.width > 0 ? size.width : 448
    }

    private var sizeHeight: CGFloat {
        return size.height > 0 ? size.height : 640
    }

    private func setupHUD() {
        hudLayer.removeAllChildren()

        let font = "Courier-Bold"

        let oneUpTitle = SKLabelNode(fontNamed: font)
        oneUpTitle.text = "1UP"
        oneUpTitle.fontSize = 14
        oneUpTitle.fontColor = .red
        oneUpTitle.position = CGPoint(x: -sizeWidth / 2 + 50, y: sizeHeight / 2 - 35)
        hudLayer.addChild(oneUpTitle)

        scoreLabel = SKLabelNode(fontNamed: font)
        scoreLabel.text = "00"
        scoreLabel.fontSize = 14
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: -sizeWidth / 2 + 50, y: sizeHeight / 2 - 55)
        hudLayer.addChild(scoreLabel)

        let highTitle = SKLabelNode(fontNamed: font)
        highTitle.text = "HIGH SCORE"
        highTitle.fontSize = 14
        highTitle.fontColor = .red
        highTitle.position = CGPoint(x: 0, y: sizeHeight / 2 - 35)
        hudLayer.addChild(highTitle)

        highScoreLabel = SKLabelNode(fontNamed: font)
        highScoreLabel.text = "\(highScore)"
        highScoreLabel.fontSize = 14
        highScoreLabel.fontColor = .white
        highScoreLabel.position = CGPoint(x: 0, y: sizeHeight / 2 - 55)
        hudLayer.addChild(highScoreLabel)

        stageLabel = SKLabelNode(fontNamed: font)
        stageLabel.text = "STAGE 1"
        stageLabel.fontSize = 14
        stageLabel.fontColor = .red
        stageLabel.position = CGPoint(x: sizeWidth / 2 - 60, y: sizeHeight / 2 - 55)
        hudLayer.addChild(stageLabel)

        messageLabel = SKLabelNode(fontNamed: font)
        messageLabel.text = ""
        messageLabel.fontSize = 22
        messageLabel.fontColor = .yellow
        messageLabel.position = .zero
        messageLabel.numberOfLines = 3
        hudLayer.addChild(messageLabel)

        updateLifeIcons()
    }

    private func updateLifeIcons() {
        lifeIcons.forEach { $0.removeFromParent() }
        lifeIcons.removeAll()

        for i in 0..<max(0, lives - 1) {
            let icon = SKSpriteNode(texture: RetroTextures.shared.playerMini)
            icon.position = CGPoint(x: -sizeWidth / 2 + 30 + CGFloat(i * 22), y: -sizeHeight / 2 + 25)
            hudLayer.addChild(icon)
            lifeIcons.append(icon)
        }
    }

    private func setupPlayer() {
        player = SKSpriteNode(texture: RetroTextures.shared.player)
        player.position = CGPoint(x: 0, y: -sizeHeight / 2 + 65)
        player.name = "Player"
        gameLayer.addChild(player)
    }

    func startNewGame() {
        score = 0
        lives = 3
        stage = 1
        isGameOverState = false
        isPlayerDead = false
        isPaused = false

        enemies.forEach { $0.removeFromParent() }
        enemies.removeAll()
        playerMissiles.forEach { $0.removeFromParent() }
        playerMissiles.removeAll()
        alienBullets.forEach { $0.removeFromParent() }
        alienBullets.removeAll()

        updateLifeIcons()
        scoreLabel.text = "00"
        player.isHidden = false
        player.position = CGPoint(x: 0, y: -sizeHeight / 2 + 65)

        startStage(stageNumber: stage)
    }

    private func startStage(stageNumber: Int) {
        stage = stageNumber
        stageLabel.text = "STAGE \(stage)"
        isStageIntro = true
        messageLabel.text = "STAGE \(stage)\n\nREADY"
        messageLabel.isHidden = false

        SoundEngine.shared.playTone(freqStart: 260, freqEnd: 520, duration: 0.4)

        buildWaveQueue()

        let waitAction = SKAction.wait(forDuration: 2.2)
        let finishIntro = SKAction.run { [weak self] in
            self?.isStageIntro = false
            self?.messageLabel.isHidden = true
        }
        run(SKAction.sequence([waitAction, finishIntro]))
    }

    private func getFormationSlot(row: Int, col: Int) -> CGPoint {
        let colSpacing: CGFloat = 34
        let rowSpacing: CGFloat = 26
        let startX: CGFloat = -CGFloat(10 - 1) * colSpacing / 2.0
        let startY: CGFloat = sizeHeight / 2 - 120

        return CGPoint(
            x: startX + CGFloat(col) * colSpacing,
            y: startY - CGFloat(row) * rowSpacing
        )
    }

    private func buildWaveQueue() {
        waveQueue.removeAll()

        let w1: [(EnemyType, Int, Int, String)] = [
            (.boss, 0, 4, "topLeft"), (.boss, 0, 5, "topRight"),
            (.boss, 0, 3, "topLeft"), (.boss, 0, 6, "topRight"),
            (.butterfly, 1, 4, "topLeft"), (.butterfly, 1, 5, "topRight"),
            (.butterfly, 1, 3, "topLeft"), (.butterfly, 1, 6, "topRight"),
        ]

        let w2: [(EnemyType, Int, Int, String)] = [
            (.butterfly, 1, 1, "leftSide"), (.butterfly, 1, 8, "rightSide"),
            (.butterfly, 1, 2, "leftSide"), (.butterfly, 1, 7, "rightSide"),
            (.bee, 2, 4, "leftSide"), (.bee, 2, 5, "rightSide"),
            (.bee, 2, 3, "leftSide"), (.bee, 2, 6, "rightSide"),
        ]

        let w3: [(EnemyType, Int, Int, String)] = [
            (.bee, 2, 1, "topLeft"), (.bee, 2, 8, "topRight"),
            (.bee, 2, 2, "topLeft"), (.bee, 2, 7, "topRight"),
            (.bee, 3, 4, "topLeft"), (.bee, 3, 5, "topRight"),
            (.bee, 3, 3, "topLeft"), (.bee, 3, 6, "topRight"),
        ]

        let w4: [(EnemyType, Int, Int, String)] = [
            (.bee, 3, 0, "leftSide"), (.bee, 3, 9, "rightSide"),
            (.bee, 3, 1, "leftSide"), (.bee, 3, 8, "rightSide"),
            (.bee, 3, 2, "leftSide"), (.bee, 3, 7, "rightSide"),
        ]

        let all = w1 + w2 + w3 + w4
        for (idx, item) in all.enumerated() {
            waveQueue.append(WaveSpawn(
                type: item.0,
                row: item.1,
                col: item.2,
                pathType: item.3,
                delay: 0.2 + Double(idx) * 0.22
            ))
        }
    }

    private func spawnEnemy(spawn: WaveSpawn) {
        let slot = getFormationSlot(row: spawn.row, col: spawn.col)

        var texture = RetroTextures.shared.bee1
        var health = 1
        if spawn.type == .butterfly {
            texture = RetroTextures.shared.butterfly1
        } else if spawn.type == .boss {
            texture = RetroTextures.shared.bossGreen1
            health = 2
        }

        let enemy = EnemyNode(texture: texture)
        enemy.enemyType = spawn.type
        enemy.targetSlot = slot
        enemy.health = health
        enemy.state = .entering

        let path = createEntrancePath(type: spawn.pathType, target: slot)
        enemy.position = path.currentPoint
        gameLayer.addChild(enemy)
        enemies.append(enemy)

        let follow = SKAction.follow(path, asOffset: false, orientToPath: true, duration: 2.8)
        let lockIn = SKAction.run { [weak enemy] in
            enemy?.state = .formation
            enemy?.zRotation = 0
        }
        enemy.run(SKAction.sequence([follow, lockIn]))
    }

    private func createEntrancePath(type: String, target: CGPoint) -> CGPath {
        let path = CGMutablePath()

        switch type {
        case "topLeft":
            path.move(to: CGPoint(x: -sizeWidth / 2 - 20, y: sizeHeight / 2 - 60))
            path.addCurve(to: CGPoint(x: 40, y: 0),
                          control1: CGPoint(x: -40, y: sizeHeight / 4),
                          control2: CGPoint(x: 80, y: 80))
            path.addCurve(to: target,
                          control1: CGPoint(x: 0, y: -80),
                          control2: CGPoint(x: target.x, y: target.y + 60))
        case "topRight":
            path.move(to: CGPoint(x: sizeWidth / 2 + 20, y: sizeHeight / 2 - 60))
            path.addCurve(to: CGPoint(x: -40, y: 0),
                          control1: CGPoint(x: 40, y: sizeHeight / 4),
                          control2: CGPoint(x: -80, y: 80))
            path.addCurve(to: target,
                          control1: CGPoint(x: 0, y: -80),
                          control2: CGPoint(x: target.x, y: target.y + 60))
        case "leftSide":
            path.move(to: CGPoint(x: -sizeWidth / 2 - 30, y: -60))
            path.addCurve(to: CGPoint(x: 60, y: 80),
                          control1: CGPoint(x: 0, y: -120),
                          control2: CGPoint(x: 80, y: -20))
            path.addCurve(to: target,
                          control1: CGPoint(x: 40, y: 160),
                          control2: CGPoint(x: target.x, y: target.y + 50))
        default: // rightSide
            path.move(to: CGPoint(x: sizeWidth / 2 + 30, y: -60))
            path.addCurve(to: CGPoint(x: -60, y: 80),
                          control1: CGPoint(x: 0, y: -120),
                          control2: CGPoint(x: -80, y: -20))
            path.addCurve(to: target,
                          control1: CGPoint(x: -40, y: 160),
                          control2: CGPoint(x: target.x, y: target.y + 50))
        }

        return path
    }

    // MARK: - Frame Update Loop
    private var lastUpdateTime: TimeInterval = 0

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = min(currentTime - lastUpdateTime, 0.1)
        lastUpdateTime = currentTime

        updateStars(dt: dt)

        if isGameOverState || isStageIntro { return }

        updatePlayer(dt: dt)
        updateWaveSpawning(dt: dt)
        updateFormation(dt: dt)
        updateDiveBombers(dt: dt)
        updateProjectiles(dt: dt)
        checkCollisions()
        checkStageClear()
    }

    private func updateStars(dt: TimeInterval) {
        for star in stars {
            star.node.position.y -= star.speed * CGFloat(dt)
            if star.node.position.y < -sizeHeight / 2 {
                star.node.position.y = sizeHeight / 2
                star.node.position.x = CGFloat.random(in: -sizeWidth / 2...sizeWidth / 2)
            }
        }
    }

    private func updatePlayer(dt: TimeInterval) {
        if isPlayerDead { return }

        if invulnerableTime > 0 {
            invulnerableTime -= dt
            player.alpha = Int(invulnerableTime * 8) % 2 == 0 ? 0.3 : 1.0
        } else {
            player.alpha = 1.0
        }

        let speed: CGFloat = 260.0 * CGFloat(dt)
        if moveLeft {
            player.position.x -= speed
        }
        if moveRight {
            player.position.x += speed
        }

        let limit = sizeWidth / 2 - 30
        player.position.x = max(-limit, min(limit, player.position.x))

        // Firing logic (Authentic Galaga: max 2 missiles on screen at once)
        if fireCooldown > 0 { fireCooldown -= dt }
        if isFiring && fireCooldown <= 0 && playerMissiles.count < 2 {
            firePlayerLaser()
            fireCooldown = 0.22
        }
    }

    private func firePlayerLaser() {
        SoundEngine.shared.playLaser()

        let missile = SKSpriteNode(texture: RetroTextures.shared.playerLaser)
        missile.position = CGPoint(x: player.position.x, y: player.position.y + 18)
        gameLayer.addChild(missile)
        playerMissiles.append(missile)
    }

    private func updateWaveSpawning(dt: TimeInterval) {
        guard !waveQueue.isEmpty else { return }

        spawnTimer += dt
        let next = waveQueue[0]
        if spawnTimer >= next.delay {
            spawnTimer = 0
            waveQueue.removeFirst()
            spawnEnemy(spawn: next)
        }
    }

    private func updateFormation(dt: TimeInterval) {
        formationTime += dt * 2.2
        let swayX = CGFloat(sin(formationTime)) * 18.0

        // Flapping wings animation
        wingFlapTimer += dt
        if wingFlapTimer >= 0.3 {
            wingFlapTimer = 0
            currentWingFrame = currentWingFrame == 1 ? 2 : 1
        }

        for enemy in enemies {
            // Update texture for wing flaps
            updateEnemyTexture(enemy: enemy)

            if enemy.state == .formation {
                enemy.position.x = enemy.targetSlot.x + swayX
                enemy.position.y = enemy.targetSlot.y
                enemy.zRotation = 0
            } else if enemy.state == .returning {
                // Return from top
                let targetPos = CGPoint(x: enemy.targetSlot.x + swayX, y: enemy.targetSlot.y)
                let dx = targetPos.x - enemy.position.x
                let dy = targetPos.y - enemy.position.y
                enemy.position.x += dx * CGFloat(dt) * 3.0
                enemy.position.y += dy * CGFloat(dt) * 3.0

                if hypot(dx, dy) < 8 {
                    enemy.state = .formation
                    enemy.hasFired = false
                    enemy.zRotation = 0
                }
            }
        }
    }

    private func updateEnemyTexture(enemy: EnemyNode) {
        switch enemy.enemyType {
        case .bee:
            enemy.texture = currentWingFrame == 1 ? RetroTextures.shared.bee1 : RetroTextures.shared.bee2
        case .butterfly:
            enemy.texture = currentWingFrame == 1 ? RetroTextures.shared.butterfly1 : RetroTextures.shared.butterfly2
        case .boss:
            if enemy.health > 1 {
                enemy.texture = currentWingFrame == 1 ? RetroTextures.shared.bossGreen1 : RetroTextures.shared.bossGreen2
            } else {
                enemy.texture = currentWingFrame == 1 ? RetroTextures.shared.bossBlue1 : RetroTextures.shared.bossBlue2
            }
        }
    }

    private func updateDiveBombers(dt: TimeInterval) {
        guard waveQueue.isEmpty else { return }

        diveTimer += dt
        let diveInterval = max(1.2, 2.5 - Double(stage) * 0.2)

        if diveTimer >= diveInterval {
            diveTimer = 0
            let ready = enemies.filter { $0.state == .formation }
            if let victim = ready.randomElement() {
                launchDive(enemy: victim)
            }
        }

        // Check diving enemies to fire bullets midway
        for enemy in enemies where enemy.state == .diving {
            if !enemy.hasFired && enemy.position.y > -50 && enemy.position.y < sizeHeight / 4 {
                fireAlienBullet(from: enemy)
                enemy.hasFired = true
            }
        }
    }

    private func launchDive(enemy: EnemyNode) {
        SoundEngine.shared.playDive()
        enemy.state = .diving
        enemy.hasFired = false

        let start = enemy.position
        let playerX = player.position.x
        let sweepDir: CGFloat = start.x > 0 ? -1.0 : 1.0

        let path = CGMutablePath()
        path.move(to: start)
        path.addCurve(to: CGPoint(x: playerX + sweepDir * 30, y: -sizeHeight / 4),
                      control1: CGPoint(x: start.x + sweepDir * 40, y: start.y + 20),
                      control2: CGPoint(x: start.x + sweepDir * 80, y: 0))
        path.addCurve(to: CGPoint(x: -sweepDir * sizeWidth / 2, y: -sizeHeight / 2 - 50),
                      control1: CGPoint(x: playerX - sweepDir * 20, y: -sizeHeight / 2 + 50),
                      control2: CGPoint(x: playerX - sweepDir * 60, y: -sizeHeight / 2))

        let follow = SKAction.follow(path, asOffset: false, orientToPath: true, duration: 2.8)
        let loopBack = SKAction.run { [weak self, weak enemy] in
            guard let enemy = enemy, let self = self else { return }
            enemy.state = .returning
            enemy.position = CGPoint(x: enemy.targetSlot.x, y: self.sizeHeight / 2 + 30)
            enemy.zRotation = 0
        }

        enemy.run(SKAction.sequence([follow, loopBack]))
    }

    private func fireAlienBullet(from enemy: EnemyNode) {
        let bullet = SKSpriteNode(texture: RetroTextures.shared.alienBullet)
        bullet.position = enemy.position
        gameLayer.addChild(bullet)
        alienBullets.append(bullet)

        let dx = player.position.x - enemy.position.x
        let dy = player.position.y - enemy.position.y
        let angle = atan2(dy, dx)
        let speed: CGFloat = 220 + CGFloat(stage * 20)

        bullet.userData = ["vx": cos(angle) * speed, "vy": sin(angle) * speed]
    }

    private func updateProjectiles(dt: TimeInterval) {
        // Player Missiles
        for (idx, missile) in playerMissiles.enumerated().reversed() {
            missile.position.y += 620.0 * CGFloat(dt)
            if missile.position.y > sizeHeight / 2 + 20 {
                missile.removeFromParent()
                playerMissiles.remove(at: idx)
            }
        }

        // Alien Bullets
        for (idx, bullet) in alienBullets.enumerated().reversed() {
            if let vx = bullet.userData?["vx"] as? CGFloat, let vy = bullet.userData?["vy"] as? CGFloat {
                bullet.position.x += vx * CGFloat(dt)
                bullet.position.y += vy * CGFloat(dt)
            } else {
                bullet.position.y -= 250.0 * CGFloat(dt)
            }

            if bullet.position.y < -sizeHeight / 2 - 20 || bullet.position.y > sizeHeight / 2 + 20 ||
               bullet.position.x < -sizeWidth / 2 - 20 || bullet.position.x > sizeWidth / 2 + 20 {
                bullet.removeFromParent()
                alienBullets.remove(at: idx)
            }
        }
    }

    private func checkCollisions() {
        // 1. Player Missile vs Enemies
        for (mIdx, missile) in playerMissiles.enumerated().reversed() {
            for (eIdx, enemy) in enemies.enumerated().reversed() {
                if hypot(missile.position.x - enemy.position.x, missile.position.y - enemy.position.y) < 22 {
                    missile.removeFromParent()
                    playerMissiles.remove(at: mIdx)

                    enemy.health -= 1
                    if enemy.health <= 0 {
                        // Destroyed
                        SoundEngine.shared.playExplosion()
                        createExplosion(at: enemy.position)

                        var pts = 50
                        switch enemy.enemyType {
                        case .bee: pts = enemy.state == .diving ? 100 : 50
                        case .butterfly: pts = enemy.state == .diving ? 160 : 80
                        case .boss: pts = enemy.state == .diving ? 400 : 150
                        }
                        addScore(pts: pts)

                        enemy.removeAllActions()
                        enemy.removeFromParent()
                        enemies.remove(at: eIdx)
                    } else {
                        // Boss damaged
                        SoundEngine.shared.playLaser()
                        addScore(pts: 50)
                        updateEnemyTexture(enemy: enemy)
                    }
                    break
                }
            }
        }

        // 2. Alien Attacks vs Player
        guard !isPlayerDead && invulnerableTime <= 0 else { return }

        // Bullet vs Player
        for (bIdx, bullet) in alienBullets.enumerated().reversed() {
            if hypot(bullet.position.x - player.position.x, bullet.position.y - player.position.y) < 16 {
                bullet.removeFromParent()
                alienBullets.remove(at: bIdx)
                killPlayer()
                return
            }
        }

        // Enemy Ramming Player
        for (eIdx, enemy) in enemies.enumerated().reversed() {
            if hypot(enemy.position.x - player.position.x, enemy.position.y - player.position.y) < 24 {
                SoundEngine.shared.playExplosion()
                createExplosion(at: enemy.position)
                enemy.removeFromParent()
                enemies.remove(at: eIdx)
                killPlayer()
                return
            }
        }
    }

    private func killPlayer() {
        SoundEngine.shared.playPlayerDeath()
        createExplosion(at: player.position)
        isPlayerDead = true
        player.isHidden = true
        lives -= 1
        updateLifeIcons()

        let delay = SKAction.wait(forDuration: 1.8)
        let respawn = SKAction.run { [weak self] in
            guard let self = self else { return }
            if self.lives > 0 {
                self.isPlayerDead = false
                self.player.isHidden = false
                self.player.position = CGPoint(x: 0, y: -self.sizeHeight / 2 + 65)
                self.invulnerableTime = 2.0
            } else {
                self.gameOver()
            }
        }
        run(SKAction.sequence([delay, respawn]))
    }

    private func createExplosion(at position: CGPoint) {
        let exp = SKSpriteNode(texture: RetroTextures.shared.explosions[0])
        exp.position = position
        gameLayer.addChild(exp)

        let animate = SKAction.animate(with: RetroTextures.shared.explosions, timePerFrame: 0.08)
        let remove = SKAction.removeFromParent()
        exp.run(SKAction.sequence([animate, remove]))
    }

    private func addScore(pts: Int) {
        score += pts
        scoreLabel.text = "\(score)"
        if score > highScore {
            highScore = score
            highScoreLabel.text = "\(highScore)"
        }
    }

    private func checkStageClear() {
        if waveQueue.isEmpty && enemies.isEmpty && !isStageIntro && !isGameOverState {
            isStageIntro = true
            messageLabel.text = "STAGE CLEARED!"
            messageLabel.isHidden = false

            let wait = SKAction.wait(forDuration: 2.0)
            let next = SKAction.run { [weak self] in
                guard let self = self else { return }
                self.startStage(stageNumber: self.stage + 1)
            }
            run(SKAction.sequence([wait, next]))
        }
    }

    private func gameOver() {
        isGameOverState = true
        messageLabel.text = "GAME OVER\n\nSCORE: \(score)\n\nPRESS FIRE / TAP"
        messageLabel.isHidden = false

        if score > 0 {
            submitScoreToLeaderboard()
        }
    }

    private func submitScoreToLeaderboard() {
        guard let url = URL(string: "http://localhost:8000/api/leaderboard") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "player": "APL",
            "score": score,
            "stage": stage,
            "platform": "apple"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rank = json["rank"] as? Int,
                  let self = self else { return }
            DispatchQueue.main.async {
                self.messageLabel.text = "GAME OVER\n\nSCORE: \(self.score)\nGLOBAL RANK: #\(rank)\n\nPRESS FIRE / TAP"
            }
        }.resume()
    }

    // MARK: - Controller Support
    private func setupGameControllers() {
        #if canImport(GameController)
        NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            if let controller = note.object as? GCController {
                self?.configureController(controller)
            }
        }
        for controller in GCController.controllers() {
            configureController(controller)
        }
        #endif
    }

    #if canImport(GameController)
    private func configureController(_ controller: GCController) {
        controller.extendedGamepad?.dpad.valueChangedHandler = { [weak self] (dpad, x, y) in
            self?.moveLeft = x < -0.2
            self?.moveRight = x > 0.2
        }
        controller.extendedGamepad?.buttonA.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.isFiring = pressed
            if pressed && self?.isGameOverState == true {
                self?.startNewGame()
            }
        }
        controller.microGamepad?.dpad.valueChangedHandler = { [weak self] (dpad, x, y) in
            self?.moveLeft = x < -0.2
            self?.moveRight = x > 0.2
        }
        controller.microGamepad?.buttonA.valueChangedHandler = { [weak self] (button, value, pressed) in
            self?.isFiring = pressed
            if pressed && self?.isGameOverState == true {
                self?.startNewGame()
            }
        }
    }
    #endif
}

// MARK: - Input Extensions for iOS & tvOS
#if os(iOS) || os(tvOS)
extension GameScene {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isGameOverState {
            startNewGame()
            return
        }

        isFiring = true
        if let touch = touches.first {
            let loc = touch.location(in: self)
            player.position.x = loc.x
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let loc = touch.location(in: self)
            player.position.x = loc.x
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isFiring = false
    }

    func handleSwipe(direction: SwipeDirection) {
        switch direction {
        case .left:
            player.position.x -= 40
        case .right:
            player.position.x += 40
        }
    }
}
#endif

// MARK: - Input Extensions for macOS
#if os(OSX)
extension GameScene {
    override func keyDown(with event: NSEvent) {
        if isGameOverState {
            startNewGame()
            return
        }

        switch event.keyCode {
        case 123, 0: // Left Arrow or 'A'
            moveLeft = true
        case 124, 2: // Right Arrow or 'D'
            moveRight = true
        case 49, 126, 36: // Spacebar, Up Arrow, Return
            isFiring = true
        default:
            break
        }
    }

    override func keyUp(with event: NSEvent) {
        switch event.keyCode {
        case 123, 0:
            moveLeft = false
        case 124, 2:
            moveRight = false
        case 49, 126, 36:
            isFiring = false
        default:
            break
        }
    }

    override func mouseDown(with event: NSEvent) {
        if isGameOverState {
            startNewGame()
        } else {
            isFiring = true
            let loc = event.location(in: self)
            player.position.x = loc.x
        }
    }

    override func mouseUp(with event: NSEvent) {
        isFiring = false
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = event.location(in: self)
        player.position.x = loc.x
    }
}
#endif
