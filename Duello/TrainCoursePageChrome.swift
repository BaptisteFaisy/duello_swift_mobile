import SwiftUI

// V3 2026-09-29 (complexité) : extension extraite de `TrainCoursePage.swift`
// (boutons d'import / remplacement / suppression) et types auxiliaires du bloc
// « Mon cours » (onglets, alertes, lecteur plein écran). `TrainFlashcardPanelTab`
// et `TrainFlashcardDeckNaming` proviennent de `TrainFlashcardsPanel.swift`
// (retirés de ce fichier pour repasser sous 500 lignes) : ce sont les onglets et
// l'espace de noms de la surface « Cartes » hébergée par la page, ils rejoignent
// donc les types auxiliaires du bloc « cours ». Les membres étaient `private` ;
// `private` en Swift est limité au FICHIER, ils sont élargis à `internal`
// (corps inchangés).

extension TrainCoursePage {
    /// Bouton d'import initial (`Télécharger mon cours`).
    var uploadButton: some View {
        Button {
            pickerVisible = true
        } label: {
            HStack(spacing: 8) {
                IonIcon(name: "cloud-upload-outline", size: 20, color: Theme.surface)
                Text(uploadPending ? "Import en cours…" : "Télécharger mon cours")
                    .font(.system(size: 15, weight: .heavy))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(DuelloPrimaryButton())
        .disabled(uploadPending)
        .accessibilityLabel("Importer mon cours en PDF, JPEG ou PNG")
    }

    /// Bouton de remplacement (`Remplacer le document`, `8438`).
    var replaceButton: some View {
        Button {
            pickerVisible = true
        } label: {
            HStack(spacing: 8) {
                IonIcon(name: "refresh-outline", size: 17, color: Theme.ink)
                Text(uploadPending ? "Import en cours…" : "Remplacer le document")
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(uploadPending || deletePending)
        .accessibilityLabel("Remplacer le document du cours")
    }

    /// Bouton de suppression (`Supprimer le document`, `confirmCourseDocumentDeletion`).
    var deleteButton: some View {
        Button {
            alert = .confirmDeletion
        } label: {
            HStack(spacing: 8) {
                IonIcon(name: "trash-outline", size: 17, color: Color(hex: 0xA31616))
                Text(deletePending ? "Suppression en cours…" : "Supprimer le document")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(Color(hex: 0xA31616))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(uploadPending || deletePending)
        .accessibilityLabel("Supprimer le document du cours")
    }
}

/// Onglets de la page « Mon cours » (`coursePage` + `flashcardPanel`) :
/// « Lire », puis les trois sections de cartes.
enum TrainCoursePageTab: String, CaseIterable, Identifiable {
    case lire
    case generate
    case create
    case review

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lire: return "Lire"
        case .generate: return "Générer"
        case .create: return "Créer"
        case .review: return "Réviser"
        }
    }

    var ionName: String {
        switch self {
        case .lire: return "book-outline"
        case .generate: return "sparkles-outline"
        case .create: return "add-outline"
        case .review: return "play-outline"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .lire: return "Lire mon cours"
        case .generate: return "Générer les flashcards"
        case .create: return "Créer une flashcard"
        case .review: return "Réviser mes flashcards"
        }
    }

    /// Onglet de cartes correspondant (`nil` pour « Lire »).
    var flashcardPanel: TrainFlashcardPanelTab? {
        switch self {
        case .lire: return nil
        case .generate: return .generate
        case .create: return .create
        case .review: return .review
        }
    }
}

/// Alertes de la page « Mon cours », libellés Expo mot pour mot.
enum TrainCourseAlert: Equatable {
    case confirmDeletion
    case importFailed
    case deleteFailed

    var message: String {
        switch self {
        case .confirmDeletion:
            return "Le document et son repère seront supprimés. Tes flashcards et tes notes seront conservées."
        case .importFailed:
            return "Choisis un fichier PDF, JPEG ou PNG lisible, puis réessaie."
        case .deleteFailed:
            return "Le document n’a pas pu être supprimé. Réessaie dans un instant."
        }
    }
}

/// Lecteur plein écran de la page « Mon cours » (`courseFullscreenOpen`) :
/// en-tête blanc 54, bouton réduire, lecteur sur toute la hauteur restante.
struct TrainCourseFullscreen: View {
    let document: CtdStoredCourseDocument
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                Button(action: onClose) {
                    IonIcon(name: "contract-outline", size: 24, color: Theme.ink)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Réduire le cours")
            }
            .padding(.trailing, 8)
            .frame(minHeight: 54)
            .background(Theme.surface)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.border).frame(height: 1)
            }
            CtdDocumentViewer(
                uri: document.uri,
                mimeType: document.mimeType,
                revision: document.uploadedAt,
                height: .infinity,
                // Le plein écran montre le même cours : même texte joint au
                // prof IA que le lecteur de la page.
                courseDocument: document
            )
        }
        .background(Theme.surfaceMuted)
    }
}

/// Onglets de la surface « Cartes » : Générer / Créer / Réviser.
enum TrainFlashcardPanelTab: String, CaseIterable, Identifiable {
    case generate
    case create
    case review

    var id: String { rawValue }

    var label: String {
        switch self {
        case .generate: return "Générer"
        case .create: return "Créer"
        case .review: return "Réviser"
        }
    }

    var ionName: String {
        switch self {
        case .generate: return "sparkles-outline"
        case .create: return "add-outline"
        case .review: return "play-outline"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .generate: return "Générer les flashcards"
        case .create: return "Créer une flashcard"
        case .review: return "Réviser mes flashcards"
        }
    }
}

/// Normalisation d'un nom de paquet personnalisé (`custom-…`). Espace de noms
/// distinct de la vue `TrainFlashcardsPanel` (une seule déclaration de type par
/// nom).
enum TrainFlashcardDeckNaming {
    /// Clé `custom-xxx` ASCII (`normalize('NFD')`, minuscules, tirets).
    static func customDeckKey(_ label: String, fallback: Double) -> String {
        let folded = label.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let slug = folded.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return "custom-\(slug.isEmpty ? String(Int(fallback)) : slug)"
    }

    /// Suffixe aléatoire d'une carte manuelle (`Math.random().toString(36)`).
    static func randomSuffix() -> String {
        let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        return String((0..<6).map { _ in alphabet[Int.random(in: 0..<alphabet.count)] })
    }
}
