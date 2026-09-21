//
//  EvEventSession.swift
//  Duello
//
//  Orchestration d'un événement, du décompte au classement.
//
//  Fichier source Expo porté : `src/hooks/useEventSession.ts`.
//  L'orchestrateur ne décide rien lui-même : les phases viennent de l'horaire
//  affiché (`EvEventSchedule`), la salle d'attente et l'état de correction du
//  serveur, et les réponses d'un brouillon local persisté par compte. Le dépôt
//  automatique de fin repose sur une comparaison d'instants, donc il part même
//  si l'application a dormi entre-temps.
//
//  Limite connue : le crédit local idempotent des XP et du delta Elo
//  (`src/utils/eventRewards.ts`) n'est pas porté — `ProgressStore`, partagé et
//  non modifiable dans ce lot, n'expose pas d'entrée pour un événement.
//
//  Cible : iOS 16.
//
import Foundation

/// Rythme de rafraîchissement du décompte et des états serveur.
private enum EvEventPolling {
    static let tick: TimeInterval = 1
    static let waitingRoomTicks = 10
    static let resultsTicks = 5
}

final class EvEventSession: ObservableObject {
    let event: EvEvent
    let email: String
    let token: String?
    private let accountId: String

    /// Seconde courante, partagée par le décompte et les seuils.
    @Published private(set) var now: Date
    @Published private(set) var phase: EvEventPhase
    /// Compteur de la salle d'attente, relu du serveur.
    @Published private(set) var waitingCount: Int?
    /// `nil` = inconnu, `false` = non inscrit, `true` = inscription posée.
    @Published private(set) var joined: Bool?
    @Published private(set) var joinError = ""
    @Published private(set) var draft = EvDraft()
    @Published private(set) var submission: EvSubmissionState = .draft
    @Published private(set) var submitError = ""
    @Published private(set) var results: EvResultsState?

    private var timer: Timer?
    private var tickCount = 0
    private var autoSubmitted = false

    init(event: EvEvent, email: String, token: String?) {
        self.event = event
        self.email = email
        self.token = token
        self.accountId = DuelloAPI.publicProfileId(email: email)
        let start = Date()
        self.now = start
        self.phase = EvEventSchedule.phase(event, now: start)
    }

    deinit { timer?.invalidate() }

    // MARK: Lecture

    /// Instant de début, ou `nil` si l'horaire est illisible.
    var startDate: Date? { EvEventSchedule.startDate(event) }
    /// Instant limite de participation, époque 0 quand l'horaire est illisible.
    var joinDeadlineDate: Date {
        EvEventSchedule.joinDeadline(event) ?? Date(timeIntervalSince1970: 0)
    }
    /// Durée affichée du sujet, en minutes.
    var durationMinutes: Int { Int((EvEventSchedule.duration(event) / 60).rounded()) }
    /// Une copie devient soumissible dès un caractère ou une photo.
    var draftHasContent: Bool { EvEventDraftStore.hasContent(draft) }
    /// Le nom affiché en classement reste l'identité locale du compte.
    var displayName: String {
        let local = email.split(separator: "@").first.map(String.init) ?? ""
        return local.isEmpty ? "Utilisateur Duello" : local
    }

    // MARK: Cycle de vie

