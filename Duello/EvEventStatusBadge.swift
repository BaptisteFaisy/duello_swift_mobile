//
//  EvEventStatusBadge.swift
//  Duello
//
//  Pastille de statut d'un événement : petite, en majuscule, posée sur les
//  cartes de la liste comme en haut de la page. Seule l'épreuve en cours
//  s'inverse (blanc sur noir) : passé ou en correction, l'événement n'appelle
//  plus à l'action.
//
//  Fichier source Expo porté : `src/components/event/EventStatusBadge.tsx`
//  (`EventStatusBadge`, `BADGE_LABELS`). Le type `EventStatusBadge` de
//  `src/utils/eventSchedule.ts` devient `EvEventStatusBadgeKey`.
//
//  Cible : iOS 16.
//
import SwiftUI

/// Statut d'un événement (`EventStatusBadge` de `eventSchedule.ts`).
enum EvEventStatusBadgeKey: Equatable {
    case enCours
    case correctionEnCours
    case termine

    /// Libellé affiché, mot pour mot de `BADGE_LABELS`.
    var label: String {
        switch self {
        case .enCours: return "EN COURS"
        case .correctionEnCours: return "CORRECTION EN COURS"
        case .termine: return "TERMINÉ"
        }
    }
}

/// `EventStatusBadge` : pastille de statut d'un événement.
struct EvEventStatusBadge: View {
    let status: EvEventStatusBadgeKey

    /// Seule l'épreuve en cours s'inverse (fond encre, texte blanc).
    private var live: Bool { status == .enCours }

    var body: some View {
        Text(status.label)
            .font(.system(size: 10, weight: .black))
            .tracking(0.6)
            .foregroundStyle(live ? Color.white : Theme.inkSoft)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(live ? Theme.ink : Theme.surfaceMuted)
            .clipShape(Capsule())
            .accessibilityLabel(status.label)
    }
}
