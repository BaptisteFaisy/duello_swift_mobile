//
//  PresenceViews.swift
//  Duello
//
//  Lot « Social » — présence temps réel : source de vérité, pastille de
//  présence et enveloppe d'avatar.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/PresenceProvider.tsx      (PresenceProvider, PresenceValue)
//    - src/components/AvatarPresence.tsx        (AvatarPresence)
//    - src/components/OnlineDot.tsx             (OnlineDot)
//    - src/hooks/usePresenceConnection.ts       (socket, reconnexion, arrière-plan)
//    - src/utils/presenceProtocol.ts            (presenceWebSocketUrl,
//                                                parsePresenceServerEvent,
//                                                applyPresenceEvent,
//                                                isPublicIdOnline)
//    - src/theme.ts                             (colors.online)
//
//  La socket est portée par `URLSessionWebSocketTask` (iOS 13+), l'équivalent
//  natif de `WebSocket` côté Expo : rien n'est simulé.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - Protocole de présence

/// Événement du serveur de présence (`PresenceServerEvent` de
/// `utils/presenceProtocol.ts`).
enum SocPresenceEvent: Equatable {
    /// Liste complète des connectés au moment de l'authentification.
    case ready([String])
    /// Un compte passe en ligne ou hors ligne.
    case presence(id: String, online: Bool)
    /// Le serveur refuse la socket (jeton expiré, par exemple).
    case error(code: String, message: String)
}

/// Lecture et application des messages du serveur
/// (`utils/presenceProtocol.ts`).
enum SocPresenceProtocol {
    /// Construit l'adresse de la socket à partir de l'URL d'API déjà embarquée :
    /// `https://hote/api` devient `wss://hote/api/presence`.
    static func socketURL(for apiURL: URL) -> URL? {
        guard var components = URLComponents(url: apiURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        switch components.scheme {
        case "https": components.scheme = "wss"
        case "http": components.scheme = "ws"
        default: return nil
        }

        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        if !path.hasSuffix("/presence") { path += "/presence" }
        components.path = path
        components.query = nil
        components.fragment = nil
        return components.url
    }

    /// Relit un message du serveur sans jamais accepter une forme inattendue
    /// (`parsePresenceServerEvent`).
    static func event(from raw: String) -> SocPresenceEvent? {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let value = object as? [String: Any],
              let type = value["type"] as? String
        else { return nil }

        switch type {
        case "ready":
            guard let online = value["online"] as? [Any] else { return nil }
            return .ready(online.compactMap { $0 as? String })
        case "presence":
            guard let id = value["id"] as? String,
                  let online = value["online"] as? Bool
            else { return nil }
            return .presence(id: id, online: online)
        case "error":
            guard let code = value["code"] as? String,
                  let message = value["message"] as? String
            else { return nil }
            return .error(code: code, message: message)
        default:
            return nil
        }
    }

    /// Applique un événement à l'ensemble courant (`applyPresenceEvent`). La
    /// liste `ready` remplace tout : elle est la photographie de référence au
    /// moment de la connexion.
    static func applying(_ event: SocPresenceEvent, to online: Set<String>) -> Set<String> {
        switch event {
        case let .ready(ids):
            return Set(ids)
        case let .presence(id, isOnline):
            var next = online
            if isOnline { next.insert(id) } else { next.remove(id) }
            return next
        case .error:
            return online
        }
    }
}

// MARK: - Source de vérité

/// État de présence de la session active (`PresenceProvider.tsx`,
/// `usePresenceConnection.ts`).
///
/// Une socket est ouverte par session : elle diffuse la liste des comptes en
/// ligne, puis chaque changement. Elle se ferme dès que l'application n'est plus
/// au premier plan — la personne n'est plus « en ligne » et l'appareil
/// n'entretient pas de connexion inutile — et se rouvre au retour, avec une
/// nouvelle tentative cinq secondes après une coupure involontaire.
///
/// Comme côté Expo, une coupure ne fait retomber que `isConnected` : la dernière
/// photographie (`onlineIds`) reste affichée jusqu'à la prochaine liste `ready`
/// du serveur, qui la remplace en entier.
///
/// L'instance partagée porte l'état : `SocialPresenceProvider`, monté une seule
/// fois à la racine, l'injecte dans l'environnement **et** pilote sa socket. Un
/// écran monté hors du fournisseur lit cette même instance et ne signale
/// personne en ligne — le repli exact du contexte React d'Expo, dont la valeur
/// par défaut est `isOnline: () => false`.
final class SocPresenceStore: ObservableObject {
    /// Instance partagée de l'application.
    static let shared = SocPresenceStore()

