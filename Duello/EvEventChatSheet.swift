//
//  EvEventChatSheet.swift
//  Duello
//
//  Chat d'un événement, ouvert depuis la bulle de la barre d'actions : les
//  messages des participants, du plus ancien au plus récent, et un champ
//  d'envoi. La liste se relit toutes les cinq secondes tant que le chat est
//  ouvert. Pendant l'épreuve, le chat est fermé : le champ disparaît et un mot
//  l'explique.
//
//  Fichier source Expo porté : `src/components/event/EventChatSheet.tsx`
//  (`EventChatSheet`, polling 5 s, max 500 caractères, formatage d'horloge
//  `formatEventClock`).
//
//  Icônes Ionicons :
//    - bouton d'envoi → `send` (18 pt, blanc sur noir, `ChatSendButton.tsx`).
//
//  Cible : iOS 16.
//
import SwiftUI

struct EvEventChatSheet: View {
    let eventId: String
    let eventTitle: String
    let token: String?
    let ownId: String?
    /// Faux pendant l'épreuve : le chat est alors fermé (`chatOpen`).
    let chatOpen: Bool
    /// Ouvre le profil du participant au clic sur son nom.
    var onOpenProfile: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [EvEventChatMessage]? = nil
    @State private var draft: String = ""
    @State private var sending: Bool = false
    @State private var sendError: String? = nil
    @State private var loadFailed: Bool = false
    @State private var closed: Bool = false
    @State private var pollingTask: Task<Void, Never>? = nil

    /// Nombre de tentatives du premier chargement avant d'avouer l'échec.
    private let loadAttempts = 3
    private let maxMessageLength = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Theme.border)
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)

            Text("Chat de l’événement")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 12)

            if closed || !chatOpen {
                Text("Chat fermé pendant l’épreuve. Il rouvrira dès la fin.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if messages == nil && !loadFailed {
                ProgressView()
                    .tint(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if loadFailed && (messages == nil || messages?.isEmpty == true) {
                VStack(spacing: 10) {
                    Text("La discussion est momentanément illisible.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await refresh() }
                    } label: {
                        Text("Réessayer")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 18)
                            .background(Theme.ink)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else if let list = messages, list.isEmpty {
                Text("Aucun message pour le moment. Lance la discussion !")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if let list = messages {
                GeometryReader { geo in
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(list) { message in
                                    row(message, maxWidth: geo.size.width * 0.85)
                                        .id(message.id)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        .onChange(of: list.count) { _ in
                            if let last = list.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            if chatOpen && !closed {
                composer
            }

            if let sendError {
                Text(sendError)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.like)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(Theme.surface)
        .presentationDetents([.fraction(0.82)])
        .task {
            await startLoading()
        }
        .onDisappear {
            pollingTask?.cancel()
            pollingTask = nil
        }
    }

    /// Ligne d'un message : auteur + horodatage au-dessus, bulle de texte.
    private func row(_ message: EvEventChatMessage, maxWidth: CGFloat) -> some View {
        let own = message.authorId == ownId
        return VStack(alignment: own ? .trailing : .leading, spacing: 3) {
            Button {
                dismiss()
                onOpenProfile?(message.authorId)
            } label: {
                HStack(spacing: 4) {
                    Text(own ? "Toi" : message.displayName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                    Text(EvEventDateFormatting.clock(Date(timeIntervalSince1970: message.createdAt / 1000)))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
                .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)
            .disabled(own || onOpenProfile == nil)
            .accessibilityLabel(own ? "Ton message" : "Voir le profil de \(message.displayName)")

            Text(message.body)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(own ? Color.white : Theme.ink)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(own ? Theme.ink : Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                .frame(maxWidth: maxWidth, alignment: own ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: own ? .trailing : .leading)
    }

    /// Champ de saisie et bouton d'envoi.
    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Écris un message…", text: $draft)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Theme.surfaceMuted)
                .clipShape(Capsule())
                .disabled(sending)
                .opacity(sending ? 0.6 : 1)
                .onChange(of: draft) { value in
                    // Longueur maximale d'un message, comme côté serveur.
                    if value.count > maxMessageLength {
                        draft = String(value.prefix(maxMessageLength))
                    }
                }
                .onSubmit { Task { await send() } }

            Button {
                Task { await send() }
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.ink)
                        .frame(width: 42, height: 42)
                    if sending {
                        ProgressView()
                            .tint(Color.white)
                            .controlSize(.small)
                    } else {
                        IonIcon(name: "send", size: 18, color: Color.white)
                    }
                }
                .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending ? 0.35 : 1)
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
            .accessibilityLabel("Envoyer le message")
        }
        .padding(.top, 10)
    }

    // MARK: - Réseau & Polling

    @MainActor
    private func startLoading() async {
        guard chatOpen else { return }
        messages = nil
        loadFailed = false
        closed = false

        for _ in 0..<loadAttempts {
            await refresh()
            if messages != nil || closed { break }
            try? await Task.sleep(nanoseconds: 800_000_000)
        }

        if messages == nil && !closed {
            loadFailed = true
        }

        // Relecture toutes les cinq secondes tant que le chat est ouvert.
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { break }
                await self.refresh()
            }
        }
    }

    @MainActor
    private func refresh() async {
        do {
            let state = try await EvEventAPI.chat(eventId: eventId, token: token)
            messages = state.messages
            loadFailed = false
            closed = false
        } catch let error as DirectoryError {
            // Le refus de l'épreuve (403) est un état, pas un incident.
            if error.status == 403 {
                closed = true
                loadFailed = false
            } else if messages == nil {
                loadFailed = true
            }
        } catch {
            if messages == nil { loadFailed = true }
        }
    }

    @MainActor
    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !sending, chatOpen else { return }
        sending = true
        sendError = nil
        do {
            try await EvEventAPI.postChat(eventId: eventId, text: text, token: token)
            draft = ""
            sending = false
            await refresh()
        } catch {
            sendError = (error as? DirectoryError)?.message ?? "Le message n’a pas pu partir."
            sending = false
        }
    }
}
