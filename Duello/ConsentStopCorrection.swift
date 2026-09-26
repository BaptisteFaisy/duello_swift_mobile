//
//  ConsentStopCorrection.swift
//  Duello
//
//  Confirmation avant d'arrêter une correction en cours : libellés et
//  présentation de la boîte de dialogue.
//
//  Fichier source Expo porté :
//    - `src/components/correction-summary/confirmStopCorrection.ts`
//      (`confirmStopCorrection(onQuit)`, via `AppAlert.alert`).
//
//  La source est impérative (elle ouvre l'alerte au moment de l'appel) ; en
//  SwiftUI la présentation se fait depuis une vue, d'où le modificateur
//  `ConsentStopCorrectionAlert` à poser sur l'écran de correction. Les libellés
//  sont repris mot pour mot : « Continuer » est destructif (il arrête la
//  correction), « Annuler » referme la boîte.
//
//  Cible : iOS 16.
//
import SwiftUI

/// Confirmation d'arrêt d'une correction (`confirmStopCorrection`).
enum ConsentStopCorrection {

    /// `AppAlert.alert` : titre.
    static let title = "Arrêter la correction ?"

    /// Message de la boîte.
    static let message = "Si tu continues, la correction en cours s’arrêtera."

    /// Bouton d'annulation (`style: 'cancel'`).
    static let cancelLabel = "Annuler"

    /// Bouton de confirmation (`style: 'destructive'`).
    static let confirmLabel = "Continuer"
}

// MARK: - Présentation

/// Présente la confirmation d'arrêt quand `isPresented` passe à vrai.
struct ConsentStopCorrectionAlert: ViewModifier {

    /// Déclencheur de la boîte, piloté par l'écran de correction.
    @Binding var isPresented: Bool
    /// Action confirmée : arrêter la correction (`onQuit`).
    let onQuit: () -> Void

    func body(content: Content) -> some View {
        content.alert(ConsentStopCorrection.title, isPresented: $isPresented) {
            Button(ConsentStopCorrection.cancelLabel, role: .cancel) {}
            Button(ConsentStopCorrection.confirmLabel, role: .destructive, action: onQuit)
        } message: {
            Text(ConsentStopCorrection.message)
        }
    }
}

extension View {
    /// Pose la confirmation d'arrêt de correction sur un écran
    /// (`confirmStopCorrection(onQuit:)`).
    func consentStopCorrectionAlert(
        isPresented: Binding<Bool>,
        onQuit: @escaping () -> Void
    ) -> some View {
        modifier(ConsentStopCorrectionAlert(isPresented: isPresented, onQuit: onQuit))
    }
}
