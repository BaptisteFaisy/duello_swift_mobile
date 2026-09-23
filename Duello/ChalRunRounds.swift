//
//  ChalRunRounds.swift
//  Duello
//
//  Lot 11-C — déroulé d'un défi : les manches (série d'exercices), la question
//  courante et la saisie de la réponse.
//
//  Fichier source Expo porté (plage 1941-2368 de ChallengesScreen.tsx) :
//    - en-tête de manche : chrono (`DuelChrono`) puis « Exercice n/N » ;
//    - avis d'exercice déjà commencé (pénalité côté joueur, bonus côté
//      adversaire) ;
//    - onglets de questions (`questionTabs`) et invite de la question ouverte ;
//    - carte de copie (`productionCard`) et bouton « Terminer … » dont le
//      libellé dépend du temps écoulé et du rang dans la série ;
//    - note d'attente de la copie adverse et abandon (« Abandonner sans
//      gagner d'XP » / « Ne pas attendre — défi non arbitré »).
//
//  Réutilise sans les recréer : `ChalTimer` (chrono borné), `judgeDuel`,
//  `DuelExercise`, `DuelQuotaError`, `joinDuelAnswers`, `attemptedDuelAnswers`,
//  `duelQuestionLabel`, `LatexToUnicode`, `DuelloPrimaryButton`.
//
//  Limite assumée : les outils de saisie riches de la source (clavier maths,
//  dictée, photo de copie, console Python) vivent dans leurs propres lots et ne
//  sont pas repris ici ; la saisie reste un champ texte multiligne.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI
import Combine

/// État d'une manche en cours : la série d'exercices du défi, l'exercice ouvert,
/// les réponses et la question active (le `session` de la source).
struct ChalRunRoundState {
    /// Nombre d'exercices de la série (`session.series.length`).
    var seriesCount: Int
    /// Rang de l'exercice ouvert (`session.exerciseIndex`).
    var exerciseIndex: Int
    /// Énoncé de l'exercice ouvert (`session.exercise`).
    var exercise: DuelExercise
    /// Réponses rendues, indexées par question (`session.answers`).
    var answers: [String: String]
    /// Question ouverte dans les onglets (`session.activeQuestionId`).
    var activeQuestionId: String
    /// Instant de remise de la copie (`session.submittedAt`), absent avant.
    var submittedAt: Double?

    var questions: [DuelExercise.Question] { exercise.questions }

    /// Rang de la question active, ramené dans les bornes.
    var activeQuestionIndex: Int {
        max(0, questions.firstIndex(where: { $0.id == activeQuestionId }) ?? 0)
    }

    /// Question ouverte, absente seulement si l'exercice n'en a aucune.
    var activeQuestion: DuelExercise.Question? {
        questions.indices.contains(activeQuestionIndex) ? questions[activeQuestionIndex] : nil
    }

    /// Invite de la question ouverte, quand l'énoncé ne la porte pas déjà.
    var activeQuestionPrompt: String? {
        let prompt = activeQuestion?.prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (prompt?.isEmpty ?? true) ? nil : prompt
    }

    /// Progression affichée : « Exercice n/N ».
    var progressLabel: String { "Exercice \(exerciseIndex + 1)/\(seriesCount)" }

    /// La copie rendue, telle que le correcteur la lira (`joinDuelAnswers`).
    var submittedCopy: String { joinDuelAnswers(exercise, answers) }

    /// La copie porte au moins une réponse : sans elle, on n'envoie rien.
    var canSubmit: Bool {
        !submittedCopy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Libellé du bouton de remise, selon le temps écoulé et le rang de manche.
    func submitTitle(timeIsUp: Bool) -> String {
        if timeIsUp { return "Temps écoulé — faire noter" }
        return exerciseIndex < seriesCount - 1 ? "Terminer cet exercice" : "Terminer et faire noter"
    }
}

/// Déroulé d'une manche de défi : chrono, énoncé, question courante, saisie,
/// remise de la copie et attente de l'adversaire (`ChallengeExerciseWorkspace`).
struct ChalRunRounds: View {
    @EnvironmentObject private var session: SessionStore

