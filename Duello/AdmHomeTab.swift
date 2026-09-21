//
//  AdmHomeTab.swift
//  Duello
//
//  Onglet « Admin » : identité du compte, isolation de l'espace, clé d'accès
//  serveur, exception d'inscription multiple, mot de passe et déconnexion.
//
//  Fichier source Expo porté : src/admin/AdminApp.tsx (vue de l'onglet `admin`,
//  `toggleRegistrationAccess`, effets de chargement et d'enregistrement de la
//  clé). Les libellés sont repris mot pour mot.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// État de la requête d'exception d'inscription (`ipAccessState` du source).
private enum AdmIPPhase {
    case idle, loading, saving, error
}

/// `activeTab === 'admin'` : accueil de l'espace d'administration.
struct AdmHomeTab: View {
    let account: AdmAccount
    @Binding var apiToken: String
    var onChangePassword: (String) async throws -> Void
    var onLogout: () async throws -> Void

    @State private var ipAccess: AdmRegistrationIpAccess?
    @State private var ipPhase: AdmIPPhase = .idle
    @State private var ipMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                isolationCard
                AdmAccessKeyCard(token: $apiToken)
                ipAccessCard
                AdmPasswordCard(onChangePassword: onChangePassword)
                AdmLogoutCard(onLogout: onLogout)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .task(id: apiToken) { await loadIpAccess() }
    }

    /// En-tête : marque de l'espace, nom et adresse du compte admin.
    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.surface)
                .frame(width: 52, height: 52)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            VStack(alignment: .leading, spacing: 3) {
                Text("ESPACE D’ADMINISTRATION")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.primary)
                Text(account.profile.displayName)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text(account.email)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    /// Rappel de l'invariant d'isolation de l'espace d'administration.
    private var isolationCard: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 40, height: 40)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 6) {
                Text("Espace totalement séparé")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("Cet espace ne charge ni le profil, ni la progression, ni le planning d’un compte utilisateur. Sa structure et ses données restent indépendantes de tous les autres comptes.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Exception d'inscription : adresse réseau courante et bascule.
    private var ipAccessCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            AdmCardHeading(icon: "iphone", title: "Comptes multiples sur un même appareil")
            Text("Autorise la création de plusieurs comptes depuis l’adresse réseau de cet appareil : pratique pour installer plusieurs comptes de test sur le même smartphone.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if let ipAccess {
                VStack(alignment: .leading, spacing: 7) {
                    Text(ipAccess.currentIp)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .textSelection(.enabled)
                    Text(ipAccess.unlimited
                        ? "Exception active : comptes illimités depuis cette adresse."
                        : "Aucune exception active pour cette adresse.")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            }
            ipAccessButton
            if !ipMessage.isEmpty {
                Text(ipMessage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ipPhase == .error ? Theme.ink : Theme.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Bouton de bascule de l'exception, désactivé pendant une requête.
    private var ipAccessButton: some View {
        Button {
            Task { await toggleRegistrationAccess() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: ipAccess?.unlimited == true ? "lock" : "checkmark.circle")
                    .font(.system(size: 15, weight: .bold))
                Text(ipAccessButtonTitle)
                    .font(.system(size: 14, weight: .black))
            }
            .foregroundStyle(Theme.surface)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .disabled(isIpAccessBlocked)
        .opacity(isIpAccessBlocked ? 0.55 : 1)
        .accessibilityLabel(ipAccessButtonTitle)
    }

    /// Libellé du bouton, aligné sur les états `loading` / `saving` du source.
    private var ipAccessButtonTitle: String {
        switch ipPhase {
        case .loading: return "Vérification…"
        case .saving: return "Modification…"
        case .idle, .error: return ipAccess?.unlimited == true ? "Retirer l’exception" : "Autoriser les comptes multiples"
        }
    }

    /// Bouton désactivé dans les mêmes cas que le source
    /// (`disabled={!ipAccess || ipAccessState === 'saving'}`).
    private var isIpAccessBlocked: Bool {
        ipAccess == nil || ipPhase == .saving
    }

    /// Une bascule exige un état connu, et aucune requête en cours
    /// (`!ipAccess || saving || loading` dans le source).
    private var canToggleIpAccess: Bool {
        ipAccess != nil && ipPhase != .saving && ipPhase != .loading
    }

    /// Relit l'état de l'exception après une pause de saisie de la clé
    /// (`setTimeout(500)` du source : la clé mémorisée, pas chaque frappe).
    @MainActor
    private func loadIpAccess() async {
        try? await Task.sleep(nanoseconds: 500_000_000)
        if Task.isCancelled { return }
        ipPhase = .loading
        do {
            ipAccess = try await AdmAPI.getRegistrationIpAccess(token: apiToken)
            ipPhase = .idle
            ipMessage = ""
        } catch {
            ipAccess = nil
            ipPhase = .error
            ipMessage = AdmErrorText.message(
                error,
                fallback: "Impossible de vérifier l’exception pour le moment."
            )
        }
    }

    /// `toggleRegistrationAccess` : bascule l'exception d'inscription.
    @MainActor
    private func toggleRegistrationAccess() async {
        guard let current = ipAccess, canToggleIpAccess else { return }
        ipPhase = .saving
        ipMessage = ""
        do {
            let next = try await AdmAPI.setRegistrationIpAccess(
                token: apiToken,
                unlimited: !current.unlimited
            )
            ipAccess = next
            ipPhase = .idle
            ipMessage = next.unlimited
                ? "Création de plusieurs comptes autorisée depuis cette adresse."
                : "Exception retirée : le parcours d’inscription standard s’applique."
        } catch {
            ipPhase = .error
            ipMessage = AdmErrorText.message(
                error,
                fallback: "Impossible de modifier l’exception pour le moment."
            )
        }
    }
}
