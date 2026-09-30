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
//  V1 (2026-09-26) — écart U08#2 : `AcctInfoDeleteRow` exécute désormais la
//  suppression réelle (`onDelete` asynchrone et faillible), avec l'état
//  « Suppression en cours… » et l'alerte « Compte non supprimé » de
//  `handleDeleteAccount` (`AccountScreen.tsx:861-875`).
//
//  V2 (2026-09-29) — écart P2 : la ligne « Duello » retrouve une icône. Le PNG
//  cube Duello (`DUELLO_CUBE_LOGO_SOURCE`, `AccountScreen.tsx:104,3872`) n'est
//  pas embarqué dans le bundle Swift et le nom fourni par la page
//  (`AcctInfoPages.swift:90`, `cube.transparent`) n'est pas un glyphe Ionicons :
//  `leadingIcon` retombe désormais sur le glyphe Ionicons `cube-outline`, équi-
//  valent au logo cube. L'embarquement du PNG reste à raccorder (cf. rapport).
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
                IonIcon(name: "chevron-forward", size: 20, color: Theme.inkFaint)
            }
            .frame(minHeight: 60)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ouvrir \(label)")
    }

    /// Icône de tête : asset si présent dans le bundle, sinon glyphe Ionicons,
    /// sinon repli cube (le PNG cube Duello n'est pas embarqué — écart assumé).
    @ViewBuilder private var leadingIcon: some View {
        Group {
            if let assetIcon, UIImage(named: assetIcon) != nil {
                Image(assetIcon).resizable().scaledToFit()
            } else if let icon {
                // RN `SettingsCategoryRow` : `<Ionicons name={icon} … color={colors.ink} />`.
                // Un nom qui n'est pas un glyphe Ionicons (`cube.transparent`,
                // symbole SF passé par la page « Duello ») retombe sur le glyphe
                // cube équivalent au logo Duello, faute du PNG cube embarqué.
                IonIcon(
                    name: IoniconsGlyphs.character(icon) != nil ? icon : "cube-outline",
                    size: iconSize,
                    color: Theme.ink
                )
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
                // RN `passwordToggleIcon` / `compactSettingsIcon` : IonIcon teinté.
                IonIcon(name: icon, size: iconSize, color: tint)
                    .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
                    .background(Theme.surface)
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if showsChevron {
                    IonIcon(name: "chevron-forward", size: 20, color: Theme.inkFaint)
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
            // RN `visibilityIcon` : IonIcon teinté.
            IonIcon(name: icon, size: iconSize, color: tint)
                .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
                .background(Theme.surface)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if let description {
                    Text(description)
                        // `privateAccountDescription` (`AccountScreen.tsx:5882-5887`) :
                        // `inkSoft`, 12, **sans graisse** (400), interligne 17.
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            // `Switch` de la source : piste `surfaceMuted` / `primaryLight`,
            // pouce `primary` / `inkFaint` (le `Toggle` natif ne règle ni la
            // piste éteinte ni la couleur du pouce).
            AcctInfoSwitch(isOn: $isOn, disabled: isDisabled)
                .accessibilityLabel(accessibilityLabel ?? title)
        }
        .frame(minHeight: 60)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}

/// Interrupteur des lignes de réglages (`Switch` de `AccountScreen.tsx`) : piste
/// `surfaceMuted` (éteint) / `primaryLight` (allumé), pouce `primary` (allumé) /
/// `inkFaint` (éteint), comme `NotifSwitch` et `AiConsentSwitch`. Mesures iOS de
/// l'interrupteur (piste 51 × 31, pouce 27).
private struct AcctInfoSwitch: View {
    @Binding var isOn: Bool
    var disabled: Bool = false

    var body: some View {
        Button { isOn.toggle() } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Theme.primaryLight : Theme.surfaceMuted)
                    .frame(width: 51, height: 31)
                Circle()
                    .fill(isOn ? Theme.primary : Theme.inkFaint)
                    .frame(width: 27, height: 27)
                    .padding(2)
                    .shadow(color: Color.black.opacity(0.15), radius: 1, y: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
}

/// Ligne de déconnexion (`LogoutControl`) : pictogramme, libellé, et confirmation
/// avant exécution de l'action.
struct AcctInfoLogoutRow: View {
    var actionLabel: String = "Me déconnecter"
    var description: String = "Ton profil et ta progression resteront associés à ce compte."
    var iconSize: CGFloat = AcctInfoRowMetrics.iconSize
    var isBusy: Bool = false
    /// Déconnexion réelle ; lève une erreur si la session ne peut pas être
    /// fermée (RN `LogoutControl` : `onLogout: () => Promise<void>`).
    let onLogout: () async throws -> Void

    @State private var isConfirming = false
    @State private var logoutFailed = false

    var body: some View {
        button
            // RN `LogoutControl.logout` : alerte « Déconnexion impossible » quand
            // la fermeture de session échoue.
            .alert("Déconnexion impossible", isPresented: $logoutFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("La session n’a pas pu être fermée sur cet appareil. Réessaie.")
            }
    }

    private var button: some View {
        Button { isConfirming = true } label: {
            HStack(spacing: 13) {
                // RN `LogoutControl` : `<Ionicons name="log-out-outline" … color={colors.ink} />`.
                IonIcon(name: "log-out-outline", size: iconSize, color: Theme.ink)
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
            Button(actionLabel, role: .destructive) { Task { await performLogout() } }
        } message: {
            Text(description)
        }
    }

    /// `LogoutControl.logout` : tente la déconnexion, signale l'échec.
    @MainActor
    private func performLogout() async {
        do {
            try await onLogout()
        } catch {
            logoutFailed = true
        }
    }
}

/// Ligne de suppression de compte (action en encre), avec la confirmation
/// « Supprimer mon compte ? » de la source, puis l'exécution réelle de la
/// suppression (`handleDeleteAccount` d'`AccountScreen.tsx:861-875`) : état
/// « Suppression en cours… » pendant l'appel serveur et alerte « Compte non
/// supprimé » en cas d'échec.
///
/// V1 (2026-09-26) — écart U08#2 : `onDelete` est la suppression réelle
/// (asynchrone et faillible) au lieu d'un no-op, et `isBusy` est enfin armé.
struct AcctInfoDeleteRow: View {
    var iconSize: CGFloat = AcctInfoRowMetrics.iconSize
    /// Suppression réelle ; lève une erreur si le serveur la refuse.
    let onDelete: () async throws -> Void

    @State private var isConfirming = false
    @State private var isBusy = false
    @State private var errorMessage: String?

    /// `Alert.alert` de la source, titres et messages repris mot pour mot.
    private static let confirmTitle = "Supprimer mon compte ?"
    private static let confirmMessage = "Cette action supprime définitivement ton compte serveur, ta progression, tes copies, ton profil public et tes appareils associés. Cette action est irréversible."
    private static let errorTitle = "Compte non supprimé"
    private static let errorFallback = "La suppression du compte est momentanément indisponible. Réessaie."

    var body: some View {
        button
            .alert(Self.errorTitle, isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? Self.errorFallback)
            }
    }

    private var button: some View {
        Button { isConfirming = true } label: {
            HStack(spacing: 13) {
                if isBusy {
                    ProgressView()
                        .tint(Theme.danger)
                        .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
                } else {
                    // RN : `<Ionicons name="trash-outline" … color={colors.danger} />`.
                    IonIcon(name: "trash-outline", size: iconSize, color: Theme.danger)
                        .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
                        .background(Theme.surface)
                }
                Text(isBusy ? "Suppression en cours…" : "Supprimer mon compte")
                    .font(.system(size: 13, weight: .heavy))
                    // RN `deleteAccountText` : `color: colors.danger`.
                    .foregroundStyle(Theme.danger)
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
            Button("Supprimer définitivement", role: .destructive) { Task { await performDelete() } }
        } message: {
            Text(Self.confirmMessage)
        }
    }

    /// `handleDeleteAccount` : un seul appel à la fois ; un échec rend la main
    /// et affiche « Compte non supprimé » (message du serveur, sinon repli).
    @MainActor
    private func performDelete() async {
        guard !isBusy else { return }
        isBusy = true
        do {
            try await onDelete()
        } catch {
            isBusy = false
            let message = ((error as? LocalizedError)?.errorDescription ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = message.isEmpty ? Self.errorFallback : message
        }
    }

    /// Présence de l'alerte d'échec, reliée à `errorMessage`.
    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
