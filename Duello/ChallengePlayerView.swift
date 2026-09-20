import SwiftUI
import Combine

/// Joueur d'un défi : énoncé réel servi par le backend, rédaction de la copie
/// sous chrono, notation IA via le relais, puis verdict et corrigé.
/// Reprend le flux de `src/screens/ChallengesScreen.tsx` : l'énoncé de la
/// banque devient la mise en situation, chaque question ouvre son champ, et
/// c'est l'IA — jamais le joueur — qui note la copie.
struct ChallengePlayerView: View {
    @EnvironmentObject private var session: SessionStore

    let match: MatchView
    /// Identifiant public du joueur (clé de dépôt de la copie côté serveur).
    let userId: String
    /// Appelé quand l'écran se referme, défi rendu ou abandonné.
    let onFinished: () -> Void

    private enum Phase: Equatable {
        case loading
        case unavailable(String)
        case writing
        case grading
        /// Copie déposée ; l'adversaire n'a pas encore rendu la sienne.
        case waitingOpponent(deadline: Double)
        case result
    }

    @State private var phase: Phase = .loading
    @State private var exercise: DuelExercise?
    @State private var statementText = ""
    @State private var answers: [String: String] = [:]
    @State private var verdict: DuelVerdict?
    @State private var quotaMessage: String?
    @State private var gradeTask: Task<Void, Never>?
    @State private var elapsed: Int = 0
    @State private var didAutoSubmit = false

