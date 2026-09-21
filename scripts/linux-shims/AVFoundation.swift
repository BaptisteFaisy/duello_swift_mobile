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
public typealias AVAudioNodeTapBlock = (AVAudioPCMBuffer, AVAudioTime) -> Void

open class AVAudioFormat: NSObject {}
open class AVAudioPCMBuffer: NSObject {}
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

    public func prepare() {}
    public func start() throws {}
    public func stop() {}
}
