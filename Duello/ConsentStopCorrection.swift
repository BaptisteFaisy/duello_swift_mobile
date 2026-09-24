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
//  La source est impérative (elle ouvre l'alerte au moment de l'appel) ; le
//  port suit cette forme : `ConsentStopCorrection.confirm(onQuit:)` passe par
//  la fenêtre d'alerte commune `AppAlert` (montée une fois à la racine via
//  `.appAlertHost()`), fermable par le fond (`cancelable: true`). Les libellés
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

    /// `confirmStopCorrection(onQuit)` : ouvre la confirmation via la fenêtre
    /// d'alerte commune (`AppAlert`), fermable par le fond (`cancelable: true`).
    /// `onQuit` n'est appelé qu'à l'appui de « Continuer ».
    static func confirm(onQuit: @escaping () -> Void) {
        AppAlert.alert(
            title,
            message,
            [
                AppAlertButton(cancelLabel, style: .cancel),
                AppAlertButton(confirmLabel, style: .destructive, onPress: onQuit),
            ],
            options: AppAlertOptions(cancelable: true)
        )
    }
}
