import SwiftUI

// MARK: - En-tête, onglets de document et verrouillage du corrigé

extension AnnReaderView {
    // MARK: En-tête

    var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 34, height: 34)
                        .background(Theme.surfaceMuted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fermer le sujet")

                VStack(alignment: .leading, spacing: 2) {
                    Text(subject)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Theme.inkFaint)
                    Text(entry.title)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.ink)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                ForEach(entry.displayedBadges, id: \.self) { badge in
                    DuelloPill(text: badge, tone: .neutral, icon: "school")
                }
                if let theme = entry.theme {
                    DuelloPill(text: theme.label, tone: .neutral, icon: "tag")
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    // MARK: Onglets de document

    var tabs: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(visibleModes) { candidate in
                        DuelloChip(
                            title: candidate.label,
                            selected: mode == candidate
                        ) {
                            if isEnabled(candidate) { mode = candidate }
                        }
                        .opacity(isEnabled(candidate) ? 1 : 0.45)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 1)
            }
            if !canShowSolution {
                Text(solutionLockMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 8)
    }

    /// Onglets affichés : un document absent n'apparaît pas.
    private var visibleModes: [AnnDocumentMode] {
        AnnDocumentMode.allCases.filter { candidate in
            switch candidate {
            case .statement: return true
            case .markingScheme: return entry.markingScheme != nil
            case .comments: return entry.comments != nil
            case .solution: return entry.hasOfficialSolution
            }
        }
    }

    private func isEnabled(_ candidate: AnnDocumentMode) -> Bool {
        switch candidate {
        case .statement:
            return true
        case .markingScheme, .comments:
            // Le barème et les commentaires ne s'ouvrent qu'une fois les
            // réponses envoyées.
            return attemptComplete
        case .solution:
            return canShowSolution
        }
    }

    /// Le corrigé d'une épreuve écrite s'ouvre après les heures d'épreuve
    /// écoulées ; celui d'un sujet interactif, après une réponse validée.
    var canShowSolution: Bool {
        if entry.isWrittenPaper {
            return entry.hasOfficialSolution && dsUnlocked
        }
        return unlockedCorrectionCount > 0
    }

    /// Questions dont le corrigé est déverrouillé (`unlockedCorrectionCount`) :
    /// au-delà de la difficulté 5, seul un verdict validé ouvre le corrigé.
    private var unlockedCorrectionCount: Int {
        entry.questions.filter { question in
            guard let verdict = verdicts[question.id] else { return false }
            return entry.difficulty < 5 || verdict.isValidated
        }.count
    }

    /// Message de verrouillage du corrigé, mot pour mot du lecteur Expo.
    var solutionLockMessage: String {
        if canShowSolution { return "" }
        if entry.isWrittenPaper {
            return "Corrigé disponible après avoir indiqué que les \(entry.durationHours) heures sont écoulées"
        }
        return "Corrigé disponible après l’envoi d’une réponse"
    }
}
