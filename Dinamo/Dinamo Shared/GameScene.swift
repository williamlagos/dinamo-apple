//
//  GameScene.swift
//  Dinamo Shared
//
//  Galaga 1981 & Game Boy Retro Shooter Engine for Apple Platforms (iOS, macOS, tvOS)
//

import SpriteKit
import AVFoundation

#if canImport(GameController)
import GameController
#endif

// MARK: - Enums & Data Structures

enum GameTheme: String, CaseIterable {
    case dmg = "DMG"
    case pocket = "Pocket"
    case gbc = "GBC"
    case arcade = "Arcade"
}

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
    case up
    case down
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

// MARK: - Procedural Retro & Chiptune Sound Engine
class SoundEngine {
    static let shared = SoundEngine()
    var isMuted = false
    var isGBMode = true
    private var audioEngine = AVAudioEngine()

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
    func playTone(freqStart: Double, freqEnd: Double, duration: Double, isNoise: Bool = false, dutyCycle: Double = 0.5) {
        guard !isMuted else { return }

        DispatchQueue.global(qos: .userInteractive).async {
            let sampleRate = 44100.0
            let numSamples = Int(sampleRate * duration)
            var samples = [Float](repeating: 0, count: numSamples)

            if isNoise {
                // Game Boy Channel 4 7-bit LFSR pseudo-random noise simulation
                var lfsr: UInt16 = 0x7fff
                for i in 0..<numSamples {
                    let progress = Double(i) / Double(numSamples)
                    let envelope = Float(max(0.0, 1.0 - progress))
                    let bit = (lfsr & 1) ^ ((lfsr >> 1) & 1)
                    lfsr = (lfsr >> 1) | (bit << 14)
                    // 7-bit metallic crunch
                    lfsr = (lfsr & ~0x40) | (bit << 6)
                    let val = (lfsr & 1) != 0 ? Float(0.8) : Float(-0.8)
                    samples[i] = val * envelope * 0.45
                }
            } else {
                // Pulse square wave (Channel 1 & 2)
                var phase: Double = 0.0
                for i in 0..<numSamples {
                    let progress = Double(i) / Double(numSamples)
                    let currentFreq = freqStart + (freqEnd - freqStart) * progress
                    let phaseInc = (2.0 * Double.pi * currentFreq) / sampleRate
                    phase += phaseInc
                    if phase > 2.0 * Double.pi { phase -= 2.0 * Double.pi }

                    let wave = sin(phase) > (2.0 * (dutyCycle - 0.5)) ? Float(0.7) : Float(-0.7)
                    let envelope = Float(max(0.0, 1.0 - progress * 1.1))
                    samples[i] = wave * envelope * 0.35
                }
            }

            guard let wavData = self.createWavData(samples: samples, sampleRate: Int(sampleRate)) else { return }

            DispatchQueue.main.async {
                do {
                    let player = try AVAudioPlayer(data: wavData)
                    player.volume = 0.8
                    player.play()
                    objc_setAssociatedObject(self, "sound_\(Date().timeIntervalSince1970)", player, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                } catch {
                    // Audio fallback
                }
            }
        }
    }

    func playLaser() {
        playTone(freqStart: 880, freqEnd: 220, duration: 0.11, isNoise: false)
    }

    func playExplosion() {
        playTone(freqStart: 0, freqEnd: 0, duration: 0.22, isNoise: true)
    }

    func playDive() {
        playTone(freqStart: 520, freqEnd: 260, duration: 0.35, isNoise: false)
    }

    func playPlayerDeath() {
        playTone(freqStart: 0, freqEnd: 0, duration: 0.48, isNoise: true)
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

// MARK: - Procedural Texture Generator with Authentic Palettes
class RetroTextures {
    static let shared = RetroTextures()

    var currentTheme: GameTheme = .dmg

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

    func setTheme(_ theme: GameTheme) {
        self.currentTheme = theme
        generateAll()
    }

    private func createTexture(width: Int, height: Int, pixels: [String], colors: [Character: (CGFloat, CGFloat, CGFloat)], scale: Int = 1) -> SKTexture {
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

    func generateAll() {
        let colors: [Character: (CGFloat, CGFloat, CGFloat)]

        switch currentTheme {
        case .dmg:
            // Authentic Game Boy DMG (1989) pea-green monochrome
            let lightest: (CGFloat, CGFloat, CGFloat) = (224.0/255.0, 248.0/255.0, 208.0/255.0) // #e0f8d0
            let light: (CGFloat, CGFloat, CGFloat)    = (136.0/255.0, 192.0/255.0, 112.0/255.0) // #88c070
            let dark: (CGFloat, CGFloat, CGFloat)     = (52.0/255.0, 104.0/255.0, 86.0/255.0)   // #346856
            let darkest: (CGFloat, CGFloat, CGFloat)  = (8.0/255.0, 24.0/255.0, 32.0/255.0)     // #081820
            colors = [
                "W": lightest, "C": lightest,
                "B": light, "Y": light, "G": light,
                "R": dark, "O": dark, "P": dark,
                "D": darkest
            ]

        case .pocket:
            // Authentic Game Boy Pocket (1996) true monochrome FSTN
            let lightest: (CGFloat, CGFloat, CGFloat) = (1.0, 1.0, 1.0)
            let light: (CGFloat, CGFloat, CGFloat)    = (170.0/255.0, 170.0/255.0, 170.0/255.0)
            let dark: (CGFloat, CGFloat, CGFloat)     = (85.0/255.0, 85.0/255.0, 85.0/255.0)
            let darkest: (CGFloat, CGFloat, CGFloat)  = (0.0, 0.0, 0.0)
            colors = [
                "W": lightest, "C": lightest,
                "B": light, "Y": light, "G": light,
                "R": dark, "O": dark, "P": dark,
                "D": darkest
            ]

        case .gbc:
            // Game Boy Color (1998) 4-color sprite banks
            colors = [
                "W": (1.0, 1.0, 1.0),
                "R": (216.0/255.0, 40.0/255.0, 0.0),
                "B": (0.0, 104.0/255.0, 248.0/255.0),
                "Y": (248.0/255.0, 216.0/255.0, 0.0),
                "G": (0.0, 232.0/255.0, 72.0/255.0),
                "C": (0.0, 232.0/255.0, 216.0/255.0),
                "O": (248.0/255.0, 136.0/255.0, 0.0),
                "P": (184.0/255.0, 0.0, 64.0/255.0),
                "D": (24.0/255.0, 24.0/255.0, 40.0/255.0),
            ]

        case .arcade:
            // Original Galaga 1981 Arcade Colors
            colors = [
                "W": (1.0, 1.0, 1.0),
                "R": (1.0, 0.15, 0.15),
                "B": (0.15, 0.5, 1.0),
                "Y": (1.0, 0.88, 0.0),
                "G": (0.0, 0.88, 0.25),
                "C": (0.15, 1.0, 1.0),
                "O": (1.0, 0.55, 0.0),
                "P": (0.65, 0.25, 1.0),
                "D": (0.25, 0.25, 0.25),
            ]
        }

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
        player = createTexture(width: 15, height: 16, pixels: playerPixels, colors: colors, scale: 1)
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
        bee1 = createTexture(width: 16, height: 16, pixels: bee1Pixels, colors: colors, scale: 1)
        bee2 = createTexture(width: 16, height: 16, pixels: bee2Pixels, colors: colors, scale: 1)

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
        butterfly1 = createTexture(width: 16, height: 16, pixels: bfly1Pixels, colors: colors, scale: 1)
        butterfly2 = createTexture(width: 16, height: 16, pixels: bfly2Pixels, colors: colors, scale: 1)

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
        bossGreen1 = createTexture(width: 16, height: 16, pixels: bossG1Pixels, colors: colors, scale: 1)
        bossGreen2 = createTexture(width: 16, height: 16, pixels: bossG2Pixels, colors: colors, scale: 1)

        let bossB1Pixels = bossG1Pixels.map { $0.replacingOccurrences(of: "G", with: "B") }
        let bossB2Pixels = bossG2Pixels.map { $0.replacingOccurrences(of: "G", with: "B") }
        bossBlue1 = createTexture(width: 16, height: 16, pixels: bossB1Pixels, colors: colors, scale: 1)
        bossBlue2 = createTexture(width: 16, height: 16, pixels: bossB2Pixels, colors: colors, scale: 1)

        let laserPixels = [
            "R R",
            "Y Y",
            "Y Y",
            "W W",
            "W W",
            "Y Y",
            "Y Y",
            "R R",
        ]
        playerLaser = createTexture(width: 3, height: 8, pixels: laserPixels, colors: colors, scale: 1)

        let bulletPixels = [
            " O ",
            "OOO",
            "OWO",
            "OOO",
            " O ",
        ]
        alienBullet = createTexture(width: 3, height: 5, pixels: bulletPixels, colors: colors, scale: 1)

        let exp1 = ["  W  "]
        let exp2 = ["  Y  ", " YWY ", "  Y  "]
        let exp3 = [" R O R ", "  YWY  ", "OW W WO", "  YWY  ", " R O R "]
        let exp4 = ["R  O  R", " Y   Y ", "O  W  O", " Y   Y ", "R  O  R"]
        explosions = [
            createTexture(width: 5, height: 1, pixels: exp1, colors: colors, scale: 1),
            createTexture(width: 5, height: 3, pixels: exp2, colors: colors, scale: 1),
            createTexture(width: 7, height: 5, pixels: exp3, colors: colors, scale: 1),
            createTexture(width: 7, height: 5, pixels: exp4, colors: colors, scale: 1),
        ]
    }
}

// MARK: - GameScene Main Implementation
class GameScene: SKScene {

    // Native 160x144 Game Boy Resolution
    let nativeWidth: CGFloat = 160.0
    let nativeHeight: CGFloat = 144.0

    // Theme state
    var currentTheme: GameTheme = .dmg

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
    private var themeLabel: SKLabelNode!

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
        // Enforce authentic 160x144 Game Boy viewport with aspect-fit scaling
        self.size = CGSize(width: nativeWidth, height: nativeHeight)
        self.scaleMode = .aspectFit
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // Setup Scene Layers
        addChild(starLayer)
        addChild(gameLayer)
        addChild(hudLayer)

        setupThemeColors()
        setupStarfield()
        setupHUD()
        setupPlayer()
        setupGameControllers()

        startNewGame()
    }

    func setTheme(_ theme: GameTheme) {
        currentTheme = theme
        RetroTextures.shared.setTheme(theme)
        setupThemeColors()
        setupStarfield()
        updateHUDTheme()

        if player != nil {
            player.texture = RetroTextures.shared.player
        }
        for enemy in enemies {
            updateEnemyTexture(enemy: enemy)
        }
        updateLifeIcons()
    }

    func cycleTheme() {
        let all = GameTheme.allCases
        if let idx = all.firstIndex(of: currentTheme) {
            let nextTheme = all[(idx + 1) % all.count]
            setTheme(nextTheme)
        }
    }

    private func setupThemeColors() {
        switch currentTheme {
        case .dmg:
            backgroundColor = SKColor(red: 8/255, green: 24/255, blue: 32/255, alpha: 1.0)
        case .pocket:
            backgroundColor = .black
        case .gbc:
            backgroundColor = SKColor(red: 8/255, green: 16/255, blue: 32/255, alpha: 1.0)
        case .arcade:
            backgroundColor = SKColor(red: 5/255, green: 5/255, blue: 13/255, alpha: 1.0)
        }
    }

    private func setupStarfield() {
        starLayer.removeAllChildren()
        stars.removeAll()

        let starColors: [SKColor]
        switch currentTheme {
        case .dmg:
            starColors = [
                SKColor(red: 136/255, green: 192/255, blue: 112/255, alpha: 1.0),
                SKColor(red: 224/255, green: 248/255, blue: 208/255, alpha: 1.0)
            ]
        case .pocket:
            starColors = [.white, SKColor(white: 0.65, alpha: 1.0)]
        case .gbc:
            starColors = [.yellow, .cyan, .white]
        case .arcade:
            starColors = [.white, .cyan, .yellow, .red]
        }

        for _ in 0..<28 {
            let star = SKShapeNode(rectOf: CGSize(width: 1, height: 1))
            star.fillColor = starColors.randomElement() ?? .white
            star.strokeColor = .clear
            star.position = CGPoint(
                x: CGFloat.random(in: -nativeWidth / 2...nativeWidth / 2),
                y: CGFloat.random(in: -nativeHeight / 2...nativeHeight / 2)
            )
            starLayer.addChild(star)
            stars.append((node: star, speed: CGFloat.random(in: 12...35)))
        }
    }

    private func setupHUD() {
        hudLayer.removeAllChildren()

        let font = "Courier-Bold"

        let oneUpTitle = SKLabelNode(fontNamed: font)
        oneUpTitle.text = "1UP"
        oneUpTitle.fontSize = 6
        oneUpTitle.fontColor = currentTheme == .dmg ? SKColor(red: 224/255, green: 248/255, blue: 208/255, alpha: 1.0) : .red
        oneUpTitle.position = CGPoint(x: -nativeWidth / 2 + 18, y: nativeHeight / 2 - 8)
        hudLayer.addChild(oneUpTitle)

        scoreLabel = SKLabelNode(fontNamed: font)
        scoreLabel.text = "00"
        scoreLabel.fontSize = 6
        scoreLabel.fontColor = currentTheme == .dmg ? SKColor(red: 224/255, green: 248/255, blue: 208/255, alpha: 1.0) : .white
        scoreLabel.position = CGPoint(x: -nativeWidth / 2 + 18, y: nativeHeight / 2 - 16)
        hudLayer.addChild(scoreLabel)

        let highTitle = SKLabelNode(fontNamed: font)
        highTitle.text = "HIGH"
        highTitle.fontSize = 6
        highTitle.fontColor = currentTheme == .dmg ? SKColor(red: 224/255, green: 248/255, blue: 208/255, alpha: 1.0) : .red
        highTitle.position = CGPoint(x: 0, y: nativeHeight / 2 - 8)
        hudLayer.addChild(highTitle)

        highScoreLabel = SKLabelNode(fontNamed: font)
        highScoreLabel.text = "\(highScore)"
        highScoreLabel.fontSize = 6
        highScoreLabel.fontColor = currentTheme == .dmg ? SKColor(red: 224/255, green: 248/255, blue: 208/255, alpha: 1.0) : .white
        highScoreLabel.position = CGPoint(x: 0, y: nativeHeight / 2 - 16)
        hudLayer.addChild(highScoreLabel)

        stageLabel = SKLabelNode(fontNamed: font)
        stageLabel.text = "ST 1"
        stageLabel.fontSize = 6
        stageLabel.fontColor = currentTheme == .dmg ? SKColor(red: 136/255, green: 192/255, blue: 112/255, alpha: 1.0) : .cyan
        stageLabel.position = CGPoint(x: nativeWidth / 2 - 18, y: nativeHeight / 2 - 16)
        hudLayer.addChild(stageLabel)

        themeLabel = SKLabelNode(fontNamed: font)
        themeLabel.text = "[\(currentTheme.rawValue)]"
        themeLabel.fontSize = 5
        themeLabel.fontColor = currentTheme == .dmg ? SKColor(red: 136/255, green: 192/255, blue: 112/255, alpha: 1.0) : .gray
        themeLabel.position = CGPoint(x: nativeWidth / 2 - 18, y: -nativeHeight / 2 + 8)
        hudLayer.addChild(themeLabel)

        messageLabel = SKLabelNode(fontNamed: font)
        messageLabel.text = ""
        messageLabel.fontSize = 9
        messageLabel.fontColor = currentTheme == .dmg ? SKColor(red: 224/255, green: 248/255, blue: 208/255, alpha: 1.0) : .yellow
        messageLabel.position = .zero
        messageLabel.numberOfLines = 3
        hudLayer.addChild(messageLabel)

        updateLifeIcons()
    }

    private func updateHUDTheme() {
        let fontColor = currentTheme == .dmg ? SKColor(red: 224/255, green: 248/255, blue: 208/255, alpha: 1.0) : .white
        scoreLabel?.fontColor = fontColor
        highScoreLabel?.fontColor = fontColor
        messageLabel?.fontColor = currentTheme == .dmg ? fontColor : .yellow
        themeLabel?.text = "[\(currentTheme.rawValue)]"
        themeLabel?.fontColor = currentTheme == .dmg ? SKColor(red: 136/255, green: 192/255, blue: 112/255, alpha: 1.0) : .gray
    }

    private func updateLifeIcons() {
        lifeIcons.forEach { $0.removeFromParent() }
        lifeIcons.removeAll()

        for i in 0..<max(0, lives - 1) {
            let icon = SKSpriteNode(texture: RetroTextures.shared.playerMini)
            icon.position = CGPoint(x: -nativeWidth / 2 + 12 + CGFloat(i * 10), y: -nativeHeight / 2 + 8)
            hudLayer.addChild(icon)
            lifeIcons.append(icon)
        }
    }

    private func setupPlayer() {
        player = SKSpriteNode(texture: RetroTextures.shared.player)
        player.position = CGPoint(x: 0, y: -nativeHeight / 2 + 16)
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
        player.position = CGPoint(x: 0, y: -nativeHeight / 2 + 16)

        startStage(stageNumber: stage)
    }

    private func startStage(stageNumber: Int) {
        stage = stageNumber
        stageLabel.text = "ST \(stage)"
        isStageIntro = true
        messageLabel.text = "STAGE \(stage)\n\nREADY"
        messageLabel.isHidden = false

        SoundEngine.shared.playTone(freqStart: 260, freqEnd: 520, duration: 0.35)

        buildWaveQueue()

        let waitAction = SKAction.wait(forDuration: 2.0)
        let finishIntro = SKAction.run { [weak self] in
            self?.isStageIntro = false
            self?.messageLabel.isHidden = true
        }
        run(SKAction.sequence([waitAction, finishIntro]))
    }

    // 10-ship armada formation matching GBGame
    private func getFormationSlot(row: Int, col: Int) -> CGPoint {
        let colSpacing: CGFloat = 16
        let rowSpacing: CGFloat = 14
        let startX: CGFloat = -CGFloat(5) * colSpacing / 2.0
        let startY: CGFloat = nativeHeight / 2 - 28

        return CGPoint(
            x: startX + CGFloat(col) * colSpacing,
            y: startY - CGFloat(row) * rowSpacing
        )
    }

    private func buildWaveQueue() {
        waveQueue.removeAll()

        // 10-ship armada layout:
        // Row 0: 2 Bosses (cols 2, 3)
        // Row 1: 4 Escorts (cols 1, 2, 3, 4)
        // Row 2: 4 Bees (cols 1, 2, 3, 4)
        let waveItems: [(EnemyType, Int, Int, String)] = [
            (.boss, 0, 2, "topLeft"), (.boss, 0, 3, "topRight"),
            (.butterfly, 1, 1, "leftSide"), (.butterfly, 1, 4, "rightSide"),
            (.butterfly, 1, 2, "topLeft"), (.butterfly, 1, 3, "topRight"),
            (.bee, 2, 1, "leftSide"), (.bee, 2, 4, "rightSide"),
            (.bee, 2, 2, "topLeft"), (.bee, 2, 3, "topRight"),
        ]

        for (idx, item) in waveItems.enumerated() {
            waveQueue.append(WaveSpawn(
                type: item.0,
                row: item.1,
                col: item.2,
                pathType: item.3,
                delay: 0.15 + Double(idx) * 0.18
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

        let follow = SKAction.follow(path, asOffset: false, orientToPath: true, duration: 2.2)
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
            path.move(to: CGPoint(x: -nativeWidth / 2 - 10, y: nativeHeight / 2 - 20))
            path.addCurve(to: CGPoint(x: 15, y: 0),
                          control1: CGPoint(x: -15, y: nativeHeight / 4),
                          control2: CGPoint(x: 30, y: 25))
            path.addCurve(to: target,
                          control1: CGPoint(x: 0, y: -25),
                          control2: CGPoint(x: target.x, y: target.y + 20))
        case "topRight":
            path.move(to: CGPoint(x: nativeWidth / 2 + 10, y: nativeHeight / 2 - 20))
            path.addCurve(to: CGPoint(x: -15, y: 0),
                          control1: CGPoint(x: 15, y: nativeHeight / 4),
                          control2: CGPoint(x: -30, y: 25))
            path.addCurve(to: target,
                          control1: CGPoint(x: 0, y: -25),
                          control2: CGPoint(x: target.x, y: target.y + 20))
        case "leftSide":
            path.move(to: CGPoint(x: -nativeWidth / 2 - 15, y: -20))
            path.addCurve(to: CGPoint(x: 20, y: 25),
                          control1: CGPoint(x: 0, y: -40),
                          control2: CGPoint(x: 25, y: -10))
            path.addCurve(to: target,
                          control1: CGPoint(x: 15, y: 50),
                          control2: CGPoint(x: target.x, y: target.y + 20))
        default: // rightSide
            path.move(to: CGPoint(x: nativeWidth / 2 + 15, y: -20))
            path.addCurve(to: CGPoint(x: -20, y: 25),
                          control1: CGPoint(x: 0, y: -40),
                          control2: CGPoint(x: -25, y: -10))
            path.addCurve(to: target,
                          control1: CGPoint(x: -15, y: 50),
                          control2: CGPoint(x: target.x, y: target.y + 20))
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
            if star.node.position.y < -nativeHeight / 2 {
                star.node.position.y = nativeHeight / 2
                star.node.position.x = CGFloat.random(in: -nativeWidth / 2...nativeWidth / 2)
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

        let speed: CGFloat = 90.0 * CGFloat(dt)
        if moveLeft {
            player.position.x -= speed
        }
        if moveRight {
            player.position.x += speed
        }

        let limit = nativeWidth / 2 - 10
        player.position.x = max(-limit, min(limit, player.position.x))

        // Firing logic (Authentic Game Boy: max 2 missiles on screen at once)
        if fireCooldown > 0 { fireCooldown -= dt }
        if isFiring && fireCooldown <= 0 && playerMissiles.count < 2 {
            firePlayerLaser()
            fireCooldown = 0.22
        }
    }

    private func firePlayerLaser() {
        SoundEngine.shared.playLaser()

        let missile = SKSpriteNode(texture: RetroTextures.shared.playerLaser)
        missile.position = CGPoint(x: player.position.x, y: player.position.y + 8)
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
        let swayX = CGFloat(sin(formationTime)) * 6.0

        // Flapping wings animation
        wingFlapTimer += dt
        if wingFlapTimer >= 0.25 {
            wingFlapTimer = 0
            currentWingFrame = currentWingFrame == 1 ? 2 : 1
        }

        for enemy in enemies {
            updateEnemyTexture(enemy: enemy)

            if enemy.state == .formation {
                enemy.position.x = enemy.targetSlot.x + swayX
                enemy.position.y = enemy.targetSlot.y
                enemy.zRotation = 0
            } else if enemy.state == .returning {
                let targetPos = CGPoint(x: enemy.targetSlot.x + swayX, y: enemy.targetSlot.y)
                let dx = targetPos.x - enemy.position.x
                let dy = targetPos.y - enemy.position.y
                enemy.position.x += dx * CGFloat(dt) * 3.0
                enemy.position.y += dy * CGFloat(dt) * 3.0

                if hypot(dx, dy) < 4 {
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
        diveTimer += dt
        if diveTimer >= 2.5 {
            diveTimer = 0
            triggerDiveBomb()
        }
    }

    private func triggerDiveBomb() {
        let formationEnemies = enemies.filter { $0.state == .formation }
        guard let attacker = formationEnemies.randomElement() else { return }

        attacker.state = .diving
        attacker.hasFired = false
        SoundEngine.shared.playDive()

        executeDivePath(for: attacker)
    }

    private func executeDivePath(for enemy: EnemyNode) {
        let path = CGMutablePath()
        let start = enemy.position
        let playerX = player.position.x
        let sweepDir: CGFloat = start.x > 0 ? -1 : 1

        path.move(to: start)
        path.addCurve(to: CGPoint(x: playerX + sweepDir * 15, y: -nativeHeight / 4),
                      control1: CGPoint(x: start.x + sweepDir * 20, y: start.y + 10),
                      control2: CGPoint(x: start.x + sweepDir * 40, y: 0))
        path.addCurve(to: CGPoint(x: -sweepDir * nativeWidth / 2, y: -nativeHeight / 2 - 20),
                      control1: CGPoint(x: playerX - sweepDir * 10, y: -nativeHeight / 2 + 20),
                      control2: CGPoint(x: playerX - sweepDir * 30, y: -nativeHeight / 2))

        let follow = SKAction.follow(path, asOffset: false, orientToPath: true, duration: 2.2)
        let loopBack = SKAction.run { [weak self, weak enemy] in
            guard let enemy = enemy, let self = self else { return }
            enemy.state = .returning
            enemy.position = CGPoint(x: enemy.targetSlot.x, y: self.nativeHeight / 2 + 10)
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
        let speed: CGFloat = 110 + CGFloat(stage * 10)

        bullet.userData = ["vx": cos(angle) * speed, "vy": sin(angle) * speed]
    }

    private func updateProjectiles(dt: TimeInterval) {
        // Player Missiles
        for (idx, missile) in playerMissiles.enumerated().reversed() {
            missile.position.y += 180.0 * CGFloat(dt)
            if missile.position.y > nativeHeight / 2 + 10 {
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
                bullet.position.y -= 110.0 * CGFloat(dt)
            }

            if bullet.position.y < -nativeHeight / 2 - 10 || bullet.position.y > nativeHeight / 2 + 10 ||
               bullet.position.x < -nativeWidth / 2 - 10 || bullet.position.x > nativeWidth / 2 + 10 {
                bullet.removeFromParent()
                alienBullets.remove(at: idx)
            }
        }
    }

    private func checkCollisions() {
        // 1. Player Missile vs Enemies
        for (mIdx, missile) in playerMissiles.enumerated().reversed() {
            for (eIdx, enemy) in enemies.enumerated().reversed() {
                if hypot(missile.position.x - enemy.position.x, missile.position.y - enemy.position.y) < 10 {
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
            if hypot(bullet.position.x - player.position.x, bullet.position.y - player.position.y) < 8 {
                bullet.removeFromParent()
                alienBullets.remove(at: bIdx)
                killPlayer()
                return
            }
        }

        // Enemy Ramming Player
        for (eIdx, enemy) in enemies.enumerated().reversed() {
            if hypot(enemy.position.x - player.position.x, enemy.position.y - player.position.y) < 12 {
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

        let delay = SKAction.wait(forDuration: 1.5)
        let respawn = SKAction.run { [weak self] in
            guard let self = self else { return }
            if self.lives > 0 {
                self.isPlayerDead = false
                self.player.isHidden = false
                self.player.position = CGPoint(x: 0, y: -self.nativeHeight / 2 + 16)
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

        let animate = SKAction.animate(with: RetroTextures.shared.explosions, timePerFrame: 0.06)
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

            let wait = SKAction.wait(forDuration: 1.8)
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
        controller.extendedGamepad?.buttonX.valueChangedHandler = { [weak self] (button, value, pressed) in
            if pressed {
                self?.cycleTheme()
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
        controller.microGamepad?.buttonX.valueChangedHandler = { [weak self] (button, value, pressed) in
            if pressed {
                self?.cycleTheme()
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

        if let touch = touches.first {
            let loc = touch.location(in: self)
            // Tap top HUD to switch palettes
            if loc.y > nativeHeight / 2 - 25 {
                cycleTheme()
                return
            }
            player.position.x = loc.x
        }
        isFiring = true
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
            player.position.x -= 20
        case .right:
            player.position.x += 20
        case .up, .down:
            cycleTheme()
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
        case 18: // '1' -> DMG
            setTheme(.dmg)
        case 19: // '2' -> Pocket
            setTheme(.pocket)
        case 20: // '3' -> GBC
            setTheme(.gbc)
        case 21: // '4' -> Arcade
            setTheme(.arcade)
        case 17: // 'T' -> Cycle
            cycleTheme()
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
            let loc = event.location(in: self)
            if loc.y > nativeHeight / 2 - 25 {
                cycleTheme()
                return
            }
            isFiring = true
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
