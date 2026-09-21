//
//  AdmReportCards.swift
//  Duello
//
//  Cartes de signalement affichées par l'écran des signalements.
//
//  Fichier source Expo porté : src/admin/AdminExerciseReportsScreen.tsx
//  (`reportCard` des signalements de comptes et de contenus, `TARGET_LABEL`,
//  `SOURCE_LABEL`, `USER_REASON_LABEL`). Les libellés sont repris mot pour mot.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// Carte d'un compte signalé : motif, auteur, précisions confidentielles.
struct AdmUserReportCard: View {
    let report: AdmUserReportRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdmReportHeader(
                icon: "flag",
                tint: Theme.like,
                title: report.reportedDisplayName,
                date: AdmFormat.recordDate(report.createdAt),
                badge: "COMPTE"
            )
            Text(report.reason.label)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Signalé par \(report.reporterDisplayName)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            Text("Cible : \(report.reportedId) · Auteur : \(report.reporterId)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            AdmReportMessage(
                label: "PRÉCISIONS CONFIDENTIELLES",
                message: report.details
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

/// Carte d'un contenu signalé : exercice, origine, précision de l'élève.
struct AdmContentReportCard: View {
    let report: AdmExerciseReportRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdmReportHeader(
                icon: "ladybug",
                tint: Theme.like,
                title: report.displayName,
                date: AdmFormat.recordDate(report.createdAt),
                badge: report.target.label
            )
            Text(report.exerciseTitle)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(report.subject) · \(report.source.label)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Text("ID : \(report.exerciseId)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            AdmReportMessage(
                label: "PRÉCISION DE L’ÉLÈVE",
                message: report.message
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

/// En-tête commun : icône, nom, date et étiquette de cible.
struct AdmReportHeader: View {
    let icon: String
    let tint: Color
    let title: String
    let date: String
    let badge: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(Theme.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(date)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 8)
            DuelloPill(text: badge, tone: .ink)
        }
    }
}

/// Bloc « PRÉCISIONS… » : message de l'auteur du signalement.
struct AdmReportMessage: View {
    let label: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkFaint)
            Text(message.isEmpty ? "Aucune précision ajoutée." : message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }
}
