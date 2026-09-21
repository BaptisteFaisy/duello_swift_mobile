//
//  AdmFormat.swift
//  Duello
//
//  Formatage partagé de l'espace d'administration (durées, dates, pluriel).
//
//  Fichiers source Expo portés :
//    - src/admin/AdminUsersScreen.tsx           (`formatDuration`, `formatDate`,
//      `formatDay`)
//    - src/admin/AdminAnalyticsScreen.tsx       (`duration`, `shortDate`)
//    - src/admin/AdminFeedbackScreen.tsx        (`formatDate`)
//    - src/admin/AdminExerciseReportsScreen.tsx (`formatDate`)
//    - src/admin/adminAnalytics.ts              (`dateKey`, `analyticsToday`)
//
//  Les écrans Expo s'appuient sur `Intl.DateTimeFormat('fr-FR')` : les mêmes
//  options sont reprises ici. Seule la ponctuation entre date et heure peut
//  différer légèrement (`à` au lieu de `,`), la langue et l'ordre restant ceux
//  de `fr-FR`.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Formatage commun aux écrans d'administration.
enum AdmFormat {
    /// `dateKey` de `adminAnalytics.ts` : clé de jour locale `yyyy-MM-dd`.
    static func dayKey(_ date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    /// Analyse une clé de jour `yyyy-MM-dd` (`formatDay`, `shortDate`).
    static func day(from value: String) -> Date? {
        dayKeyFormatter.date(from: value)
    }

    /// `formatDuration` de `AdminUsersScreen.tsx` : « 2 h 05 », « 12 min », « 45 s ».
    static func durationSeconds(_ totalSeconds: Double?) -> String {
        let seconds = max(0, Int((totalSeconds ?? 0).rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours) h \(String(format: "%02d", minutes))" }
        if minutes > 0 { return "\(minutes) min" }
        return "\(seconds) s"
    }

    /// `duration` de `AdminAnalyticsScreen.tsx` : arrondi à la minute, en heures
    /// au-delà de soixante minutes.
    static func durationMinutes(_ totalSeconds: Double) -> String {
        let minutes = Int((max(0, totalSeconds) / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(String(format: "%02d", minutes % 60))"
    }

    /// `formatDate` de `AdminUsersScreen.tsx` : dernière activité connue.
    static func lastActivityDate(_ value: String?) -> String {
        guard let value, !value.isEmpty, let date = ISO8601DateFormatter.date(fromISO: value) else {
            return "Aucune activité"
        }
        return mediumDateTime.string(from: date)
    }

    /// `formatDate` des écrans feedback et signalements : date d'un message.
    static func recordDate(_ value: String) -> String {
        guard let date = ISO8601DateFormatter.date(fromISO: value) else { return "Date inconnue" }
        return mediumDateTime.string(from: date)
    }

    /// `formatDay` de `AdminUsersScreen.tsx` : « lun. 12 sept. ».
    static func dayLabel(_ value: String) -> String {
        guard let date = day(from: value) else { return value }
        return dayLabelFormatter.string(from: date)
    }

    /// `shortDate` de `AdminAnalyticsScreen.tsx` : « 12 sept. ».
    static func shortDate(_ value: String) -> String {
        guard let date = day(from: value) else { return value }
        return shortDateFormatter.string(from: date)
    }

    /// Accord du pluriel des sous-titres admin (« compte » / « comptes »).
    static func plural(_ count: Int) -> String {
        count > 1 ? "s" : ""
    }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let mediumDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dayLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}
