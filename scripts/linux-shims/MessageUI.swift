// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// `MessageUI` n'existe pas sous Linux. Duello n'utilise que le composeur SMS
// (`EvEventShareSheet.swift`, `EvEventActionsBar.swift`).
//
// `MFMailComposeViewController` / `MFMailComposeViewControllerDelegate` sont
// volontairement absents : aucun `grep MFMail` dans Duello/ ne les trouve
// (contrairement à ce qu'annonce le tableau de SHIM_SPEC.md).
import Foundation
import UIKit

public enum MFMessageComposeResult: Int, Sendable {
    case cancelled = 0
    case sent = 1
    case failed = 2
}

public protocol MFMessageComposeViewControllerDelegate: NSObjectProtocol {
    func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MFMessageComposeResult
    )
}

open class MFMessageComposeViewController: UIViewController {
    public var body: String?
    public var recipients: [String]?
    public var subject: String?
    public weak var messageComposeDelegate: MFMessageComposeViewControllerDelegate?

    public class func canSendText() -> Bool { false }
}