    private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            switch phase {
            case .loading:
                ProgressView("Chargement de l'énoncé…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .unavailable(let message):
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                    Text(message)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                    Button("Retour aux défis") { onFinished() }
                        .buttonStyle(DuelloPrimaryButton())
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .writing:
                writingBody
            case .grading:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("L'IA compare les deux réponses…")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Ta copie est rendue. Le verdict arrive dès la notation.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .waitingOpponent(let deadline):
                waitingView(deadline: deadline)
            case .result:
                if let verdict {
                    resultView(verdict)
                }
            }
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Toujours disponible : rendre sa copie, attendre l'adversaire ou
            // lire le verdict, le joueur peut plier le défi à tout moment.
            ToolbarItem(placement: .cancellationAction) {
                Button("Abandonner") {
                    leaveDuel()
                }
                .font(.system(size: 13, weight: .heavy))
            }
        }
        .task { await loadExercise() }
        .onReceive(timer) { _ in tick() }
        .onDisappear {
            gradeTask?.cancel()
        }
    }

    // MARK: Chrono

    /// Le chrono tourne chez les deux joueurs à partir du `startedAt` du match.
    private var remainingSeconds: Int {
        let total = match.durationMinutes * 60
        return max(0, total - elapsed)
    }

    private var isTimeOver: Bool {
        remainingSeconds == 0
    }

    private func tick() {
        guard case .writing = phase else { return }
        let start = Date(timeIntervalSince1970: match.startedAt / 1000)
        elapsed = Int(Date().timeIntervalSince(start))
        if isTimeOver && !didAutoSubmit {
            // La fin du temps explique qu'une copie reste inachevée : elle
            // part quand même, le barème note l'avancement réel.
            didAutoSubmit = true
            submit()
        }
    }

    private func formatClock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: En-tête

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Défi — \(match.opponent.displayName)")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("\(match.subject) · \(match.durationMinutes) min")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer()
            if case .writing = phase {
                Text(formatClock(remainingSeconds))
                    .font(.system(size: 20, weight: .black).monospacedDigit())
                    .foregroundStyle(remainingSeconds <= 60 ? Theme.like : Theme.ink)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.surface)
    }

    // MARK: Chargement de l'énoncé servi

    private func loadExercise() async {
        guard exercise == nil else { return }
        guard let token = session.token else {
            phase = .unavailable("Ta session a expiré, reconnecte-toi.")
            return
        }
        do {
                // Le serveur sert les énoncés chapitre par chapitre : on
                // résout le chapitre du match — la clé serveur est
                // `<année>:maths:<chapitre>`, le manifeste ne porte que le
                // dernier segment — puis l'exercice exact tiré.
                let manifest = try await DuelloAPI.contentManifest()
                let chapterId = match.chapterKey.split(separator: ":", omittingEmptySubsequences: false).last.map(String.init) ?? match.chapterKey
                // Un même chapitre peut exister dans plusieurs banques servies
                // (MPSI et MP partagent des identifiants) : on retient celle
                // du parcours du joueur, comme le fait le choix de scope de
                // `DuelloExerciseCatalog.forProfile`.
                let candidates = (manifest.chapters ?? []).filter { $0.chapterId == chapterId }
                guard let descriptor = candidates.first(where: { $0.bundleId == expectedBundleId(for: match.chapterKey) }) ?? candidates.first else {
                    phase = .unavailable("Cet énoncé n'est pas encore servi pour ce parcours.")
                    return
                }
            let exercises = try await DuelloAPI.chapterExercises(descriptor)
            guard let found = exercises.first(where: { $0.key == match.exerciseId }) else {
                phase = .unavailable("Cet énoncé n'est plus disponible dans la banque.")
                return
            }
            let item = ChallengeExerciseEntry(
                id: found.key,
                title: found.title,
                statement: found.statement,
                solution: found.solution,
                questions: nil
            )
            let built = chapterItemAsDuelExercise(item, match.subject)
            statementText = LatexToUnicode.toUnicodeMath(item.statement ?? item.title)
            answers = Dictionary(
                uniqueKeysWithValues: built.questions.map { ($0.id, "") }
            )
            exercise = built
            phase = .writing
        } catch {
            phase = .unavailable("Impossible de charger l'énoncé : \(error.localizedDescription)")
        }
    }

    // MARK: Rédaction

    /// Banque servie attendue pour le parcours du joueur (`<scope>-statements`,
    /// même correspondance que les scopes de `DuelloExerciseCatalog`).
    private func expectedBundleId(for chapterKey: String) -> String? {
        let parts = chapterKey.split(separator: ":")
        guard parts.count >= 3, let year = Int(parts[0]) else { return nil }
        let applied = session.profile.specialty
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .contains("appliqu")
        switch session.profile.track {
        case "MPSI":
            return year == 2 ? "mp-statements" : "mpsi-statements"
        case "ECG":
            return applied ? "ecg-applied-\(year)-statements" : "ecg-advanced-\(year)-statements"
        default:
            return nil
        }
    }

    private var writingBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let exercise {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Énoncé", systemImage: "doc.text")
                            .font(.system(size: 13, weight: .heavy))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.inkSoft)
                        Text(statementText)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .duelloCard()

                    ForEach(Array(exercise.questions.enumerated()), id: \.element.id) { index, question in
                        answerField(exercise: exercise, index: index, question: question)
                    }

                    if let quotaMessage {
                        Text(quotaMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.like)
                    }

                    Button {
                        submit()
                    } label: {
                        Text("Rendre ma copie")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(DuelloPrimaryButton())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private func answerField(exercise: DuelExercise, index: Int, question: DuelExercise.Question) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if exercise.questions.count > 1 {
                Text("Question \(duelQuestionLabel(question, index))")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: Binding(
                    get: { answers[question.id] ?? "" },
                    set: { answers[question.id] = $0 }
                ))
                .font(.system(size: 15))
                .frame(minHeight: exercise.questions.count > 1 ? 96 : 150)
                .scrollContentBackground(.hidden)
                .background(Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.border, lineWidth: 1)
                )
                if (answers[question.id] ?? "").isEmpty {
                    Text("Ta réponse…")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.inkFaint)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: Attente de l'adversaire

    private func waitingView(deadline: Double) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("En attente de la copie adverse…")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("La note la plus haute l'emporte. Le serveur prononce le forfait à la date limite.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
            if deadline > 0 {
                Text("Date limite : \(Date(timeIntervalSince1970: deadline / 1000), style: .time)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: Verdict

    private func resultView(_ verdict: DuelVerdict) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: iconName(for: verdict))
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(Theme.ink)
                    Text(verdict.summary)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    if !verdict.ranked {
                        Text("Ce défi ne compte pas pour la cote : les copies n'ont pas été notées au même barème.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    if verdict.source == .local {
                        Text("Noté par le barème local : le correcteur IA était injoignable.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    if let elo = verdict.elo {
                        Text("Cote : \(elo.before) → \(elo.after) (\(elo.delta >= 0 ? "+" : "")\(elo.delta))")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(elo.delta >= 0 ? Theme.progress : Theme.like)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .duelloCard()

                let me = verdict.me
                copyCard(title: "Ta copie — \(me.score)/100", body: me.note)
                if let opponent = verdict.opponent {
                    copyCard(title: "Copie adverse — \(opponent.score)/100", body: opponent.note)
                }

                if let exercise, !attemptedAnswers(exercise).isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TA COPIE")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(Theme.inkFaint)
                        Text(joinDuelAnswers(exercise, answers))
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .duelloCard()
                }

                if let exercise, let solution = exercise.solution, !solution.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CORRIGÉ")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(Theme.inkFaint)
                        Text(LatexToUnicode.toUnicodeMath(solution))
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .duelloCard()
                }

                Button {
                    onFinished()
                } label: {
                    Text("Retour aux défis")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(DuelloPrimaryButton())
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private func copyCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.inkFaint)
            Text(body)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    private func iconName(for verdict: DuelVerdict) -> String {
        switch verdict.outcome {
        case .me: return "crown.fill"
        case .opponent: return "flag.checkered"
        case .draw: return "equal.circle"
        }
    }

    // MARK: Actions

    private func attemptedAnswers(_ exercise: DuelExercise) -> [String: String] {
        attemptedDuelAnswers(exercise, answers)
    }

    private func submit() {
        guard case .writing = phase, let exercise else { return }
        guard let token = session.token else {
            phase = .unavailable("Ta session a expiré, reconnecte-toi.")
            return
        }
        phase = .grading
        let attempted = attemptedAnswers(exercise)
        let production = joinDuelAnswers(exercise, answers)
        let matchRef = match
        let userRef = userId
        gradeTask = Task {
            do {
                let verdict = try await judgeDuel(
                    match: matchRef,
                    subject: matchRef.subject,
                    exercise: exercise,
                    myProduction: production,
                    answers: attempted,
                    userId: userRef,
                    token: token,
                    onWaitingForOpponent: { deadline in
                        Task { @MainActor in
                            self.phase = .waitingOpponent(deadline: deadline)
                        }
                    }
                )
                await MainActor.run {
                    self.verdict = verdict
                    self.phase = .result
                }
            } catch let quota as DuelQuotaError {
                // Le quota de défis est un refus produit : la copie reste
                // rédigée, l'élève peut réessayer au prochain créneau.
                let message = quota.message
                await MainActor.run {
                    self.quotaMessage = message
                    self.phase = .writing
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run {
                    self.quotaMessage = message
                    self.phase = .writing
                }
            }
        }
    }

    private func leaveDuel() {
        gradeTask?.cancel()
        if let token = session.token {
            Task {
                await DuelloAPI.abandonDuel(
                    matchId: match.id,
                    userId: userId,
                    token: token
                )
            }
        }
        onFinished()
    }
}
