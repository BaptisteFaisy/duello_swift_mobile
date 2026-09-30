//
//  CtdDocumentReadSupport.swift
//  Duello
//
//  Port de `src/utils/courseDocumentData.ts` et `src/utils/courseDocumentFile.ts`
//  (+ `src/components/CourseUnreadableNotice.tsx`) : lecture d'un document de
//  cours, distinction « fichier introuvable » / « cours illisible », journal du
//  motif exact et bandeau « le prof IA ne peut pas lire ce cours ».
//
//  Un cours enregistré peut manquer (fichier effacé de l'appareil) ou rester
//  illisible (contenu corrompu, lecture impossible). Le lecteur propose une
//  réimportation dans le premier cas, un réessai dans le second
//  (`CourseDocumentViewer.native.tsx:136-166`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import SwiftUI

// MARK: - Motif d'échec de lecture

/// `CourseDocumentReadFailure` : un cours enregistré peut manquer (fichier
/// effacé de l'appareil) ou rester illisible (contenu corrompu). Le lecteur
/// propose une réimportation dans le premier cas, un réessai dans le second.
enum CtdDocumentReadFailure: Equatable {
    /// Fichier effacé de l'appareil : à réimporter.
    case missing
    /// Contenu corrompu ou lecture impossible : à réessayer.
    case unreadable

    /// `logCourseReadFailure` : libellé journalisé du motif.
    var logLabel: String {
        self == .missing ? "Course file missing" : "Course unreadable"
    }
}

/// `CourseDocumentReadError` : erreur de lecture d'un document local, portant
/// son motif affichable.
enum CtdDocumentError: LocalizedError {
    case missing
    case unreadable

    /// Motif affichable (`CourseDocumentReadError.failure`).
    var failure: CtdDocumentReadFailure {
        self == .missing ? .missing : .unreadable
    }

    var errorDescription: String? {
        self == .missing ? "Fichier du cours introuvable" : "Cours illisible"
    }
}

/// `logCourseReadFailure` (`useCourseDocumentMessages.ts:24-28`) : l'écran
/// d'erreur n'affiche qu'un motif générique, ce journal garde la cause exacte
/// pour le diagnostic.
func logCourseReadFailure(_ failure: CtdDocumentReadFailure, detail: String?) {
    if let detail, !detail.isEmpty {
        print("[cours] \(failure.logLabel): \(detail)")
    } else {
        print("[cours] \(failure.logLabel)")
    }
}

// MARK: - Lecture d'un document local

/// Lecture d'un document local (`readCourseDocumentBase64` de
/// `courseDocumentFile.ts`) : base64 pour une photo, octets pour un PDF.
enum CtdDocumentLoader {
    /// Charge le document : base64 pour une photo, octets pour un PDF.
    static func load(uri: String, mimeType: CtdMimeType) throws -> CtdDocumentPayload {
        let data = try data(uri: uri)
        guard mimeType.isImage else { return .pdf(data) }
        return .image(base64: data.base64EncodedString(), mimeType: mimeType)
    }

    /// Octets du document : fichier local, ou contenu d'une URI `data:`
    /// héritée du web. Un fichier absent de l'appareil lève `missing` (à
    /// réimporter), un contenu illisible `unreadable` (à réessayer).
    static func data(uri: String) throws -> Data {
        if uri.hasPrefix("data:"), let comma = uri.firstIndex(of: ",") {
            let encoded = String(uri[uri.index(after: comma)...])
            guard let decoded = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters) else {
                throw CtdDocumentError.unreadable
            }
            return decoded
        }
        guard let url = fileURL(uri) else { throw CtdDocumentError.unreadable }
        // La fiche du cours et son fichier vivent dans deux stockages séparés :
        // la fiche peut survivre au fichier (données effacées, import ancien).
        // Le lecteur propose alors une réimportation, pas un réessai voué à
        // l'échec (`courseDocumentFile.ts:21-24`).
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CtdDocumentError.missing
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw CtdDocumentError.unreadable
        }
    }

    /// `data:` ou `file://` acceptés ; un chemin nu devient une URL de
    /// fichier.
    static func fileURL(_ uri: String) -> URL? {
        if uri.hasPrefix("data:") { return nil }
        if uri.contains("://") { return URL(string: uri) }
        return URL(fileURLWithPath: uri)
    }
}

// MARK: - Calque de texte du prof IA

/// Compteur de mots du calque de texte (`wordsRef` de
/// `useCourseDocumentMessages.ts:53`) : mots exposés par le document et mots
/// effectivement devenus sélectionnables.
struct CtdProfWordTally {
    var items = 0
    var spans = 0
}

// MARK: - Bandeau « prof IA ne peut pas lire »

/// `CourseUnreadableNotice` : avertissement sous un cours que le prof IA ne
/// peut pas lire. Le cours reste consultable : c'est la sélection pour le prof
/// qui a échoué. Sans ce bandeau, l'élève ne voit qu'un PDF correct qui ne se
/// surligne pas, sans bouton et sans explication.
struct CtdCourseUnreadableNotice: View {
    var body: some View {
        Text("Le prof IA ne peut pas lire ce cours : son texte n’est pas sélectionnable. Le cours reste consultable normalement.")
            .font(.system(size: 13))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.surfaceMuted)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }
    }
}

// MARK: - Bouton d'échec du lecteur

/// Bouton « Réessayer » / « Réimporter » du lecteur (`styles.retryButton`,
/// `CourseDocumentViewer.native.tsx:197-203`).
struct CtdRetryButton: View {
    let title: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Couleurs du lecteur

/// Couleurs du lecteur (`CourseDocumentViewer.native.tsx:186-187`) : le fond du
/// document est `#E9E9E7`, distinct de `Theme.surfaceMuted` (`#F4F5F4`).
enum CtdDocumentStyle {
    static var readerBackground: Color { Color(hex: 0xE9E9E7) }
}
