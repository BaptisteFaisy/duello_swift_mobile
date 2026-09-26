//
//  PlanGrid.swift
//  Duello
//
//  Écran « Plan » — grille horaire 00:00 → 00:00 : mesures figées, graduations, blocs de séance et page-jour.
//
import Foundation
import SwiftUI

// MARK: - Mesures figées

/// Constantes de la grille et de l'écran, reprises de la source (lignes 360-366,
/// 386-432 et 95). Elles ne sont pas paramétrables : la journée entière doit
/// tenir dans la page, sans défilement interne.
enum PlanMetrics {
    /// `DAY_MINUTES` (ligne 360).
    static let dayMinutes = 24 * 60
    /// `HOURS` (ligne 362) : 25 graduations, la dernière fermant la journée.
    static let hours: [Int] = Array(0...24)
    /// `DAY_HEADER_HEIGHT` (ligne 364).
    static let dayHeaderHeight: CGFloat = 30
    /// `TIMELINE_BOTTOM_PADDING` (ligne 366).
    static let timelineBottomPadding: CGFloat = 10
    /// Plancher de hauteur de grille (ligne 386).
    static let minimumTimelineHeight: CGFloat = 240
    /// Hauteur du carrousel de jours. L'écran Expo mesurait la hauteur restante
    /// (`onLayout`) ; dans un `ScrollView` SwiftUI, une valeur fixe garde la
    /// grille lisible et le défilement vertical prévisible.
    static let dayAreaHeight: CGFloat = 560
    /// Effacement automatique du bandeau d'ajout (ligne 95).
    static let bannerDismissDelay: TimeInterval = 3.5
    /// Seuils de contenu des blocs (lignes 431-432).
    static let compactBlockThreshold: CGFloat = 42
    static let tinyBlockThreshold: CGFloat = 24
    /// Hauteur minimale d'un bloc (ligne 428).
    static let minimumBlockHeight: CGFloat = 14
    /// Décalage entre deux blocs d'un même jour (lignes 555 et 579).
    static let blockGapMinutes = 15
}

// MARK: - Grille horaire

/// Graduation d'heure : étiquette à gauche, trait à partir de 38 pt, renforcé
/// toutes les 6 heures (lignes 405-410).
struct PlanHourTick: View {
    let hour: Int
    let strong: Bool

    var body: some View {
        HStack(spacing: 2) {
            Text(String(format: "%02d:00", hour % 24))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
                .frame(width: 36, alignment: .leading)
            Rectangle()
                .fill(strong ? Theme.inkFaint : Theme.border)
                .frame(height: strong ? 1 : 0.5)
        }
        .frame(height: 1)
    }
}

/// Bloc d'une séance : accent d'encre à gauche, contenu qui se réduit quand le
/// bloc devient court (`compact < 42`, `tiny < 24`, lignes 426-461).
struct PlanTimelineBlock: View {
    let session: PlanSession
    let pxPerMinute: CGFloat
    let onSelect: (PlanSession) -> Void

    var body: some View {
        let top = CGFloat(PlanDateEngine.timeToMinutes(session.startTime)) * pxPerMinute
        let blockHeight = max(CGFloat(session.durationMinutes) * pxPerMinute - 2, PlanMetrics.minimumBlockHeight)
        let compact = blockHeight < PlanMetrics.compactBlockThreshold
        let tiny = blockHeight < PlanMetrics.tinyBlockThreshold

        Button {
            onSelect(session)
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.ink)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(compact ? "\(session.startTime) · \(session.title)" : session.title)
                        .font(.system(size: tiny ? 9 : 12, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if !compact {
                        Text(session.subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                        Text("\(session.startTime)–\(session.endTime) · \(PlanDateEngine.formatDuration(session.durationMinutes))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.inkFaint)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, tiny ? 0 : 4)
                .padding(.horizontal, tiny ? 6 : 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                if session.isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Theme.ink)
                        .padding(.trailing, 6)
                }
            }
            .frame(height: blockHeight)
            .background(session.color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .clipped()
            .opacity(session.isDone ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .padding(.leading, 42)
        .offset(y: top)
        .accessibilityLabel("\(session.startTime) \(session.title) — \(session.subtitle), \(PlanDateEngine.formatDuration(session.durationMinutes))")
    }
}

/// Une page-jour : bandeau de date + grille 00:00 → 00:00 (lignes 378-465).
struct PlanDayPage: View {
    let day: PlanDay
    let sessions: [PlanSession]
    let areaHeight: CGFloat
    let onSelect: (PlanSession) -> Void

    private var isToday: Bool { day.dayOffset == 0 }

    var body: some View {
        let timelineHeight = max(
            areaHeight - PlanMetrics.dayHeaderHeight - PlanMetrics.timelineBottomPadding,
            PlanMetrics.minimumTimelineHeight
        )
        let pxPerMinute = timelineHeight / CGFloat(PlanMetrics.dayMinutes)
        let plannedMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }
        let nowMinutes = isToday ? PlanDayPage.minutesNow() : nil

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(isToday ? "Aujourd'hui" : "\(PlanTaskAnalyzer.capitalize(day.dayLabel)) \(day.fullLabel)")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(sessions.isEmpty
                     ? "Rien de prévu"
                     : "\(sessions.count) \(sessions.count > 1 ? "blocs" : "bloc") · \(PlanDateEngine.formatDuration(plannedMinutes))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }
            .frame(height: PlanMetrics.dayHeaderHeight)

            ZStack(alignment: .topLeading) {
                ForEach(PlanMetrics.hours, id: \.self) { hour in
                    PlanHourTick(hour: hour, strong: hour % 6 == 0)
                        .offset(y: CGFloat(hour) * 60 * pxPerMinute)
                }

                // Ligne « maintenant », aujourd'hui seulement (ligne 412).
                if let nowMinutes {
                    HStack(spacing: 0) {
                        Circle()
                            .fill(Theme.ink)
                            .frame(width: 7, height: 7)
                            .offset(x: -3)
                        Rectangle()
                            .fill(Theme.ink)
                            .frame(height: 1.5)
                    }
                    .padding(.leading, 36)
                    .offset(y: CGFloat(nowMinutes) * pxPerMinute)
                }

                if sessions.isEmpty {
                    HStack(spacing: 7) {
                        Image(systemName: "leaf")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                        Text("Journée libre")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.leading, 42)
                }

                ForEach(sessions) { session in
                    PlanTimelineBlock(session: session, pxPerMinute: pxPerMinute, onSelect: onSelect)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: timelineHeight, alignment: .topLeading)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// `now.getHours() * 60 + now.getMinutes()` (ligne 389).
    private static func minutesNow() -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
