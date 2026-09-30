//
//  ChalClassInviteSheet.swift
//  Duello
//
//  Lot S01 (vague 6) — vue du volet « défi de classe » (port de
//  `ClassInviteModal`, `src/components/ChallengeInviteModal.tsx:1327-2010`) :
//  onglets Organiser / Participer, création et partage du rendez-vous, puis
//  recherche par code et liste des défis à venir / passés.
//
//  Le modèle vit dans `ChalClassInvite.swift` ; le branchement du « Rejoindre »
//  (`onJoinChallenge` → `ChalScheduledRoom.join`, S05) est posé par
//  `ChalIntChallengesTab` (extension `+ClassInvite`). L'enveloppe (voile,
//  panneau animé, glisser-pour-fermer) est déléguée au `.sheet` natif, comme
//  `SocialChallengeInviteModal`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - Volet

/// Contenu du volet « défi de classe », présenté par `ChalIntChallengesTab`
/// (`.sheet`). La fermeture est déléguée à l'appelant.
@MainActor
struct ChalClassInviteSheet: View {
    @StateObject private var model: ChalClassInviteModel
    private let onJoinChallenge: (ScheduledClassChallenge, Double) -> Void
    private let onClose: () -> Void

    init(
        organizerId: String,
        prepName: String,
        className: String,
        subject: String,
        durationMinutes: Int,
        token: String?,
        onJoinChallenge: @escaping (ScheduledClassChallenge, Double) -> Void,
        onClose: @escaping () -> Void
    ) {
        _model = StateObject(wrappedValue: ChalClassInviteModel(
            organizerId: organizerId,
            prepName: prepName,
            className: className,
            subject: subject,
            durationMinutes: Double(durationMinutes),
            token: token
        ))
        self.onJoinChallenge = onJoinChallenge
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            handle
            sectionTabs
            if model.section == .organize {
                organizeContent
            } else {
                participateContent
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 22)
        .background(Theme.surface)
    }

    // MARK: En-tête

    private var handle: some View {
        Capsule()
            .fill(Theme.border)
            .frame(width: 42, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 14)
            .accessibilityLabel("Faire descendre pour fermer")
    }

    private var sectionTabs: some View {
        HStack(spacing: 8) {
            ForEach(ChalClassInviteSection.allCases, id: \.self) { item in
                sectionTab(item)
            }
        }
        .padding(.top, 11)
    }

