//
//  ReportPublicProfilePublisher+Helpers.swift
//  Duello
//
//  Port de src/components/PublicProfilePublisher.tsx (RN) — utilitaires du
//  coordinateur : délai jusqu'à la prochaine minuit locale (`scheduleNextDay`)
//  et message d'un envoi raté (`.catch` de la source).
//
//  Découpage (24/09/2026) : section extraite de
//  `ReportPublicProfilePublisher.swift` (porté du même fichier source).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

extension ReportPublicProfilePublisher {

    /// Délai jusqu'à la prochaine minuit locale, avec la seconde de marge de
    /// `setHours(24, 0, 1, 0)` et le plancher de `Math.max(1_000, …)`.
    static func nanosecondsUntilNextLocalMidnight(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> UInt64 {
        let startOfDay = calendar.startOfDay(for: now)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)
            ?? now.addingTimeInterval(86_400)
        let interval = max(1.0, nextDay.addingTimeInterval(1).timeIntervalSince(now))
        return UInt64(interval * 1_000_000_000)
    }

    /// Message d'un envoi raté, comme le `.catch` de la source.
    static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription
            ?? "Publication des performances impossible"
    }
}
