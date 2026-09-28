// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// `AVFoundation` n'existe pas sous Linux. Ce shim couvre ce que Duello utilise
// réellement (mesuré par grep) :
//   * `AVCaptureDevice` (+ `AVMediaType`) — `PhotoPickService.swift`,
//     `RemPhotoCameraPicker.swift`, `PhotoTranscriptionView.swift` ;
//   * `AVAudioEngine` et sa chaîne de nœuds — `DictSpeechEngine.swift`.
// Rien d'exécuté : uniquement de quoi satisfaire le vérificateur de types.
import Foundation

// MARK: - Types de média et autorisation de capture

public struct AVMediaType: Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let video = AVMediaType(rawValue: "vide")
    public static let audio = AVMediaType(rawValue: "soun")
}

public enum AVAuthorizationStatus: Int, Sendable {
    case notDetermined = 0
    case restricted = 1
    case denied = 2
    case authorized = 3
}

open class AVCaptureDevice: NSObject {
    public class func authorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus {
        .notDetermined
    }

    public class func requestAccess(for mediaType: AVMediaType) async -> Bool { false }
}

// MARK: - Moteur audio (AVFAudio)

public typealias AVAudioNodeBus = UInt32
public typealias AVAudioFrameCount = UInt32
public typealias AVAudioChannelCount = UInt32
public typealias AVAudioPacketCount = UInt32
public typealias AVAudioNodeTapBlock = (AVAudioPCMBuffer, AVAudioTime) -> Void

/// Format d'échantillonnage commun (`AVAudioCommonFormat`) — seul
/// `.pcmFormatInt16` est utilisé par `DictAsrRelay`.
public enum AVAudioCommonFormat: UInt, Sendable {
    case otherFormat = 0
    case pcmFormatFloat32 = 1
    case pcmFormatFloat64 = 2
    case pcmFormatInt16 = 3
    case pcmFormatInt32 = 4
}

open class AVAudioFormat: NSObject {
    public var sampleRate: Double = 0
    public var channelCount: AVAudioChannelCount = 0
    public var commonFormat: AVAudioCommonFormat = .pcmFormatFloat32
    public var isInterleaved: Bool = false

    public convenience init?(
        commonFormat: AVAudioCommonFormat,
        sampleRate: Double,
        channels: AVAudioChannelCount,
        interleaved: Bool
    ) {
        self.init()
        self.commonFormat = commonFormat
        self.sampleRate = sampleRate
        self.channelCount = channels
        self.isInterleaved = interleaved
    }
}

open class AVAudioBuffer: NSObject {}

open class AVAudioPCMBuffer: AVAudioBuffer {
    public var format: AVAudioFormat
    public var frameLength: AVAudioFrameCount = 0
    public var int16ChannelData: UnsafeMutablePointer<UnsafeMutablePointer<Int16>>?

    public init?(pcmFormat: AVAudioFormat, frameCapacity: AVAudioFrameCount) {
        self.format = pcmFormat
        super.init()
    }
}

open class AVAudioTime: NSObject {}

open class AVAudioNode: NSObject {
    public func installTap(
        onBus bus: AVAudioNodeBus,
        bufferSize: AVAudioFrameCount,
        format: AVAudioFormat?,
        block: @escaping AVAudioNodeTapBlock
    ) {}

    public func removeTap(onBus bus: AVAudioNodeBus) {}
    public func outputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat { AVAudioFormat() }
}

open class AVAudioInputNode: AVAudioNode {}

open class AVAudioEngine: NSObject {
    public var inputNode: AVAudioInputNode { AVAudioInputNode() }
    public var isRunning: Bool = false

    public func prepare() {}
    public func start() throws {}
    public func stop() {}
}

// MARK: - Convertisseur de format (AVAudioConverter)

/// État d'entrée rendu par le bloc d'alimentation du convertisseur.
public enum AVAudioConverterInputStatus: Int, Sendable {
    case haveData = 0
    case noDataNow = 1
    case endOfStream = 2
}

/// État de sortie rendu par `AVAudioConverter.convert(to:error:withInputFrom:)`.
public enum AVAudioConverterOutputStatus: Int, Sendable {
    case haveData = 0
    case inputRanDry = 1
    case endOfStream = 2
    case error = 3
}

public typealias AVAudioConverterInputBlock =
    (AVAudioPacketCount, UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer?

open class AVAudioConverter: NSObject {
    public init?(from: AVAudioFormat, to: AVAudioFormat) { super.init() }

    public func convert(
        to outputBuffer: AVAudioBuffer,
        error outError: UnsafeMutablePointer<NSError?>?,
        withInputFrom inputBlock: @escaping AVAudioConverterInputBlock
    ) -> AVAudioConverterOutputStatus {
        .haveData
    }
}

// MARK: - Session audio (AVFAudio)
//
// `AVAudioSession` : utilisée par `DictSpeechEngine` et `DictAsrRelay+Capture`
// (`setCategory(_:mode:options:)`, `setActive(_:options:)`,
// `requestRecordPermission`). Aucune de ces méthodes n'est exécutée.

open class AVAudioSession: NSObject {
    public static func sharedInstance() -> AVAudioSession { AVAudioSession() }

    public struct Category: Hashable, RawRepresentable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let ambient = Category(rawValue: "ambient")
        public static let soloAmbient = Category(rawValue: "soloAmbient")
        public static let playback = Category(rawValue: "playback")
        public static let record = Category(rawValue: "record")
        public static let playAndRecord = Category(rawValue: "playAndRecord")
        public static let multiRoute = Category(rawValue: "multiRoute")
    }

    public struct Mode: Hashable, RawRepresentable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let `default` = Mode(rawValue: "default")
        public static let measurement = Mode(rawValue: "measurement")
        public static let voiceChat = Mode(rawValue: "voiceChat")
        public static let gameChat = Mode(rawValue: "gameChat")
        public static let videoRecording = Mode(rawValue: "videoRecording")
        public static let voicePrompt = Mode(rawValue: "voicePrompt")
    }

    public struct CategoryOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }

        public static let mixWithOthers = CategoryOptions(rawValue: 1 << 0)
        public static let duckOthers = CategoryOptions(rawValue: 1 << 1)
        public static let allowBluetooth = CategoryOptions(rawValue: 1 << 2)
        public static let defaultToSpeaker = CategoryOptions(rawValue: 1 << 3)
        public static let allowBluetoothA2DP = CategoryOptions(rawValue: 1 << 4)
        public static let interruptSpokenAudioAndMixWithOthers = CategoryOptions(rawValue: 1 << 5)
    }

    public struct SetActiveOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }

        public static let notifyOthersOnDeactivation = SetActiveOptions(rawValue: 1 << 0)
    }

    public func setCategory(_ category: Category) throws {}

    public func setCategory(_ category: Category, mode: Mode, options: CategoryOptions = []) throws {}

    public func setActive(_ active: Bool, options: SetActiveOptions = []) throws {}

    public func requestRecordPermission(_ response: @escaping (Bool) -> Void) {}
}
