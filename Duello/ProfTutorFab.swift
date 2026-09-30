//
//  ProfTutorFab.swift
//  Duello
//
//  Port de `src/components/prof-tutor/ProfTutorFab.tsx` (RN) — boutons flottants
//  du logiciel ordinateur téléchargé, en bas à droite : le prof en question
//  libre (panneau latéral, jamais plein écran) et, dessous, un bouton lecture
//  réservé, sans action pour l'instant. Le bouton du prof s'efface pendant la
//  discussion (`request !== null`).
//
//  La feuille est présentée par `.sheet(item:)` — comme les deux autres hôtes
//  (`CourseDocumentView`, `AnnReaderCore`) — plutôt qu'inline comme le `Modal`
//  du RN ; le glissement vers le bas remet l'item à `nil` via `onDismiss`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import SwiftUI

/// `ProfTutorFab` : pile de boutons flottants du prof IA et de la lecture.
struct ProfTutorFab: View {
    /// Contexte de la page courante. Le bouton du logiciel ordinateur ne connaît
    /// pas de chapitre : l'écran lui passe au moins l'identité de l'élève et le
    /// programme qu'il suit (`profStudentContext`).
    let context: ProfTutorContext
    /// Jeton de session Duello, posé depuis `SessionStore`.
    var token: String? = nil
    /// Fourni : le chevron de l'en-tête du panneau ouvre la fiche du prof IA
    /// (même couture que `CourseDocumentView` et `AnnReaderCore`).
    var onOpenProfile: ((String) -> Void)? = nil

    /// Demande posée par le bouton du prof ; `nil` referme la feuille.
    @State private var request: ProfTutorRequest?

    var body: some View {
        VStack(spacing: 0) {
            // Le bouton du prof s'efface pendant la discussion.
            if request == nil {
                fabButton(icon: "school-outline", label: "Ouvrir le prof IA") {
                    request = ProfTutorRequest(quote: "", context: context)
                }
                .padding(.bottom, 12)
            }
            // Bouton réservé : aucune action pour l'instant.
            fabButton(icon: "play", label: "Lecture") {}
        }
        .padding(.trailing, 24)
        .padding(.bottom, 24)
        .sheet(item: $request, onDismiss: { request = nil }) { req in
            ProfTutorSheet(
                request: req,
                token: token,
                onOpenProfile: onOpenProfile,
                onClose: { request = nil }
            )
        }
    }

    /// Bouton rond 56 × 56, fond `primary`, glyphe blanc 26, ombre de carte
    /// (`styles.fab` : `borderRadius: 28`, `...cardShadow`).
    private func fabButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            IonIcon(name: icon, size: 26, color: .white)
                .frame(width: 56, height: 56)
                .background(Theme.primary)
                .clipShape(Circle())
                .duelloShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
