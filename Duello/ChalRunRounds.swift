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
//  V2 (29/09/2026, parité RN dev) : la fenêtre Premium reçoit le quota durable
//  du compte (`useCorrectionQuota`, `ChallengesScreen.tsx:443`) chargé par
//  `PremQuotaService` — la ligne « défis gratuits » n'était jamais alimentée.
//
//  FIX-02 (29/09/2026) : `ChalRunRounds` accepte deux paramètres de plus
//  (`completedSeries`, `onSubmitRequested`) attendus par l'appel de
//  `ChalIntDuelFlow`. Ils sont **stockés mais inertes** dans cette vue : la
//  remise de série et l'alerte « Enchaîner » restent arbitrées par
//  `ChalIntDuelFlow` (`requestDuelSubmission`), qui les lui transmet pour un
//  raccord ultérieur. Aucun comportement d'affichage n'est modifié.
//
//  Outils de saisie (vague 6, écart 07#5) : la ligne `inputTools` et la console
//  Python sont désormais montées sous le champ par `ChalRunAnswerTools`
//  (`ChalRunTools.swift`) — dicter, photo, clavier maths/Python, bloc Python.
//  La saisie reste un champ texte multiligne ; les outils s'y ajoutent.
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
    /// Exercices déjà validés de la série, dans l'ordre (voir
    /// `ChalSeries.buildExercise`, qui réunit la copie notée). Transmis par
    /// `ChalIntDuelFlow` pour la remise ; **stocké et inerte** dans cette vue
    /// (aucun affichage ne le consomme encore) — voir en-tête de fichier.
    var completedSeries: [ChalCompletedExercise] = []
    /// Demande de remise d'une fin d'exercice non terminale
    /// (`ChallengesScreen.tsx:1319-1344`) : la vue fournit l'action `proceed`
    /// (« Enchaîner ») et l'appelant décide de la lancer tout de suite ou de la
    /// différer (voir `ChalIntDuelFlow.requestDuelSubmission(proceed:)`, qui
    /// reçoit cette action `@escaping`). **Stocké et inerte** ici : le flux qui
    /// l'arbitre reste porté par `ChalIntDuelFlow` — voir en-tête de fichier.
    var onSubmitRequested: (@escaping () -> Void) -> Void = { _ in }
    /// Appelé quand la copie est notée et l'attente adverse résolue.
    var onVerdict: (DuelVerdict) -> Void
    /// Appelé pour abandonner le défi sans gagner d'XP.
    var onAbandon: () -> Void

    @State private var now: Double = Date().timeIntervalSince1970 * 1000
    @State private var isSubmitting = false
    @State private var notice: String?
    @State private var waitingDeadline: Double?
    @State private var gradeTask: Task<Void, Never>?
    /// Fenêtre Premium ouverte quand le quota de corrections est épuisé
    /// (`paywallVisible` de la source).
    @State private var paywallVisible = false
    /// Quota de corrections du compte (`useCorrectionQuota`) : `nil` tant que le
    /// serveur n'a pas répondu, ou quand sa réponse n'est pas exploitable.
    @State private var quota: PremQuotaSnapshot?

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
                        icon: "alert-circle-outline",
                        text: "Tu avais déjà commencé cet exercice : ta note finale aura une pénalité de \(startedPenalty) points."
                    )
                }
                if opponentStartedBonus > 0 {
                    ChalRunNotice(
                        icon: "add-circle-outline",
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
        // `useCorrectionQuota` : la ligne d'état de la fenêtre Premium est
        // alimentée par le quota durable du compte, relu au montage.
        .task {
            quota = try? await PremQuotaService.load(token: session.token, userId: userId)
        }
        // Quota épuisé : la fenêtre Premium s'ouvre par-dessus la copie
        // (`PaywallModal`, `paywallVisible` de la source).
        .sheet(isPresented: $paywallVisible) {
            PremPaywallSheet(
                quota: quota,
                token: session.token,
                onClose: { paywallVisible = false }
            )
        }
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
            SubjAnswerComposition(answer: state.answers[state.activeQuestionId] ?? "")
            ChalRunAnswerTools(
                subject: match.subject,
                chapterId: chapterId,
                exercisePrompt: exercisePrompt,
                answer: answerBinding,
                disabled: isSubmitting
            )
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

    /// Chapitre porteur de l'exercice (`session.sourceItem.chapterId`) : dernier
    /// segment de la clé `année:matière:chapitre` du match. Il commande le mode
    /// de saisie (clavier Python) et les suggestions du clavier maths.
    private var chapterId: String? {
        match.chapterKey
            .split(separator: ":", omittingEmptySubsequences: false)
            .last.map(String.init)
    }

    /// Énoncé de l'exercice (`duelExercisePrompt`) : contexte transmis à la
    /// transcription photo et aux suggestions du clavier maths.
    private var exercisePrompt: String { duelExercisePrompt(state.exercise) }

    // MARK: Remise et attente

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView().tint(Theme.surface)
                } else {
                    IonIcon(name: "sparkles-outline", size: 18, color: Theme.white)
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
            waitingDeadline == nil ? onAbandon() : stopWaiting()
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
        // La fin du temps n'envoie **rien** toute seule : `handleTimeUp` de la
        // source ne fait que `setTimeIsUp(true)`. C'est le joueur qui appuie,
        // le libellé du bouton devenant « Temps écoulé — faire noter ».
    }

    /// « Ne pas attendre — défi non arbitré » : interrompt l'attente de la copie
    /// adverse (`opponentWait.current?.abort()`). Le verdict se résout alors
    /// localement, en défi non arbitré, et le bilan s'affiche.
    private func stopWaiting() {
        gradeTask?.cancel()
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
        let attempted = attemptedDuelAnswers(state.exercise, state.answers)
        // La copie rendue est aussi le dernier brouillon garanti dans
        // Entraînements, même si l'écran est quitté juste après le verdict
        // (`saveChallengeAttempt`, `ChallengesScreen.tsx:1421`).
        ChalProgress.saveAttempt(
            itemId: state.exercise.id, answers: attempted, accountId: userId
        )
        grade(token: token, attempted: attempted, production: state.submittedCopy)
    }

    /// Note la copie rendue et remet le verdict (`judgeDuel`). `scorePenalty` /
    /// `scoreBonus` portent l'avis d'exercice déjà commencé ; `opponentProduction`
    /// / `opponentAnswers` la copie de l'adversaire d'entraînement, quand elle
    /// est embarquée.
    private func grade(token: String, attempted: [String: String], production: String) {
        let matchRef = match
        let exerciseRef = state.exercise
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
                    scorePenalty: startedPenalty,
                    scoreBonus: opponentStartedBonus,
                    opponentProduction: exerciseRef.opponentProduction,
                    opponentAnswers: exerciseRef.opponentAnswers,
                    onWaitingForOpponent: { deadline in
                        Task { @MainActor in waitingDeadline = deadline }
                    }
                )
                await MainActor.run { onVerdict(verdict) }
            } catch let quota as DuelQuotaError {
                // Le quota est un refus produit : la copie reste rédigée, la
                // fenêtre Premium s'ouvre (le joueur peut réessayer au prochain
                // créneau ou s'abonner).
                let message = quota.message
                await MainActor.run {
                    notice = message
                    paywallVisible = true
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