    /// Identifiants publics actuellement connectés.
    @Published private(set) var onlineIds: Set<String> = []
    /// Vrai lorsque la socket de présence est authentifiée.
    @Published private(set) var isConnected = false

    /// Délai avant une nouvelle tentative après une coupure involontaire
    /// (`RECONNECT_DELAY_MS` de `usePresenceConnection.ts`).
    static let reconnectDelayNanoseconds: UInt64 = 5_000_000_000

    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?

    /// Vrai lorsque l'identifiant public est actuellement connecté, faux pour
    /// tout autre cas (`isPublicIdOnline`).
    func isOnline(_ publicId: String?) -> Bool {
        guard let publicId, !publicId.isEmpty else { return false }
        return onlineIds.contains(publicId)
    }

    /// Applique un événement serveur à l'ensemble courant.
    @MainActor
    func apply(_ event: SocPresenceEvent) {
        if case .ready = event { isConnected = true }
        if case .error = event { isConnected = false }
        onlineIds = SocPresenceProtocol.applying(event, to: onlineIds)
    }

    /// Ouvre la socket de la session active.
    ///
    /// Sans compte connecté — ou sans jeton, comme `usePresenceConnection` qui
    /// attend une session serveur — rien ne s'ouvre : un invité local n'est
    /// jamais annoncé en ligne.
    ///
    /// Volontairement non isolée : les appelants sont les rappels SwiftUI
    /// (ouverture, retour au premier plan), qui s'exécutent déjà sur le fil
    /// principal.
    func connect(accountId: String, token: String?) {
        guard !accountId.isEmpty, let token, socket == nil else { return }
        guard let url = SocPresenceProtocol.socketURL(for: DuelloAPI.baseURL) else { return }

        let task = URLSession.shared.webSocketTask(with: url)
        socket = task
        task.resume()

        if let payload = try? JSONSerialization.data(withJSONObject: ["type": "authenticate", "token": token]),
           let text = String(data: payload, encoding: .utf8) {
            task.send(.string(text)) { _ in }
        }

        receiveTask = Task { [weak self] in
            await self?.receiveLoop(task, accountId: accountId, token: token)
        }
    }

    /// Ferme la socket : la personne n'est plus « en ligne ». La dernière
    /// photographie des connectés reste affichée, comme côté Expo.
    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        isConnected = false
    }

    /// Lit la socket jusqu'à sa fermeture et applique chaque événement.
    @MainActor
    private func receiveLoop(_ task: URLSessionWebSocketTask, accountId: String, token: String?) async {
        while !Task.isCancelled && socket === task {
            do {
                let message = try await task.receive()
                let raw: String?
                switch message {
                case let .string(value): raw = value
                case let .data(value): raw = String(data: value, encoding: .utf8)
                default: raw = nil
                }
                guard let raw, let event = SocPresenceProtocol.event(from: raw) else { continue }
                apply(event)
            } catch {
                await handleDisconnect(accountId: accountId, token: token)
                return
            }
        }
    }

    /// Coupure involontaire : la socket est abandonnée, puis une nouvelle
    /// tentative est programmée (`scheduleReconnect`).
    @MainActor
    private func handleDisconnect(accountId: String, token: String?) async {
        socket = nil
        isConnected = false
        try? await Task.sleep(nanoseconds: Self.reconnectDelayNanoseconds)
        guard !Task.isCancelled else { return }
        connect(accountId: accountId, token: token)
    }
}

// MARK: - Fournisseur

