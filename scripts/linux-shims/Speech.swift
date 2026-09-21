// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// `Speech` n'existe pas sous Linux. Un seul appelant, `DictSpeechEngine.swift`
// (dont tout le corps est sous `#if canImport(Speech) && canImport(AVFoundation)`,
// donc ACTIF dès que les deux shims existent) : `SFSpeechRecognizer` et sa
// chaîne requête/tâche/résultat, plus l'autorisation.
import Foundation
import AVFoundation

public enum SFSpeechRecognizerAuthorizationStatus: Int, Sendable {
    case notDetermined = 0
    case denied = 1
    case restricted = 2
    case authorized = 3
}

open class SFTranscriptionSegment: NSObject {}

open class SFTranscription: NSObject {
    public var formattedString: String { "" }
    public var segments: [SFTranscriptionSegment] { [] }
}

open class SFSpeechRecognitionResult: NSObject {
    public var bestTranscription: SFTranscription { SFTranscription() }
    public var transcriptions: [SFTranscription] { [] }
    public var isFinal: Bool { false }
}

open class SFSpeechRecognitionRequest: NSObject {
    public var shouldReportPartialResults: Bool = false
    public var requiresOnDeviceRecognition: Bool = false
    public var addsPunctuation: Bool = false
}

open class SFSpeechAudioBufferRecognitionRequest: SFSpeechRecognitionRequest {
    public func append(_ audioPCMBuffer: AVAudioPCMBuffer) {}
    public func endAudio() {}
}

open class SFSpeechRecognitionTask: NSObject {
    public var isFinishing: Bool { false }
    public var isCancelled: Bool { false }

    public func finish() {}
    public func cancel() {}
}

open class SFSpeechRecognizer: NSObject {
    public init?(locale: Locale) { super.init() }

    public var locale: Locale { Locale(identifier: "en-US") }
    public var isAvailable: Bool { false }

    public func recognitionTask(
        with request: SFSpeechRecognitionRequest,
        resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void
    ) -> SFSpeechRecognitionTask {
        SFSpeechRecognitionTask()
    }

    public static func requestAuthorization(
        _ handler: @escaping (SFSpeechRecognizerAuthorizationStatus) -> Void
    ) {}
}