    private func sectionTab(_ item: ChalClassInviteSection) -> some View {
        let active = model.section == item
        return Button {
            model.section = item
            model.joined = false
        } label: {
            HStack(spacing: 5) {
                IonIcon(name: item.icon, size: 16, color: active ? .white : Theme.primary)
                Text(item.title)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(active ? .white : Theme.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(active ? Theme.primary : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10).stroke(Theme.primary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }

    // MARK: Organiser

    private var organizeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                label("VOTRE PRÉPA")
                field($model.prepName, placeholder: nil)
                label("VOTRE CLASSE")
                field($model.className, placeholder: "ECG1A")
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        label("JOUR")
                        field($model.date, placeholder: "12/09/2026")
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        label("HEURE")
                        field($model.time, placeholder: "18:00")
                    }
                    .frame(width: 110)
                }
                .padding(.top, 11)
                createButton
                if let error = model.organizerError {
                    Text(error)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 8)
                }
                if let created = model.created {
                    Text("Prévu le \(created.displayDate) à \(created.time)")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                // Regroupés : un `ViewBuilder` n'accepte que 10 enfants directs.
                Group {
                    codeCard
                    messageCard
                    channels
                }
            }
            .padding(.top, 11)
            .padding(.bottom, 12)
        }
    }

    private var createButton: some View {
        Button {
            Task { await model.save() }
        } label: {
            HStack(spacing: 7) {
                if model.creating {
                    ProgressView().tint(.white)
                } else {
                    IonIcon(name: "calendar-outline", size: 19, color: .white)
                }
                Text(model.created == nil ? "Créer le défi" : "Défi enregistré")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(!model.organizerReady || model.creating ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!model.organizerReady || model.creating)
        .padding(.top, 12)
    }

    private var codeCard: some View {
        Button {
            Task { await model.copyCode() }
        } label: {
            VStack(spacing: 0) {
                HStack {
                    label("CODE D'ACCÈS")
                    Spacer()
                    IonIcon(
                        name: model.copied ? "checkmark-circle" : "copy-outline",
                        size: 18,
                        color: Theme.primary
                    )
                }
                Text(model.accessCode)
                    .font(.system(size: 18, weight: .black))
                    .tracking(1.7)
                    .foregroundStyle(Theme.primary)
                Text(model.copied ? "Code copié" : "Appuie pour copier")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Theme.primary)
                    .padding(.top, 5)
            }
            .padding(11)
            .frame(maxWidth: .infinity)
            .background(Theme.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Theme.primary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copier le code d'accès")
        .padding(.top, 10)
    }

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                model.messageExpanded.toggle()
            } label: {
                HStack {
                    label("MESSAGE À ENVOYER")
                    Spacer()
                    IonIcon(
                        name: model.messageExpanded ? "chevron-up" : "chevron-down",
                        size: 17,
                        color: Theme.inkSoft
                    )
                }
            }
            .buttonStyle(.plain)
            if model.messageExpanded {
                Text(model.messages.first ?? "")
                    .font(.system(size: 12))
                    .lineSpacing(6)
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .padding(.top, 10)
    }

    private var channels: some View {
        HStack(spacing: 8) {
            channelButton(.whatsapp, label: "WhatsApp")
            channelButton(.instagram, label: "Instagram")
        }
        .padding(.top, 10)
    }

    private func channelButton(_ channel: SocShareChannel, label title: String) -> some View {
        Button {
            Task { await model.openChannel(channel) }
        } label: {
            HStack(spacing: 6) {
                IonIcon(name: channel.icon, size: 23, color: Theme.primary)
                Text(title)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Theme.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(Theme.primary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Envoyer dans un groupe \(title)")
    }

    // MARK: Participer

    private var participateContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                label("NOM DE LA PRÉPA")
                field($model.participantPrep, placeholder: nil)
                label("CLASSE")
                field($model.participantClass, placeholder: "ECG1A")
                label("CODE D'ACCÈS")
                field($model.participantCode, placeholder: "CL-ABC123")
                joinButton
                if let error = model.participantError {
                    Text(error)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.bottom, 12)
                }
                if model.joined {
                    challengeList
                }
            }
            .padding(.top, 11)
            .padding(.bottom, 24)
        }
    }

    private var joinButton: some View {
        Button {
            Task { await model.join() }
        } label: {
            HStack(spacing: 6) {
                if model.loading {
                    ProgressView().tint(.white)
                } else {
                    IonIcon(name: "enter-outline", size: 19, color: .white)
                }
                Text("Accéder aux défis")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(Theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(!model.participantReady || model.loading ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!model.participantReady || model.loading)
        .padding(.top, 2)
        .padding(.bottom, 13)
    }

    private var challengeList: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let nowMs = context.date.timeIntervalSince1970 * 1000
            let upcoming = model.challenges.filter { (model.startsAtMs($0) ?? 0) >= nowMs }
            let past = model.challenges.filter { (model.startsAtMs($0) ?? 0) < nowMs }
            VStack(alignment: .leading, spacing: 0) {
                Text("\(model.participantPrep) · \(model.participantClass)")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.ink)
                listSection("DÉFIS À VENIR")
                if upcoming.isEmpty {
                    Text("Aucun défi à venir pour le moment.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    ForEach(upcoming) { challenge in
                        upcomingCard(challenge, nowMs: nowMs)
                    }
                }
                listSection("DÉFIS PASSÉS")
                if past.isEmpty {
                    Text("Aucun défi passé pour le moment.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    ForEach(past) { challenge in pastCard(challenge) }
                }
            }
            .padding(.bottom, 12)
        }
    }

    private func upcomingCard(_ challenge: ScheduledClassChallenge, nowMs: Double) -> some View {
        let startsAt = model.startsAtMs(challenge)
        let waitingRoomOpen = DuelClassInvites.classChallengeWaitingRoomIsOpen(
            DuelClassInvites.ScheduledClassChallenge(date: challenge.date, time: challenge.time),
            now: nowMs
        )
        let minutesBefore = startsAt.map { start -> Int in
            let raw = (start - Double(DuelClassInvites.CLASS_CHALLENGE_WAITING_ROOM_MS) - nowMs) / 60_000
            return max(1, Int(ceil(raw)))
        }
        return HStack(spacing: 9) {
            IonIcon(name: "calendar-outline", size: 20, color: Theme.primary)
                .frame(width: 36, height: 36)
                .background(Theme.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 0) {
                Text(challenge.subject)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("\(challenge.displayDate) à \(challenge.time) · \(Int(challenge.durationMinutes)) min")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 3)
                if !waitingRoomOpen, let minutesBefore {
                    Text("Salle d'attente dans \(minutesBefore) min")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Theme.primary)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
            joinRoomButton(challenge, startsAt: startsAt, waitingRoomOpen: waitingRoomOpen)
        }
        .padding(11)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium).stroke(Theme.border, lineWidth: 1)
        )
        .padding(.bottom, 8)
    }

    private func joinRoomButton(
        _ challenge: ScheduledClassChallenge,
        startsAt: Double?,
        waitingRoomOpen: Bool
    ) -> some View {
        let enabled = waitingRoomOpen && startsAt != nil
        return Button {
            if let startsAt { onJoinChallenge(challenge, startsAt) }
        } label: {
            Text("Rejoindre")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 9)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(
            "Rejoindre la salle d'attente du défi du \(challenge.displayDate) à \(challenge.time)"
        )
    }

    private func pastCard(_ challenge: ScheduledClassChallenge) -> some View {
        HStack(spacing: 9) {
            IonIcon(name: "time-outline", size: 20, color: Theme.inkSoft)
                .frame(width: 36, height: 36)
                .background(Theme.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 0) {
                Text(challenge.subject)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("\(challenge.displayDate) à \(challenge.time)")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 3)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium).stroke(Theme.border, lineWidth: 1)
        )
        .padding(.bottom, 8)
    }


    // MARK: Primitives

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .black))
            .tracking(0.7)
            .foregroundStyle(Theme.inkSoft)
            .padding(.bottom, 6)
    }

    private func listSection(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .black))
            .tracking(0.8)
            .foregroundStyle(Theme.inkSoft)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }


    private func field(_ value: Binding<String>, placeholder: String?) -> some View {
        TextField(placeholder ?? "", text: value)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 11)
            .frame(minHeight: 38)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1)
            )
            .autocorrectionDisabled()
            .padding(.bottom, 10)
    }
}
