import SwiftUI

/// Onglet « Défis » : recherche d'adversaire (file d'attente serveur),
/// défi en cours, classements matière et XP hebdo.
/// Reprend `src/screens/ChallengesScreen.tsx`, `RankingsScreen.tsx`
/// et `WeeklyXpRankingScreen.tsx`.
struct ChallengesView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    MatchmakingCard()
                    LeaderboardCard()
                    WeeklyXpCard()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Défis")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Appariement

private struct MatchmakingCard: View {
    @EnvironmentObject private var session: SessionStore

    @State private var isQueuing = false
    @State private var wait: (ms: Double, window: Int, queued: Int)?
    @State private var match: MatchView?
    @State private var showPlayer = false
    @State private var statusMessage = ""

    private let initialWindow = 80
    private let windowPerSecond = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Nouveau défi")
                Spacer()
                if let wait {
                    Text("\(Int(wait.queued)) en file")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.inkFaint)
                }
            }

            subjectPicker

            if let match {
                matchedView(match)
            } else if isQueuing {
                waitingView
            } else {
                Button {
                    joinQueue()
                } label: {
                    Label("Trouver un adversaire", systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(DuelloPrimaryButton())
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .duelloCard()
        .fullScreenCover(isPresented: $showPlayer) {
            if let current = match {
                NavigationStack {
                    ChallengePlayerView(
                        match: current,
                        userId: DuelloAPI.publicProfileId(email: session.profile.email),
                        onFinished: {
                            showPlayer = false
                            self.match = nil
                        }
                    )
                }
                .environmentObject(session)
            }
        }
    }

    @State private var selectedSubjectId = "maths"

    /// Les défis ne mobilisent que les mathématiques (`getChallengeTrackSubjects`
    /// filtre sur `subject.id === 'maths'` dans l'app Expo).
    private var subjects: [TrackSubject] {
        DuelloProgram.subjects(
            track: session.profile.track,
            specialty: session.profile.specialty,
            year: session.profile.year
        ).filter { $0.id == "maths" }
    }

    private var subjectPicker: some View {
        Picker("Matière", selection: $selectedSubjectId) {
            ForEach(subjects) { subject in
                Text(subject.name).tag(subject.id)
            }
        }
        .pickerStyle(.menu)
        .font(.system(size: 15, weight: .bold))
    }

    private var waitingView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Recherche d'un adversaire…")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
            if let wait {
                Text("Fenêtre de cote ±\(wait.window) · \(String(format: "%.0f", wait.ms / 1000)) s d'attente")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
            Button("Annuler la recherche") {
                Task { await leaveQueue() }
            }
            .font(.system(size: 13, weight: .heavy))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func matchedView(_ match: MatchView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Défi trouvé", systemImage: "bolt.badge.clock.fill")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text("Adversaire : \(match.opponent.displayName)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            Text("Matière : \(match.subject) · \(match.durationMinutes) min")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            Text("Exercice : \(match.exerciseId)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
                .lineLimit(1)
                .truncationMode(.middle)
            Button {
                // Le joueur complet : énoncé servi, rédaction sous chrono,
                // notation IA puis verdict (voir `ChallengePlayerView`).
                showPlayer = true
            } label: {
                Text("Commencer le défi")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(DuelloPrimaryButton())
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func joinQueue() {
        guard let token = session.token else {
            statusMessage = "Ta session a expiré, reconnecte-toi."
            return
        }
        // Le serveur n'apparie que les filières pourvues de banques réelles
        // (ECG et MPSI) et n'ouvre de défis que sur les mathématiques.
        guard session.profile.track == "ECG" || session.profile.track == "MPSI" else {
            statusMessage = "Les défis sont disponibles en ECG et MPSI pour l'instant."
            return
        }
        // `queuePools` borne la banque au budget du corps serveur (64 Ko) :
        // au-delà, la lecture de la requête échoue avant la validation.
        let pools = DuelloExerciseCatalog.queuePools(for: session.profile)
        guard !pools.isEmpty else {
            statusMessage = "Aucun exercice disponible pour ce parcours pour l'instant."
            return
        }
        let userId = DuelloAPI.publicProfileId(email: session.profile.email)
        let request = QueueRequest(
            userId: userId,
            displayName: session.profile.displayName,
            prepName: session.profile.prepName,
            track: session.profile.track,
            year: session.profile.year,
            specialty: session.profile.specialty.isEmpty ? nil : session.profile.specialty,
            subject: "Mathématiques",
            chapters: pools.keys.sorted(),
            exercisePools: pools,
            startedExerciseIds: [],
            allowStartedExercises: false,
            maxExercises: 1,
            elo: 1000
        )

        isQueuing = true
        statusMessage = ""
        Task {
            do {
                let state = try await DuelloAPI.joinQueue(request, token: token)
                await MainActor.run { handle(state) }
                if isQueuing {
                    await pollLoop(ticket: currentTicket(from: state), token: token)
                }
            } catch {
                await MainActor.run {
                    isQueuing = false
                    statusMessage = error.localizedDescription
                }
            }
        }
    }

    @State private var activeTicket: String?

    private func currentTicket(from state: QueueState) -> String? {
        if case .waiting(let ticket, _, _, _) = state { return ticket }
        if case .matched(let ticket, _) = state { return ticket }
        return nil
    }

    private func handle(_ state: QueueState) {
        switch state {
        case .waiting(let ticket, let waitedMs, let window, let queued):
            activeTicket = ticket
            wait = (waitedMs, window, queued)
        case .matched(_, let matchView):
            match = matchView
            isQueuing = false
            wait = nil
        case .expired:
            isQueuing = false
            statusMessage = "La recherche a expiré, relance-la."
        }
    }

    private func pollLoop(ticket: String?, token: String) async {
        guard let ticket else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            do {
                let state = try await DuelloAPI.pollQueue(ticket: ticket, token: token)
                await MainActor.run { handle(state) }
                if case .matched = state { return }
                if !isQueuing { return }
            } catch {
                // Une erreur passagère n'arrête pas la recherche : on reprend
                // la boucle au prochain cycle.
                continue
            }
        }
    }

    private func leaveQueue() {
        guard let token = session.token, let ticket = activeTicket else {
            isQueuing = false
            return
        }
        isQueuing = false
        Task {
            await DuelloAPI.leaveQueue(ticket: ticket, token: token)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy))
            .textCase(.uppercase)
            .foregroundStyle(Theme.inkSoft)
    }
}

// MARK: - Classement matière

private struct LeaderboardCard: View {
    @EnvironmentObject private var session: SessionStore

    @State private var entries: [LeaderboardEntry] = []
    @State private var state: LoadState = .idle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Classement — \(selectedSubjectName)")
                    .font(.system(size: 13, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                Button {
                    load()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(.plain)
            }

            switch state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            case .error:
                Text("Classement momentanément indisponible.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            case .ready:
                if entries.isEmpty {
                    Text("Personne n'est encore classé sur cette matière.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                } else {
                    ForEach(Array(entries.prefix(10).enumerated()), id: \.element.id) { index, entry in
                        rankRow(rank: index + 1, entry: entry, value: entry.elo.map { "\($0) Elo" } ?? "—")
                        if index < min(9, entries.count - 1) {
                            Divider()
                        }
                    }
                }
            }
        }
        .duelloCard()
        .onAppear { if state == .idle { load() } }
    }

    @State private var selectedSubjectName = "Mathématiques"

    private func load() {
        guard let token = session.token else {
            state = .error
            return
        }
        state = .loading
        Task {
            do {
                let result = try await DuelloAPI.subjectLeaderboard(subject: selectedSubjectName, token: token)
                await MainActor.run {
                    entries = result
                    state = .ready
                }
            } catch {
                await MainActor.run { state = .error }
            }
        }
    }

    private func rankRow(rank: Int, entry: LeaderboardEntry, value: String) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(rank <= 3 ? Theme.ink : Theme.inkFaint)
                .frame(width: 24)
            ZStack {
                Circle()
                    .fill(Theme.primaryLight)
                    .frame(width: 30, height: 30)
                Text(entry.displayName.prefix(1).uppercased())
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.inkSoft)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.displayName)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(entry.prepName.isEmpty ? "—" : entry.prepName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
            }
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}

// MARK: - XP hebdo

private struct WeeklyXpCard: View {
    @EnvironmentObject private var session: SessionStore

    @State private var entries: [LeaderboardEntry] = []
    @State private var state: LoadState = .idle

    private var subjectName: String { "Mathématiques" }
    private var week: String { WeeklyXP.weekKey() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("XP de la semaine — \(subjectName)")
                    .font(.system(size: 13, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                Text("Semaine du \(week)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }

            switch state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            case .error:
                Text("Classement momentanément indisponible.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            case .ready:
                if entries.isEmpty {
                    Text("Aucun XP enregistré cette semaine.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                } else {
                    ForEach(Array(entries.prefix(10).enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(index < 3 ? Theme.ink : Theme.inkFaint)
                                .frame(width: 24)
                            Text(entry.displayName)
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Spacer()
                            Text(entry.xp.map { String(format: "%.0f XP", $0) } ?? "—")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
            }
        }
        .duelloCard()
        .onAppear { if state == .idle { load() } }
    }

    private func load() {
        guard let token = session.token else {
            state = .error
            return
        }
        state = .loading
        Task {
            do {
                let result = try await DuelloAPI.weeklyXpLeaderboard(subject: subjectName, week: week, token: token)
                await MainActor.run {
                    entries = result
                    state = .ready
                }
            } catch {
                await MainActor.run { state = .error }
            }
        }
    }
}

// MARK: - État de chargement partagé

enum LoadState {
    case idle
    case loading
    case ready
    case error
}
