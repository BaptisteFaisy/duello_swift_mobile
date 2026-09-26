//
//  AcctInfoRows.swift
//  Duello
//
//  Lot 10-C « réglages informations » (préfixe `AcctInfo`).
//  Lignes et cartes réutilisables des quatre pages de réglages.
//
//  Fichiers source Expo portés :
//    - src/screens/AccountScreen.tsx (3590-4132) : lignes des pages
//      « Mes informations », « Mon compte », « Duello » ;
//    - src/components/SettingsCategoryRow.tsx → `AcctInfoCategoryRow` ;
//    - src/components/LogoutControl.tsx → `AcctInfoLogoutRow` ;
//    - src/components/AiConsentCard.tsx → réutilisé via `ConsentAiCard` (existant).
//
//  Les libellés sont repris mot pour mot de la source. Les couleurs et mesures
//  passent par `Theme` ; aucune valeur ne varie en dur hors des constantes ci-dessous.
//
import SwiftUI
import UIKit

/// Mesures partagées des lignes de réglages.
enum AcctInfoRowMetrics {
    /// `INFORMATION_ICON_SIZE` : pictogramme commun des lignes.
    static let iconSize: CGFloat = 22
    /// Logo cube Duello, plus large que les pictogrammes (`iconSize={28}`).
    static let duelloLogoSize: CGFloat = 28
    /// Pastille d'icône des lignes (`compactSettingsIcon`, `passwordToggleIcon`,
    /// `visibilityIcon`, `informationRowIcon`, `compactLogoutIcon`) : 34 × 34.
    static let iconPill: CGFloat = 34
}

/// Jeu de métriques d'une ligne d'action : la source distingue les lignes
/// compactes (`feedbackButton` + `compactSettingsAction`) des lignes e-mail /
/// mot de passe (`passwordToggle`).
enum AcctInfoActionMetrics {
    /// `compactSettingsAction` : pages « Duello » et « Comptes bloqués ».
    case compact
    /// `passwordToggle` : lignes « Modifier mon adresse e-mail » / mot de passe.
    case password

    /// Hauteur minimale de la ligne.
    var minHeight: CGFloat { self == .compact ? 44 : 60 }
    /// Écart entre la pastille, le titre et le chevron.
    var gap: CGFloat { self == .compact ? 13 : 10 }
    /// Retrait vertical interne.
    var verticalPadding: CGFloat { self == .compact ? 5 : 8 }
}

/// Ligne d'accès à une sous-page (`SettingsCategoryRow`) : icône, libellé, chevron.
struct AcctInfoCategoryRow: View {
    /// Pictogramme SF Symbol (repli quand `assetIcon` est absent).
    var icon: String? = nil
    /// Nom d'asset (logo cube Duello) affiché à la place du pictogramme.
    var assetIcon: String? = nil
    var iconSize: CGFloat = AcctInfoRowMetrics.iconSize
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                leadingIcon
                Text(label)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.inkFaint)
            }
            .frame(minHeight: 60)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ouvrir \(label)")
    }

    /// Icône de tête : asset si présent dans le bundle, sinon SF Symbol.
    @ViewBuilder private var leadingIcon: some View {
        Group {
            if let assetIcon, UIImage(named: assetIcon) != nil {
                Image(assetIcon).resizable().scaledToFit()
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            } else {
                Color.clear
            }
        }
        .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
    }
}

/// Ligne d'action compacte (`feedbackButton` / `passwordToggle`) : pictogramme
/// teinté dans une pastille 34 × 34, titre 13 / 800, chevron facultatif. Sert aux
/// pages « Duello », « Comptes bloqués » et aux lignes e-mail / mot de passe.
struct AcctInfoActionRow: View {
    let icon: String
    let title: String
    var tint: Color = Theme.primary
    var iconSize: CGFloat = AcctInfoRowMetrics.iconSize
    var metrics: AcctInfoActionMetrics = .compact
    var showsChevron: Bool = true
    var accessibilityLabel: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: metrics.gap) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
                    .background(Theme.surface)
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            .frame(minHeight: metrics.minHeight)
            .padding(.horizontal, 8)
            .padding(.vertical, metrics.verticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? title)
    }
}

/// Ligne à interrupteur : pictogramme dans une pastille 34 × 34, titre
/// 13 / 800, description facultative, `Toggle`. Reprend le motif aligné au
/// centre « icône + titre + description + Switch » de la source.
struct AcctInfoToggleRow: View {
    let icon: String
    let title: String
    var description: String? = nil
    var tint: Color = Theme.primary
    var iconSize: CGFloat = AcctInfoRowMetrics.iconSize
    @Binding var isOn: Bool
    var isDisabled: Bool = false
    var accessibilityLabel: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
                .background(Theme.surface)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if let description {
                    Text(description)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.primary)
                .disabled(isDisabled)
                .accessibilityLabel(accessibilityLabel ?? title)
        }
        .frame(minHeight: 60)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}

/// Ligne de déconnexion (`LogoutControl`) : pictogramme, libellé, et confirmation
/// avant exécution de l'action.
struct AcctInfoLogoutRow: View {
    var actionLabel: String = "Me déconnecter"
    var description: String = "Ton profil et ta progression resteront associés à ce compte."
    var iconSize: CGFloat = AcctInfoRowMetrics.iconSize
    var isBusy: Bool = false
    let onLogout: () -> Void

    @State private var isConfirming = false

    var body: some View {
        Button { isConfirming = true } label: {
            HStack(spacing: 13) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
                    .background(Theme.surface)
                Text(actionLabel)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel(actionLabel)
        .alert("\(actionLabel) ?", isPresented: $isConfirming) {
            Button("Annuler", role: .cancel) {}
            Button(actionLabel, role: .destructive) { onLogout() }
        } message: {
            Text(description)
        }
    }
}

/// Ligne de suppression de compte (action en encre), avec la confirmation
/// « Supprimer mon compte ? » de la source.
struct AcctInfoDeleteRow: View {
    var isBusy: Bool = false
    var iconSize: CGFloat = AcctInfoRowMetrics.iconSize
    let onDelete: () -> Void

    @State private var isConfirming = false

    /// `Alert.alert` de la source, titre et message repris mot pour mot.
    private static let confirmTitle = "Supprimer mon compte ?"
    private static let confirmMessage = "Cette action supprime définitivement ton compte serveur, ta progression, tes copies, ton profil public et tes appareils associés. Cette action est irréversible."

    var body: some View {
        Button { isConfirming = true } label: {
            HStack(spacing: 13) {
                if isBusy {
                    ProgressView()
                        .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
                } else {
                    Image(systemName: "trash")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
                        .background(Theme.surface)
                }
                Text(isBusy ? "Suppression en cours…" : "Supprimer mon compte")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
            }
            .frame(minHeight: 52)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel(isBusy ? "Suppression du compte en cours" : "Supprimer définitivement mon compte")
        .alert(Self.confirmTitle, isPresented: $isConfirming) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer définitivement", role: .destructive) { onDelete() }
        } message: {
            Text(Self.confirmMessage)
        }
    }
}
