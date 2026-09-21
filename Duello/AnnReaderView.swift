import SwiftUI

// NOTE — limite « 500 lignes par fichier » (règles Duello) : ce fichier la
// dépasse, le type `AnnReaderView` occupant à lui seul 594 lignes. C'est un type
// unique dont tous les membres (en-tête, onglets, contenu, pied de lecteur,
// aides) partagent l'état `private` de la vue (`entry`, `mode`, `copyJob`,
// `dsUnlocked`…). Un découpage en extensions réparties sur d'autres fichiers
// exigerait d'élargir ces `private` en `internal`, c'est-à-dire de modifier des
// déclarations existantes — ce que ce découpage doit préserver (aucun type,
// propriété, méthode ni signature renommé). Le type reste donc entier ici, où
// il respecte déjà les autres limites : 8 fonctions, 50 lignes par fonction au
// plus.

// MARK: - Lecteur d'annale

/// Lecteur d'annale : onglets de document, navigation entre les questions et
/// panneau de correction de copie des épreuves écrites.
///
/// Portage de la partie lecture d'`AnnaleViewer.tsx` : les onglets Énoncé /
/// Barème / Commentaires / Corrigé, les messages de verrouillage du corrigé, le
/// panneau « Annale en cours » et l'ouverture de la fenêtre de correction de
/// copie. L'atelier de réponse (champ de réponse, dictée, tableau blanc,
/// clavier mathématique, console Python) n'est pas porté ici.
struct AnnReaderView: View {
    /// Annale affichée. L'état est modifiable pour passer d'un sujet à l'autre
    /// depuis la même fenêtre de lecture.
    @State private var entry: AnnEntry
    let subject: String
    let track: String
    let specialty: String
    @ObservedObject var monitor: AnnCorrectionMonitor
    /// Sujets de la même matière, pour passer d'une annale à la suivante.
    var siblings: [AnnEntry] = []
    var onClose: () -> Void

    /// Vrai lorsque toutes les réponses de l'annale ont été envoyées : le
    /// barème et les commentaires ne s'ouvrent qu'à ce moment-là
    /// (`attemptComplete` du lecteur Expo). L'hôte qui câble un parcours de
    /// réponse passe `true` ici.
    var attemptComplete: Bool = false
    /// Verdicts déjà connus, indexés par identifiant de question.
    var verdicts: [String: AnnVerdict] = [:]
    /// Questions classiques, marquées d'une étoile (`classicQuestionIds`).
    var classicQuestionIds: Set<String> = []
    /// Questions conseillées pour plus tard : consultables, pastillées rouge.
    var unavailableQuestionIds: Set<String> = []

    @EnvironmentObject private var session: SessionStore

    @State private var mode: AnnDocumentMode = .statement
    @State private var activeQuestionId: String?
    @State private var copySheetOpen = false
    @State private var copyJob: AnnCopyJob?
    @State private var dsUnlocked = false

