// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// `PDFKit` n'existe pas sous Linux. Un seul appelant, `CoursePdfView.swift` :
// `PDFView` (dérivé de `UIView` pour `UIViewRepresentable`) et `PDFDocument`,
// plus le calque de sélection (`PDFPage`, `PDFSelection`,
// `PDFViewSelectionChanged`).
import Foundation
import UIKit

public enum PDFDisplayMode: Int, Sendable {
    case singlePage = 0
    case singlePageContinuous = 1
    case twoUp = 2
    case twoUpContinuous = 3
}

public enum PDFDisplayDirection: Int, Sendable {
    case horizontal = 0
    case vertical = 1
}

open class PDFDocument: NSObject {
    public init?(data: Data) { super.init() }
    public init?(url: URL) { super.init() }

    public var pageCount: Int { 0 }
    public var isLocked: Bool { false }

    /// `PDFDocument.index(for:)` — **c'est le document qui indexe les pages**,
    /// pas la vue (`PDFView.index(for:)` n'existe pas dans le SDK réel).
    public func index(for page: PDFPage) -> Int { 0 }
}

/// `PDFPage` : page du document, porteuse du texte sélectionnable.
open class PDFPage: NSObject {
    public override init() { super.init() }

    public var string: String? { nil }
}

/// `PDFSelection` : sélection de texte, source du « Expliquer ce passage ».
open class PDFSelection: NSObject {
    public override init() { super.init() }

    public var string: String? { nil }
    public var pages: [PDFPage] { [] }

    public func bounds(for page: PDFPage) -> CGRect { .zero }
}

open class PDFView: UIView {
    public override init() { super.init() }

    public var autoScales: Bool = false
    public var displayMode: PDFDisplayMode = .singlePageContinuous
    public var displayDirection: PDFDisplayDirection = .vertical
    public var displayBox: Int = 0
    public var document: PDFDocument?
    public var currentSelection: PDFSelection?

    public func convert(_ rect: CGRect, from page: PDFPage) -> CGRect { .zero }
    public func goToFirstPage(_ sender: Any?) {}
    public func goToLastPage(_ sender: Any?) {}
}

public extension Notification.Name {
    /// Émise par `PDFView` quand la sélection courante change.
    static let PDFViewSelectionChanged = Notification.Name("PDFViewSelectionChanged")
}