/// Diffuse l'état de présence de la session active à toute l'application
/// (`PresenceProvider.tsx`).
///
/// À monter une seule fois, à la racine, **sous** l'injection de `SessionStore`
/// (`DuelloApp`) : sans compte connecté, rien ne s'ouvre pour un invité local.
/// Les écrans lisent ensuite la source partagée, par l'environnement
/// (`@EnvironmentObject private var presence: SocPresenceStore`) ou directement
/// (`@ObservedObject var presence = SocPresenceStore.shared`).
struct SocialPresenceProvider<Content: View>: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var presence: SocPresenceStore = SocPresenceStore.shared
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environmentObject(presence)
            .task(id: session.token) {
                presence.connect(accountId: accountId, token: session.token)
            }
            .onChange(of: scenePhase) { phase in
                // La socket ne survit pas à la sortie du premier plan (`inactive`
                // comme `background`) ; au retour, la liste complète est
                // redemandée au serveur.
                if phase == .active {
                    presence.connect(accountId: accountId, token: session.token)
                } else {
                    presence.disconnect()
                }
            }
    }

    /// Identifiant public du compte actif : la socket n'ouvre rien pour un
    /// invité local, et se ferme à la déconnexion.
    private var accountId: String {
        session.session?.publicId ?? ""
    }
}

// MARK: - Pastille de présence

/// Teintes et mesures de la pastille (`OnlineDot.tsx`, `theme.ts`).
enum SocPresencePalette {
    /// `colors.online` d'Expo : le vert de la réussite, sans introduire une
    /// teinte de plus dans la palette.
    static let online = Color(hex: 0x22C55E)
    /// Diamètre par défaut (`OnlineDot`, `size = 10`).
    static let dotSize: CGFloat = 10
    /// Épaisseur du liseré blanc qui détache la pastille de la photo.
    static let dotBorder: CGFloat = 2
}

/// Pastille de présence décorative, **placée par l'appelant** : l'information
/// est déjà portée par la liste qui la contient (`OnlineDot.tsx`, PR #426).
///
/// Depuis la PR #426, le composant ne se positionne plus lui-même : le
/// placement par défaut (coin inférieur droit) appartient à l'enveloppe
/// (`SocialAvatarPresence`), et un appelant qui vise un autre bord — le blason
/// retournable de la vitrine de profil — fournit son propre alignement.
struct SocOnlineDot: View {
    /// Absent ou faux : rien n'est dessiné, comme `if (!online) return null`.
    var online: Bool? = nil
    var size: CGFloat = SocPresencePalette.dotSize

    var body: some View {
        if online == true {
            Circle()
                .fill(SocPresencePalette.online)
                .frame(width: size, height: size)
                .overlay(
                    Circle().stroke(Theme.surface, lineWidth: SocPresencePalette.dotBorder)
                )
                .accessibilityHidden(true)
        }
    }
}

/// Enveloppe neutre autour d'une photo de profil (`AvatarPresence.tsx`) : elle
/// n'impose ni taille ni forme, mais réserve le coin inférieur droit à la
/// pastille de présence — placement repris de la PR #426 (`styles.dot`). La
/// photo garde son propre style (bord arrondi, marges), donc la pastille n'est
/// jamais rognée par un `overflow: hidden`.
struct SocialAvatarPresence<Content: View>: View {
    /// Vrai lorsque l'identifiant public est connecté.
    var online: Bool = false
    /// Diamètre de la pastille ; `nil` reprend la taille par défaut d'Expo.
    var dotSize: CGFloat?
    /// Placement de la pastille dans l'enveloppe ; coin inférieur droit par
    /// défaut, comme la source.
    var dotAlignment: Alignment
    private let content: Content

    init(
        online: Bool = false,
        dotSize: CGFloat? = nil,
        dotAlignment: Alignment = .bottomTrailing,
        @ViewBuilder content: () -> Content
    ) {
        self.online = online
        self.dotSize = dotSize
        self.dotAlignment = dotAlignment
        self.content = content()
    }

    var body: some View {
        content
            .overlay(alignment: dotAlignment) {
                SocOnlineDot(online: online, size: dotSize ?? SocPresencePalette.dotSize)
            }
    }
}
