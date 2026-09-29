import SwiftUI

// MARK: - En-tête, onglets de document et verrouillage du corrigé

extension AnnReaderView {
    // MARK: En-tête

    var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Button(action: onClose) {
                    IonIcon(name: "chevron-back", size: 22, color: Theme.ink)
                        .frame(width: 42, height: 42)
                        .background(Theme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
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
                headerActions
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

    /// Actions de l'en-tête (`headerActions` du lecteur Expo) : le classement
    /// du sujet puis le signalement de l'énoncé ou du corrigé.
    var headerActions: some View {
        AnnReaderHeaderActions(entry: entry, subject: subject, mode: mode)
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
    /// au-delà de la difficulté 5, seul un verdict validé ouvre le corrigé —
    /// sauf la difficulté 6 (« Extrême »), toujours ouverte dès qu'un verdict
    /// existe (`AnnaleViewer.tsx:3841-3845`).
    private var unlockedCorrectionCount: Int {
        entry.questions.filter { question in
            guard let verdict = verdicts[question.id] else { return false }
            return entry.difficulty < 5 || entry.difficulty >= 6 || verdict.isValidated
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

// MARK: - Actions de l'en-tête

/// Classement + signalement de l'en-tête du lecteur (`headerActions`,
/// `AnnaleViewer.tsx:3802-3824`).
///
/// Sous-vue dédiée : elle seule peut lire `SessionStore` (le champ `session` de
/// `AnnReaderView` est privé à son fichier), et le signalement a besoin du
/// profil local (`userId` + `displayName`).
///
/// Écart assumé : la pastille « nouveau résultat » du trophée
/// (`hasUnreadResult`/`rankingUnread`) n'est pas rendue — `ExGTrophy` ne porte
/// pas encore ce champ (à raccorder dans `ExGExerciseLeaderboard.swift`).
private struct AnnReaderHeaderActions: View {
    let entry: AnnEntry
    let subject: String
    let mode: AnnDocumentMode

    @EnvironmentObject private var session: SessionStore

    var body: some View {
        HStack(spacing: 8) {
            ExGTrophyButton(
                trophy: ExGTrophy(
                    itemId: entry.id,
                    subject: subject,
                    title: entry.title,
                    activity: .annale,
                    isAnnale: true
                )
            )
            ReportExerciseButton.make(
                profile: session.profile,
                target: mode == .statement ? .statement : .correction,
                source: .training,
                exerciseId: entry.id,
                exerciseTitle: entry.title,
                subject: subject,
                compact: true
            )
        }
    }
}
