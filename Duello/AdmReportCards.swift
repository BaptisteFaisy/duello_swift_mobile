//
//  AdmReportCards.swift
//  Duello
//
//  Cartes de signalement affichées par l'écran des signalements.
//
//  Fichier source Expo porté : src/admin/AdminExerciseReportsScreen.tsx
//  (`reportCard` des signalements de comptes et de contenus, `TARGET_LABEL`,
//  `SOURCE_LABEL`, `USER_REASON_LABEL`). Les libellés et les mesures sont repris
//  mot pour mot.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// Carte d'un compte signalé : motif, auteur, précisions confidentielles.
struct AdmUserReportCard: View {
    let report: AdmUserReportRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AdmReportHeader(
                icon: "flag-outline",
                title: report.reportedDisplayName,
                date: AdmFormat.recordDate(report.createdAt),
                badge: "COMPTE"
            )
            Text(report.reason.label)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 15)
            Text("Signalé par \(report.reporterDisplayName)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 5)
            Text("Cible : \(report.reportedId) · Auteur : \(report.reporterId)")
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
            AdmReportMessage(
                label: "PRÉCISIONS CONFIDENTIELLES",
                message: report.details
            )
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .admCardShadow()
    }
}

/// Carte d'un contenu signalé : exercice, origine, précision de l'élève.
struct AdmContentReportCard: View {
    let report: AdmExerciseReportRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AdmReportHeader(
                icon: "bug-outline",
                title: report.displayName,
                date: AdmFormat.recordDate(report.createdAt),
                badge: report.target.label
            )
            Text(report.exerciseTitle)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 15)
            Text("\(report.subject) · \(report.source.label)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
            Text("ID : \(report.exerciseId)")
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
            AdmReportMessage(
                label: "PRÉCISION DE L’ÉLÈVE",
                message: report.message
            )
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .admCardShadow()
    }
}

/// En-tête commun : icône, nom, date et étiquette de cible.
struct AdmReportHeader: View {
    let icon: String
    let title: String
    let date: String
    let badge: String

    var body: some View {
        HStack(spacing: 10) {
            IonIcon(name: icon, size: 20, color: Theme.like)
                .frame(width: 38, height: 38)
                .background(Theme.likeLight)
                .clipShape(RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(date)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 8)
            // `targetBadge` : fond `likeLight`, texte `like`, 9/900, rayon pilule,
            // sans mise en majuscules.
            AdmPill(
                text: badge,
                foreground: Theme.like,
                background: Theme.likeLight,
                fontSize: 9,
                weight: .black,
                verticalPadding: 6,
                horizontalPadding: 9
            )
        }
    }
}

/// Bloc « PRÉCISIONS… » : message de l'auteur du signalement.
struct AdmReportMessage: View {
    let label: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 8, weight: .black))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkFaint)
            Text(message.isEmpty ? "Aucune précision ajoutée." : message)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.inkSoft)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }
}