    let match: MatchView
    /// Identifiant public du joueur (clé de dépôt de la copie côté serveur).
    let userId: String
    /// Titre de l'exercice servi, pour le signalement de l'énoncé.
    var exerciseTitle: String = ""
    /// Énoncé et réponses de la manche ; l'appelant les conserve pour enchaîner
    /// les exercices d'une même série.
    @Binding var state: ChalRunRoundState
    /// Avis d'exercice déjà commencé, affiché en tête de manche.
    var startedPenalty: Int = 0
    var opponentStartedBonus: Int = 0
    /// Appelé quand la copie est notée et l'attente adverse résolue.
    var onVerdict: (DuelVerdict) -> Void
    /// Appelé pour abandonner le défi sans gagner d'XP.
    var onAbandon: () -> Void
    /// Appelé pour ne pas attendre l'adversaire (défi non arbitré).
    var onStopWaiting: () -> Void

    @State private var now: Double = Date().timeIntervalSince1970 * 1000
    @State private var isSubmitting = false
    @State private var didAutoSubmit = false
    @State private var notice: String?
    @State private var waitingDeadline: Double?
    @State private var gradeTask: Task<Void, Never>?

    // `let` et non `var` : une propriété stockée `private var` dotée d'une valeur
    // initiale entre dans l'initialiseur membre-à-membre, ce qui rend celui-ci
    // `private` — donc inaccessible depuis `ChalIntDuelFlow`, qui construit la vue.
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var totalSeconds: Double { Double(match.durationMinutes * 60) }

    /// Instantané du chrono : part du `startedAt` du match, s'arrête à la remise.
    private var snapshot: ChalTimer.Snapshot {
        ChalTimer.snapshot(.init(
            startedAt: match.startedAt,
            totalSeconds: totalSeconds,
            stoppedAt: state.submittedAt,
            now: now
        ))
    }

    private var timeIsUp: Bool { snapshot.remainingSeconds == 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ChalUiDuelChrono(
                    startedAt: match.startedAt,
                    stoppedAt: state.submittedAt,
                    totalSeconds: totalSeconds,
                    onTimeUp: { tick() }
                )
                Text("Exercice \(state.exerciseIndex + 1)/\(state.seriesCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .center)
                if startedPenalty > 0 {
                    ChalRunNotice(
                        icon: "exclamationmark.circle",
                        text: "Tu avais déjà commencé cet exercice : ta note finale aura une pénalité de \(startedPenalty) points."
                    )
                }
                if opponentStartedBonus > 0 {
                    ChalRunNotice(
                        icon: "plus.circle",
                        text: "Ton adversaire avait déjà commencé cet exercice : ta note finale recevra un bonus de \(opponentStartedBonus) points."
                    )
                }
                statement
                response
                submitButton
                if let waitingDeadline { waitNote(waitingDeadline) }
                cancelButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .onReceive(timer) { _ in tick() }
        .onDisappear { gradeTask?.cancel() }
    }

    // MARK: Énoncé et réponse

    private var statement: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChalRunSectionLabel(text: "ÉNONCÉ")
            VStack(alignment: .trailing, spacing: 6) {
                ReportExerciseButton.make(
                    profile: session.profile,
                    target: .statement,
                    source: .challenge,
                    exerciseId: state.exercise.id,
                    exerciseTitle: exerciseTitle,
                    subject: match.subject,
                    compact: true
                )
                Text(LatexToUnicode.toUnicodeMath(state.exercise.context ?? ""))
                    .font(Theme.readingFont)
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }

    private var response: some View {
        VStack(alignment: .leading, spacing: 10) {
            ChalRunSectionLabel(text: "TA RÉPONSE")
            ChalRunQuestionTabs(
                questions: state.questions,
                activeId: state.activeQuestionId,
                answers: state.answers,
                disabled: isSubmitting
            ) { id in
                state.activeQuestionId = id
            }
            if let prompt = state.activeQuestionPrompt {
                Text("\(duelQuestionLabel(state.activeQuestion, state.activeQuestionIndex)). \(LatexToUnicode.toUnicodeMath(prompt))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(3)
            }
            answerEditor
            if let notice {
                Text(notice)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.like)
            }
        }
    }

    private var answerEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: answerBinding)
                .font(.system(size: 13))
                .frame(minHeight: 160)
                .scrollContentBackground(.hidden)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .disabled(isSubmitting)
            if (state.answers[state.activeQuestionId] ?? "").isEmpty {
                Text("Pose tes hypothèses et avance étape par étape, aussi loin que le temps le permet…")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Réponse du champ courant, rattachée à la question ouverte.
    private var answerBinding: Binding<String> {
        Binding(
            get: { state.answers[state.activeQuestionId] ?? "" },
            set: { state.answers[state.activeQuestionId] = $0 }
        )
    }

    // MARK: Remise et attente

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView().tint(Theme.surface)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(isSubmitting ? submitProgressTitle : state.submitTitle(timeIsUp: timeIsUp))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(DuelloPrimaryButton())
        .disabled(isSubmitting || (!state.canSubmit && !timeIsUp))
        .opacity(isSubmitting || (!state.canSubmit && !timeIsUp) ? 0.45 : 1)
    }