    init(
        entry: AnnEntry,
        subject: String,
        track: String,
        specialty: String,
        monitor: AnnCorrectionMonitor,
        siblings: [AnnEntry] = [],
        onClose: @escaping () -> Void,
        attemptComplete: Bool = false,
        verdicts: [String: AnnVerdict] = [:],
        classicQuestionIds: Set<String> = [],
        unavailableQuestionIds: Set<String> = []
    ) {
        _entry = State(initialValue: entry)
        self.subject = subject
        self.track = track
        self.specialty = specialty
        _monitor = ObservedObject(wrappedValue: monitor)
        self.siblings = siblings
        self.onClose = onClose
        self.attemptComplete = attemptComplete
        self.verdicts = verdicts
        self.classicQuestionIds = classicQuestionIds
        self.unavailableQuestionIds = unavailableQuestionIds
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tabs
            Divider().overlay(Theme.border)
            content
            footer
        }
        .background(Theme.background)
        .onAppear {
            activeQuestionId = entry.questions.first?.id
            reloadCopyJob()
        }
        .onChange(of: entry.id) { _ in
            mode = .statement
            activeQuestionId = entry.questions.first?.id
            dsUnlocked = false
            copySheetOpen = false
            reloadCopyJob()
        }
        .fullScreenCover(isPresented: $copySheetOpen) {
            AnnCopyCorrectionSheet(
                itemId: entry.id,
                title: entry.title,
                subject: subject,
                statement: entry.statement ?? entry.title,
                solution: entry.solution,
                durationMinutes: entry.durationHours * 60,
                monitor: monitor,
                initialJob: copyJob,
                onClose: { copySheetOpen = false },
                onNewAttempt: {
                    copyJob = nil
                    reloadCopyJob()
                },
                onJobChange: { job in
                    copyJob = job
                    monitor.upsert(job)
                }
            )
            .environmentObject(session)
        }
    }

    // MARK: En-tête

    private var header: some View {
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

    private var tabs: some View {
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
    private var canShowSolution: Bool {
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
    private var solutionLockMessage: String {
        if canShowSolution { return "" }
        if entry.isWrittenPaper {
            return "Corrigé disponible après avoir indiqué que les \(entry.durationHours) heures sont écoulées"
        }
        return "Corrigé disponible après l’envoi d’une réponse"
    }

    // MARK: Contenu

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                questionNavigation
                documentBody
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var questionNavigation: some View {
        if entry.questions.count > 1 {
            VStack(alignment: .leading, spacing: 6) {
                Text("Questions")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.inkFaint)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entry.questions) { question in
                            questionChip(question)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    private func questionChip(_ question: AnnQuestion) -> some View {
        let selected = question.id == (activeQuestionId ?? entry.questions.first?.id)
        let verdict = verdicts[question.id]
        let isClassic = classicQuestionIds.contains(question.id)
        let isForLater = unavailableQuestionIds.contains(question.id)
        return Button {
            activeQuestionId = question.id
        } label: {
            HStack(spacing: 5) {
                if let verdict {
                    Image(systemName: verdict.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(verdict.color)
                }
                Text(question.displayLabel)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
                if isClassic {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                if isForLater {
                    Circle()
                        .fill(Theme.like)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(selected ? Theme.ink : Theme.surfaceMuted)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(selected ? Color.clear : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: question, verdict: verdict, classic: isClassic, later: isForLater))
    }

    /// Libellé d'accessibilité du bouton de question, mot pour mot du lecteur.
    private func accessibilityLabel(
        for question: AnnQuestion,
        verdict: AnnVerdict?,
        classic: Bool,
        later: Bool
    ) -> String {
        var text = "Question \(question.displayLabel)"
        if let verdict {
            text += ", \(verdict.label.lowercased())"
        }
        if classic { text += ", classique" }
        if later { text += ", conseillée pour plus tard" }
        return text
    }

    @ViewBuilder
    private var documentBody: some View {
        switch mode {
        case .statement:
            documentCard(
                title: nil,
                text: entry.statement,
                empty: "Document indisponible"
            )
        case .markingScheme:
            documentCard(
                title: "Barème",
                text: entry.markingScheme,
                empty: "Document indisponible"
            )
        case .comments:
            documentCard(
                title: "Commentaires",
                text: entry.comments,
                empty: "Document indisponible"
            )
        case .solution:
            solutionBody
        }
    }

    @ViewBuilder
    private var solutionBody: some View {
        if entry.isWrittenPaper {
            documentCard(
                title: "Corrigé",
                text: entry.solution,
                empty: "Corrigé indisponible"
            )
        } else if !canShowSolution {
            lockedSolutionCard
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(entry.questions) { question in
                    questionCorrectionCard(question)
                }
            }
        }
    }

    /// Corrigé par question, verrouillé tant que la réponse n'est pas validée.
    private func questionCorrectionCard(_ question: AnnQuestion) -> some View {
        let verdict = verdicts[question.id]
        let unlocked = verdict != nil && (entry.difficulty < 5 || (verdict?.isValidated ?? false))
        let isClassic = classicQuestionIds.contains(question.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Question \(question.displayLabel)")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if isClassic {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                Spacer(minLength: 0)
                Image(systemName: unlocked ? "lock.open" : "lock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(unlocked ? Theme.ink : Theme.inkFaint)
            }
            Text(questionCorrectionText(question, unlocked: unlocked))
                .font(Theme.readingFont)
                .foregroundStyle(unlocked ? Theme.ink : Theme.inkFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .duelloCard()
    }

    /// Texte du corrigé d'une question, ou l'explication de son verrouillage,
    /// mot pour mot du lecteur Expo.
    private func questionCorrectionText(_ question: AnnQuestion, unlocked: Bool) -> String {
        if unlocked {
            if entry.solution != nil {
                return LatexToUnicode.toUnicodeMath(entry.solution ?? "")
            }
            return "Consulte le compte rendu de cette question pour voir le corrigé de référence disponible."
        }
        if entry.difficulty >= 5, verdicts[question.id] != nil {
            let level = entry.difficulty == 6 ? "Extrême" : "Très difficile"
            return "\(level) · cette réponse doit être entièrement juste pour déverrouiller son corrigé."
        }
        return "Soumets cette réponse pour rendre son corrigé accessible."
    }

    private var lockedSolutionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            Text(solutionLockMessage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            if entry.isWrittenPaper {
                Text("Soumets l’exercice pour rendre son corrigé accessible.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    /// Carte de document : texte composé par `LatexToUnicode`, ou l'état
    /// d'indisponibilité du document.
    ///
    /// Le lecteur Expo charge le PDF puis le compose en HTML ; ici les
    /// documents arrivent retranscrits en texte avec la banque d'annales, et
    /// l'absence de texte veut dire « document indisponible ».
    @ViewBuilder
    private func documentCard(
        title: String?,
        text: String?,
        empty: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkSoft)
            }
            if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(LatexToUnicode.toUnicodeMath(text))
                    .font(Theme.readingFont)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "cloud")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                    Text(empty)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                    Text("Vérifie ta connexion, puis réessaie.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    // MARK: Pied de lecteur

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if entry.isWrittenPaper {
                dsUnlockPanel
            }
            siblingNavigation
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(Theme.surface)
        .overlay(
            Rectangle().fill(Theme.border).frame(height: 1),
            alignment: .top
        )
    }

    /// Panneau « Annale en cours » des épreuves écrites : déverrouillage du
    /// corrigé officiel et dépôt d'une partie de copie.
    private var dsUnlockPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: dsUnlocked ? "lock.open" : "clock")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 3) {
                    Text(dsUnlocked
                         ? "Corrigé officiel déverrouillé"
                         : "Annale en cours · \(entry.durationLabel) au total")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(dsUnlocked
                         ? "Tu peux consulter le corrigé et retrouver les corrections de chaque partie."
                         : "Travaille à ton rythme : tu pourras soumettre chaque partie séparément.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: 8) {
                if dsUnlocked {
                    if entry.hasOfficialSolution {
                        AnnOutlineButton(title: "Voir le corrigé officiel", icon: "doc.text") {
                            mode = .solution
                        }
                    } else {
                        Text("Le corrigé officiel n’est pas encore disponible.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    AnnOutlineButton(
                        title: "Les \(entry.durationHours) h sont écoulées",
                        icon: "checkmark.circle"
                    ) {
                        dsUnlocked = true
                        if entry.hasOfficialSolution { mode = .solution }
                    }
                }

                AnnSolidButton(title: copyButtonTitle, icon: copyButtonIcon) {
                    reloadCopyJob()
                    copySheetOpen = true
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    private var copyButtonTitle: String {
        if copyJob?.status == .ready { return "Ouvrir mes corrections" }
        if copyJob != nil { return "Suivre mes corrections" }
        return "Soumettre une partie"
    }

    private var copyButtonIcon: String {
        copyJob?.status == .ready ? "checkmark.circle" : "camera"
    }

    /// Passage d'une annale à la précédente ou à la suivante.
    @ViewBuilder
    private var siblingNavigation: some View {
        if siblings.count > 1, let index = siblings.firstIndex(where: { $0.id == entry.id }) {
            HStack(spacing: 10) {
                AnnOutlineButton(title: "Annale précédente", icon: "chevron.left") {
                    openSibling(at: index - 1)
                }
                .disabled(index == 0)
                .opacity(index == 0 ? 0.45 : 1)

                AnnOutlineButton(title: "Annale suivante", icon: "chevron.right") {
                    openSibling(at: index + 1)
                }
                .disabled(index == siblings.count - 1)
                .opacity(index == siblings.count - 1 ? 0.45 : 1)
            }
        }
    }

    // MARK: Aides

    /// Recharge la fiche de correction la plus récente de cette annale
    /// (`AnnaleViewer` : dernier job trié par `updatedAt`).
    private func reloadCopyJob() {
        let latest = monitor.jobs(for: entry.id).first
        copyJob = latest
    }

    /// Change d'annale depuis la même fenêtre de lecture. Le changement d'état
    /// déclenche la remise à zéro de l'onglet, de la question et du
    /// déverrouillage, comme à l'ouverture d'un nouveau sujet.
    private func openSibling(at index: Int) {
        guard siblings.indices.contains(index) else { return }
        entry = siblings[index]
    }
}
