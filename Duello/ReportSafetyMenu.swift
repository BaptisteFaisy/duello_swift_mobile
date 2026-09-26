//
//  ReportSafetyMenu.swift
//  Duello
//
//  Lot « Report » — menu d'actions de sécurité d'une fiche : signaler, puis
//  bloquer.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/ProfileSafetyMenu.tsx (ProfileSafetyMenu,
//                                            ProfileSafetyMenuItems)
//
//  Limite assumée : Expo dessine un menu sombre flottant ancré au déclencheur
//  (`DropdownOverlay`) ; ici le menu natif `Menu` de SwiftUI est employé — il ne
//  peut pas être teinté en sombre, mais porte les mêmes actions. Le blocage en
//  cours remplace l'ellipse par une roue d'attente, comme `ActivityIndicator`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Menu d'actions de sécurité d'une fiche (`ProfileSafetyMenu.tsx`).
struct ReportSafetyMenu: View {
    /// Blocage en cours : le déclencheur montre une roue d'attente.
    let blocking: Bool
    /// Blocage indisponible : l'action « Bloquer » est désactivée.
    let disabled: Bool
    let memberName: String
    let onBlock: () -> Void
    let onReport: () -> Void

    var body: some View {
        Menu {
            Button(action: onReport) {
                Label("Signaler", systemImage: "flag")
            }
            .accessibilityLabel("Signaler \(memberName)")

            Divider()

            Button(action: onBlock) {
                Label("Bloquer", systemImage: "hand.raised")
            }
            .disabled(disabled)
            .accessibilityLabel("Bloquer \(memberName)")
        } label: {
            trigger
        }
        .accessibilityLabel("Plus d’actions pour \(memberName)")
    }

    private var trigger: some View {
        Group {
            if blocking {
                ProgressView().progressViewStyle(.circular).tint(Theme.surface)
            } else {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.surface)
                    .rotationEffect(.degrees(90))
            }
        }
        .frame(width: 32, height: 40)
        .background(Theme.ink)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }
}
