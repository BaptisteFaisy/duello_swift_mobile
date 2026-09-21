// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// `UniformTypeIdentifiers` n'existe pas sous Linux. Duello n'en utilise qu'une
// chose : `allowedContentTypes: [.pdf, .jpeg, .png]` (`CourseTdView.swift`,
// `CollCompletionPanel.swift`), le paramètre de `fileImporter` déclaré par
// SwiftUI. Seuls ces trois types sont donc déclarés.
import Foundation

public struct UTType: Hashable, Sendable {
    public let identifier: String

    public init(_ identifier: String) { self.identifier = identifier }

    public static let pdf = UTType("com.adobe.pdf")
    public static let jpeg = UTType("public.jpeg")
    public static let png = UTType("public.png")

    public var preferredMIMEType: String? { nil }
}
