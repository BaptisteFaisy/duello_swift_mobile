import SwiftUI

// MARK: - Fiche d'annale

/// Fiche d'une annale dans la liste : titre, difficulté, badges, thème et
/// avancement de la correction de copie.
struct AnnEntryCard: View {
    let entry: AnnEntry
    var job: AnnCopyJob? = nil
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(entry.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    DuelloPill(
                        text: AnnDifficulty.label(for: entry.difficulty),
                        tone: AnnDifficulty.tone(for: entry.difficulty)
                    )
                }

                if let source = entry.source {
                    Text(source)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(2)
                }

                badgesRow

                HStack(spacing: 8) {
                    if !entry.questions.isEmpty {
                        Text("\(entry.questions.count) question\(entry.questions.count > 1 ? "s" : "")")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    if entry.isWrittenPaper {
                        Text("Épreuve écrite · \(entry.durationLabel)")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                }

                if let job {
                    HStack(spacing: 8) {
                        DuelloPill(
                            text: job.statusLabel,
                            tone: job.status == .ready ? .success : job.status == .failed ? .danger : .ink
                        )
                        if job.status == .ready, let result = job.result {
                            Text("\(result.scoreLabel)/20")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(Theme.progress)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .duelloCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.title)
    }

    private var badgesRow: some View {
        HStack(spacing: 6) {
            ForEach(entry.displayedBadges, id: \.self) { badge in
                DuelloPill(text: badge, tone: .neutral, icon: "school")
            }
            if let theme = entry.theme {
                DuelloPill(text: theme.label, tone: .neutral, icon: "tag")
            }
            if let status = entry.programStatus, !status.label.isEmpty {
                DuelloPill(text: status.label, tone: .warning, icon: status.icon)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Ligne de correction

/// Ligne du suivi des corrections : partie déposée, statut et avancement.
struct AnnCorrectionRow: View {
    let job: AnnCopyJob
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(job.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        Text(job.partLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    Spacer(minLength: 8)
                    if job.status == .ready, let result = job.result {
                        Text("\(result.scoreLabel)/20")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Theme.progress)
                    }
                }

                Text(job.statusLabel)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(job.status == .failed ? Theme.like : Theme.inkSoft)

                if job.isActive {
                    DuelloProgressTrack(fraction: job.progressFraction)
                }
            }
            .duelloCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(job.title), \(job.partLabel), \(job.statusLabel)")
    }
}
