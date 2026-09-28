//
//  AcctNotificationsPressStyle.swift
//  Duello
//
//  Retour visuel d'appui des commandes de l'écran Notifications.
//
//  Fichier source Expo porté : `src/screens/AccountScreen.tsx:5730`
//  (`pressed: { opacity: 0.75 }`), appliqué aux onglets de tête (`:2186`),
//  aux onglets Amis (`:2233`), à la carte de notification (`:2278`), à la
//  cloche des notifications (`:2644`) et au bouton retour.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Retour d'appui `pressed` de la source : opacité 0,75 tant que le doigt
/// reste posé, rien d'autre (pas d'échelle, pas de fond).
struct AcctPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