    /// Charge le brouillon, pose la vue de la carte et démarre le décompte.
    func start() {
        draft = EvEventDraftStore.load(accountId: accountId, eventId: event.id)
        now = Date()
        phase = EvEventSchedule.phase(event, now: now)
        // La carte vient d'être ouverte : la vue est posée une fois par compte et
        // par événement côté serveur. Un échec reste silencieux.
        Task { await EvEventAPI.recordView(eventId: event.id, token: token) }
        if phase == .waiting { refreshWaitingRoom() }
        if phase == .finished { refreshResults() }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: EvEventPolling.tick, repeats: true) { [weak self] _ in
            self?.handleTick()
        }
    }

    /// Arrête le décompte quand la page se referme.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: Salle d'attente

    /// Rejoint la salle d'attente ; l'inscription ne vient que de ce bouton.
    func joinEventParticipation() {
        let eventId = event.id
        let token = self.token
        let name = displayName
        Task {
            do {
                let state = try await EvEventAPI.join(eventId: eventId, displayName: name, token: token)
                await MainActor.run {
                    self.waitingCount = state.participants
                    self.joined = true
                    self.joinError = ""
                }
            } catch {
                await MainActor.run {
                    self.joined = false
                    self.joinError = "Impossible de rejoindre pour le moment. Réessaie."
                }
            }
        }
    }

    // MARK: Copie

    /// Enregistre la réponse d'une question, et la retire quand elle se vide.
    func setAnswer(_ questionId: String, _ text: String) {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.answers.removeValue(forKey: questionId)
        } else {
            draft.answers[questionId] = text
        }
        draft.updatedAt = Date().timeIntervalSince1970 * 1000
        EvEventDraftStore.save(draft, accountId: accountId, eventId: event.id)
    }

    /// Ajoute les photos rendues avec la copie, sans doublon.
    func attachPhotos(_ uris: [String]) {
        var merged = draft.photoUris
        for uri in uris where !merged.contains(uri) { merged.append(uri) }
        draft.photoUris = merged
        draft.updatedAt = Date().timeIntervalSince1970 * 1000
        EvEventDraftStore.save(draft, accountId: accountId, eventId: event.id)
    }

    /// Dépose la copie ; le serveur borne l'instant de dépôt.
    func submit() {
        guard submission == .draft else { return }
        guard draftHasContent else {
            submitError = "Écris au moins une réponse ou ajoute une photo."
            return
        }
        submission = .submitting
        submitError = ""
        let eventId = event.id
        let answers = draft.answers
        let photos = draft.photoUris
        let token = self.token
        let accountId = self.accountId
        Task {
            do {
                _ = try await EvEventAPI.submitCopy(
                    eventId: eventId,
                    answers: answers,
                    photoUris: photos,
                    submittedAt: Date().timeIntervalSince1970 * 1000,
                    token: token
                )
                await MainActor.run {
                    self.submission = .submitted
                    EvEventDraftStore.clear(accountId: accountId, eventId: eventId)
                    self.refreshResults()
                }
            } catch {
                await MainActor.run {
                    self.submission = .draft
                    self.submitError = (error as? DirectoryError)?.message ?? "La copie n’a pas pu partir."
                }
            }
        }
    }

    // MARK: Horloge et relèves

    /// Avance d'une seconde, relit la phase et déclenche les relèves dues.
    private func handleTick() {
        now = Date()
        let next = EvEventSchedule.phase(event, now: now)
        if next != phase { phase = next }
        tickCount += 1
        if phase == .waiting, tickCount % EvEventPolling.waitingRoomTicks == 0 {
            refreshWaitingRoom()
        }
        if phase == .finished {
            autoSubmitIfNeeded()
            if tickCount % EvEventPolling.resultsTicks == 0 { refreshResults() }
        }
    }

    /// Dépôt automatique à la fin : une copie contenant au moins un caractère ou
    /// une photo part sans intervention, une seule fois.
    private func autoSubmitIfNeeded() {
        guard !autoSubmitted, draftHasContent else { return }
        autoSubmitted = true
        submit()
    }

    /// Salle d'attente : compteur relu sans s'inscrire, et reconnaissance d'un
    /// passage déjà enregistré via l'état de correction du serveur.
    private func refreshWaitingRoom() {
        let eventId = event.id
        let token = self.token
        Task {
            if let count = try? await EvEventAPI.participants(eventId: eventId, token: token) {
                await MainActor.run { self.waitingCount = count }
            }
            if let state = try? await EvEventAPI.results(eventId: eventId, token: token) {
                await MainActor.run { self.joined = state.own != nil }
            }
        }
    }

    /// Correction et classement : suivi régulier dès la fin de la participation.
    private func refreshResults() {
        let eventId = event.id
        let token = self.token
        Task {
            if let state = try? await EvEventAPI.results(eventId: eventId, token: token) {
                await MainActor.run { self.results = state }
            }
        }
    }
}
