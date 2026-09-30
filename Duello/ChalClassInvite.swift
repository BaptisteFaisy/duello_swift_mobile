//
//  ChalClassInvite.swift
//  Duello
//
//  Lot S01 (vague 6) — volet « défi de classe » : état et actions (organiser un
//  rendez-vous de classe, ou rejoindre la salle planifiée d'un défi existant).
//
//  Fichier source Expo porté : `src/components/ChallengeInviteModal.tsx`
//  (`ClassInviteModal`, :1327-2010) — création
//  (`createScheduledClassChallenge`), code d'accès, message de partage et canaux
//  WhatsApp / Instagram, puis recherche par code (`fetchScheduledClassChallenges`).
//  La vue (`ChalClassInviteSheet`) vit dans `ChalClassInviteSheet.swift` ; le
//  branchement (`onJoinChallenge` → `ChalScheduledRoom.join`, S05) est posé par
//  `ChalIntChallengesTab` (extension `+ClassInvite`).
//
//  Écarts assumés (iOS 16) : la copie passe par `UIPasteboard`, l'ouverture par
//  `UIApplication.open` (`Linking.openURL` d'Expo).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI
import UIKit

// MARK: - Modèle

/// Section du volet (`section` de la source).
enum ChalClassInviteSection: String, CaseIterable {
    case organize
    case participate

    /// Libellé d'onglet, mot pour mot de la source.
    var title: String {
        switch self {
        case .organize: return "Organiser"
        case .participate: return "Participer"
        }
    }

    /// Icône Ionicons de l'onglet.
    var icon: String {
        switch self {
        case .organize: return "settings-outline"
        case .participate: return "enter-outline"
        }
    }
}

/// État et actions du volet « défi de classe » (`ClassInviteModal`).
@MainActor
final class ChalClassInviteModel: ObservableObject {
    @Published var section: ChalClassInviteSection = .organize

    // Organiser
    @Published var prepName: String
    @Published var className: String
    @Published var date: String
    @Published var time: String
    @Published var created: ScheduledClassChallenge?
    @Published var creating = false
    @Published var organizerError: String?
    @Published var messageExpanded = false
    @Published var copied = false

    // Participer
    @Published var participantPrep = ""
    @Published var participantClass = ""
    @Published var participantCode = ""
    @Published var joined = false
    @Published var loading = false
    @Published var participantError: String?
    @Published var challenges: [ScheduledClassChallenge] = []

    private let organizerId: String
    private let subject: String
    private let durationMinutes: Double
    private let token: String?

    init(
        organizerId: String,
        prepName: String,
        className: String,
        subject: String,
        durationMinutes: Double,
        token: String?
    ) {
        self.organizerId = organizerId
        self.prepName = prepName
        self.className = className
        self.subject = subject
        self.durationMinutes = durationMinutes
        self.token = token
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .short
        self.date = formatter.string(from: Date().addingTimeInterval(24 * 60 * 60))
        self.time = "18:00"
    }

    // MARK: Dérivations

    /// Code d'accès lisible de la classe (`classChallengeAccessCode`).
    var accessCode: String {
        DuelClassInvites.classChallengeAccessCode(prepName: prepName, className: className)
    }

    /// [message d'invitation, message du code] (`scheduledClassInviteMessages`),
    /// avec les mêmes replis que la source quand un champ est vide.
    var messages: [String] {
        DuelClassInvites.scheduledClassInviteMessages(
            prepName: prepName.isEmpty ? "votre prépa" : prepName,
            className: className.isEmpty ? "votre classe" : className,
            date: date.isEmpty ? "à définir" : date,
            time: time.isEmpty ? "à définir" : time,
            accessCode: accessCode,
            stableDownloadUrl: SocInviteCopy.downloadURL
        )
    }

    var organizerReady: Bool {
        !prepName.trimmingCharacters(in: .whitespaces).isEmpty
            && !className.trimmingCharacters(in: .whitespaces).isEmpty
            && !date.trimmingCharacters(in: .whitespaces).isEmpty
            && !time.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var participantReady: Bool {
        !participantPrep.trimmingCharacters(in: .whitespaces).isEmpty
            && !participantClass.trimmingCharacters(in: .whitespaces).isEmpty
            && !DuelClassInvites.normalizeClassChallengeCode(participantCode).isEmpty
    }

    /// Départ prévu d'un défi en millisecondes epoch, `nil` si date/heure mal
    /// formées (`scheduledClassChallengeStartsAt`).
    func startsAtMs(_ challenge: ScheduledClassChallenge) -> Double? {
        let stored = DuelClassInvites.ScheduledClassChallenge(
            date: challenge.date,
            time: challenge.time
        )
        guard let startsAt = DuelClassInvites.scheduledClassChallengeStartsAt(stored) else {
            return nil
        }
        return startsAt.timeIntervalSince1970 * 1000
    }

    // MARK: Actions

    /// `saveClassChallenge` : enregistre le rendez-vous, ou expose l'échec.
    @discardableResult
    func save() async -> Bool {
        creating = true
        organizerError = nil
        defer { creating = false }
        let draft = ScheduledClassChallengeDraft(
            prepName: prepName,
            className: className,
            date: date,
            time: time,
            accessCode: accessCode,
            organizerId: organizerId,
            subject: subject,
            durationMinutes: durationMinutes
        )
        do {
            created = try await SocialApiEndpoints.createScheduledClassChallenge(draft, token: token)
            return true
        } catch {
            created = nil
            organizerError = error.localizedDescription
            return false
        }
    }

    /// `copyCode` : copie le code d'accès après enregistrement.
    func copyCode() async {
        guard await save() else { return }
        UIPasteboard.general.string = accessCode
        copied = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            self?.copied = false
        }
    }

    /// `openClassChannel` : enregistre, ouvre le canal puis copie le code.
    func openChannel(_ channel: SocShareChannel) async {
        guard await save() else { return }
        let parts = messages
        let message = parts.first ?? ""
        let codeMessage = parts.count > 1 ? parts[1] : accessCode
        guard let url = channel.url(message: message) else { return }
        _ = await open(url)
        try? await Task.sleep(nanoseconds: 650_000_000)
        UIPasteboard.general.string = codeMessage
        if channel == .whatsapp, let codeURL = channel.url(message: codeMessage) {
            _ = await open(codeURL)
        }
    }

    /// `joinClassChallenge` : vérifie le code, puis lit les défis de la classe.
    func join() async {
        guard DuelClassInvites.classChallengeCodeMatches(
            prepName: participantPrep,
            className: participantClass,
            code: participantCode
        ) else {
            joined = false
            participantError = "Ce code ne correspond pas à cette prépa et à cette classe."
            return
        }
        participantError = nil
        loading = true
        defer { loading = false }
        do {
            let found = try await SocialApiEndpoints.fetchScheduledClassChallenges(
                prepName: participantPrep,
                className: participantClass,
                accessCode: DuelClassInvites.normalizeClassChallengeCode(participantCode),
                token: token
            )
            challenges = found
            joined = true
            if found.isEmpty {
                participantError = "Aucun défi créé ne correspond encore à ces informations."
            }
        } catch {
            joined = false
            challenges = []
            participantError = error.localizedDescription
        }
    }

    /// Ouvre une adresse (`Linking.openURL`), en rendant la réussite.
    private func open(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { success in
                continuation.resume(returning: success)
            }
        }
    }
}
