// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// `PDFKit` n'existe pas sous Linux. Un seul appelant, `CoursePdfView.swift` :
// `PDFView` (dérivé de `UIView` pour `UIViewRepresentable`) et `PDFDocument`.
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
}

open class PDFView: UIView {
    public override init() { super.init() }

    public var autoScales: Bool = false
    public var displayMode: PDFDisplayMode = .singlePageContinuous
    public var displayDirection: PDFDisplayDirection = .vertical
    public var displayBox: Int = 0
    public var document: PDFDocument?

    public func goToFirstPage(_ sender: Any?) {}
    public func goToLastPage(_ sender: Any?) {}
}
