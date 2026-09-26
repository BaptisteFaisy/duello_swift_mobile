//
//  AdmUserDetailView.swift
//  Duello
//
//  Détail d'un compte du registre admin : identité, vue d'ensemble, usage.
//
//  Fichier source Expo porté : src/admin/AdminUsersScreen.tsx (`UserDetail`,
//  `Metric`, badges d'annuaire). Les libellés sont repris mot pour mot.
//
//  Le détail ne montre que des indicateurs agrégés : aucun contenu scolaire
//  (réponses, brouillons, copies) n'est affiché, et aucun écran élève n'est
//  réutilisé ici.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// `UserDetail` : fiche d'un compte.
struct AdmUserDetailView: View {
    let user: AdmUserRecord
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                backButton
                identityCard
                AdmSectionLabel(title: "VUE D’ENSEMBLE")
                overviewGrid
                AdmUserUsageSections(user: user)
                privacyCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
    }

    private var metrics: AdmUserUsageMetrics { AdmUserUsageMetrics(usage: user.usage) }

    /// Retour à la liste (`BackButton` du source).
    private var backButton: some View {
        Button(action: onBack) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                Text("Users")
                    .font(.system(size: 13, weight: .heavy))
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 11)
            .frame(minHeight: 40)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Revenir à la liste des utilisateurs")
    }

    private var identityCard: some View {
        VStack(spacing: 0) {
            Text(AdmUserText.initial(for: user.displayName))
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Theme.surface)
                .frame(width: 62, height: 62)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 21))
            Text(user.displayName)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            Text(AdmUserText.path(for: user))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.top, 5)
            if let email = user.registrationEmail, !email.isEmpty {
                registrationEmailRow(email)
            }
            badges
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func registrationEmailRow(_ email: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "envelope")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            VStack(alignment: .leading, spacing: 2) {
                Text("Adresse d’inscription")
                    .font(.system(size: 9, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkFaint)
                Text(email)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .padding(.top, 12)
    }

    /// Badges d'annuaire : visibilité, puis école visée.
    private var badges: some View {
        HStack(spacing: 7) {
            DuelloPill(text: listingLabel, tone: .ink)
            if !user.targetSchool.isEmpty {
                DuelloPill(text: user.targetSchool, tone: .neutral)
            }
        }
        .padding(.top, 12)
    }

    /// `listed === false` prime : le compte n'apparaît pas dans l'annuaire.
    private var listingLabel: String {
        if user.listed == false { return "Hors annuaire" }
        return user.isPublic ? "Public" : "Privé"
    }

    private var overviewGrid: some View {
        VStack(spacing: 9) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)],
                spacing: 9
            ) {
                AdmMetricTile(label: "Temps total", value: AdmFormat.durationSeconds(metrics.totalSeconds))
                AdmMetricTile(label: "Sessions", value: "\(metrics.sessionCount)")
                AdmMetricTile(
                    label: "Moyenne / jour actif",
                    value: AdmFormat.durationSeconds(metrics.averageDaySeconds)
                )
                AdmMetricTile(label: "XP", value: "\(user.performance?.xp ?? 0)")
            }
            AdmMetricTile(
                label: "Dernière activité",
                value: AdmFormat.lastActivityDate(AdmUserText.lastActivity(for: user))
            )
        }
    }

    private var privacyCard: some View {
        AdmNoticeCard(
            icon: "checkmark.shield",
            text: "Ces indicateurs sont agrégés. Les réponses, brouillons et contenus scolaires de l’utilisateur ne sont pas transmis."
        )
    }
}
