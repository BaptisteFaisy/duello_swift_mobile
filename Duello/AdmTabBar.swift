//
//  AdmTabBar.swift
//  Duello
//
//  Navigation par onglets de l'espace d'administration.
//
//  Fichier source Expo porté : src/admin/AdminApp.tsx (`AdminTab`,
//  `AdminTabButton`, barre du bas). Les libellés et l'ordre des onglets sont
//  repris mot pour mot : Stats, Admin, Users, Waitlist, Promo, Rapports,
//  Feedback.
//
//  L'espace admin garde sa propre barre : il ne réutilise pas la navigation de
//  l'application élève (`MainTabView`), qui ne doit jamais s'afficher ici.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// `AdminTab` : les sept onglets de l'espace d'administration.
enum AdmTab: String, CaseIterable, Identifiable {
    case analytics
    case admin
    case users
    case waitlist
    case promo
    case reports
    case feedback

    var id: String { rawValue }

    /// Libellé de l'onglet (`label` de `AdminTabButton`).
    var title: String {
        switch self {
        case .analytics: return "Stats"
        case .admin: return "Admin"
        case .users: return "Users"
        case .waitlist: return "Waitlist"
        case .promo: return "Promo"
        case .reports: return "Rapports"
        case .feedback: return "Feedback"
        }
    }

    /// Icône de l'onglet, transposée des noms Ionicons du source.
    var systemImage: String {
        switch self {
        case .analytics: return "chart.bar"
        case .admin: return "checkmark.shield"
        case .users: return "person.2"
        case .waitlist: return "envelope"
        case .promo: return "tag"
        case .reports: return "ladybug"
        case .feedback: return "bubble.left.and.bubble.right"
        }
    }
}

/// Barre d'onglets du bas (`bottomNav` de `AdminApp.tsx`).
struct AdmTabBar: View {
    @Binding var active: AdmTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AdmTab.allCases) { tab in
                button(for: tab)
            }
        }
        .frame(minHeight: 62)
        .padding(.top, 6)
        .background(Theme.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }

    private func button(for tab: AdmTab) -> some View {
        Button {
            active = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(tab == active ? Theme.primary : Theme.inkFaint)
                Text(tab.title)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(tab == active ? Theme.primary : Theme.inkFaint)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(tab == active ? [.isSelected] : [])
    }
}