    private var submitProgressTitle: String {
        waitingDeadline == nil ? "L’IA note ta copie…" : "En attente de la copie adverse…"
    }

    private func waitNote(_ deadline: Double) -> some View {
        Text("Ta copie est notée. \(match.opponent.displayName) a jusqu’à \(ChalRunFormat.deadline(deadline)) pour rendre la sienne, après quoi le défi t’est acquis par forfait.")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Theme.inkFaint)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
    }

    private var cancelButton: some View {
        Button {
            waitingDeadline == nil ? onAbandon() : onStopWaiting()
        } label: {
            Text(waitingDeadline == nil ? "Abandonner sans gagner d’XP" : "Ne pas attendre — défi non arbitré")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting && waitingDeadline == nil)
    }

    // MARK: Chrono et remise

    private func tick() {
        now = Date().timeIntervalSince1970 * 1000
        guard state.submittedAt == nil, !isSubmitting else { return }
        if timeIsUp && !didAutoSubmit {
            // La fin du temps explique qu'une copie reste inachevée : elle part
            // quand même, le barème note l'avancement réel.
            didAutoSubmit = true
            submit()
        }
    }

    private func submit() {
        guard !isSubmitting, state.submittedAt == nil else { return }
        guard let token = session.token else {
            notice = "Ta session a expiré, reconnecte-toi."
            return
        }
        state.submittedAt = Date().timeIntervalSince1970 * 1000
        isSubmitting = true
        notice = nil
        let matchRef = match
        let exerciseRef = state.exercise
        let production = state.submittedCopy
        let attempted = attemptedDuelAnswers(state.exercise, state.answers)
        let userRef = userId
        gradeTask = Task {
            do {
                let verdict = try await judgeDuel(
                    match: matchRef,
                    subject: matchRef.subject,
                    exercise: exerciseRef,
                    myProduction: production,
                    answers: attempted,
                    userId: userRef,
                    token: token,
                    onWaitingForOpponent: { deadline in
                        Task { @MainActor in waitingDeadline = deadline }
                    }
                )
                await MainActor.run { onVerdict(verdict) }
            } catch let quota as DuelQuotaError {
                // Le quota est un refus produit : la copie reste rédigée, le
                // joueur peut réessayer au prochain créneau.
                let message = quota.message
                await MainActor.run {
                    notice = message
                    state.submittedAt = nil
                    isSubmitting = false
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run {
                    notice = message
                    state.submittedAt = nil
                    isSubmitting = false
                }
            }
        }
    }
}

/// Chrono du défi (`DuelChrono`) : décompte « m:ss », rouge dans la dernière
/// minute, rendu depuis un instantané déjà borné par `ChalTimer`.
struct ChalRunChrono: View {
    let remainingSeconds: Int

    var body: some View {
        Text(ChalTimer.clock(remainingSeconds))
            .font(.system(size: 20, weight: .black).monospacedDigit())
            .foregroundStyle(remainingSeconds <= 60 ? Theme.like : Theme.ink)
    }
}

/// Onglets des questions d'un exercice (`questionTabs`) : disent laquelle est
/// ouverte et lesquelles portent déjà une réponse. Un exo d'une seule question
/// n'a pas d'onglets : son champ est la copie.
struct ChalRunQuestionTabs: View {
    let questions: [DuelExercise.Question]
    let activeId: String
    let answers: [String: String]
    var disabled: Bool = false
    var onSelect: (String) -> Void

    var body: some View {
        if questions.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                        tab(index: index, question: question)
                    }
                }
            }
        }
    }

    private func tab(index: Int, question: DuelExercise.Question) -> some View {
        let active = question.id == activeId
        let written = !(answers[question.id] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        return Button {
            onSelect(question.id)
        } label: {
            HStack(spacing: 5) {
                Text(duelQuestionLabel(question, index))
                if written {
                    Circle()
                        .fill(active ? Theme.surface : Theme.ink)
                        .frame(width: 5, height: 5)
                }
            }
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(active ? Theme.surface : Theme.inkSoft)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(active ? Theme.ink : Theme.surfaceMuted)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(active ? Color.clear : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .accessibilityLabel("Question \(duelQuestionLabel(question, index))")
    }
}

/// Avis en ligne d'un défi (`successNotice`) : pénalité, bonus ou alerte.
struct ChalRunNotice: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }
}
