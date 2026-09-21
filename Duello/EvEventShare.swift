//
//  EvEventShare.swift
//  Duello
//
//  Canaux de partage d'un événement et message partagé : Message, WhatsApp et
//  Instagram, dans l'ordre du volet d'invitation des défis.
//
//  Fichier source Expo porté : `src/components/event/EventActionsBar.tsx`
//  (`ShareChannel`, `eventShareMessage`, ouverture des canaux). Le lien de
//  téléchargement vient de la configuration (`DUELLO_DOWNLOAD_URL`), dérivé de
//  l'origine de l'API comme `config/runtime-endpoints.cjs`.
//
//  Substitutions SF Symbols (Ionicons → SF Symbols) : chatbubble-outline →
//  message ; logo-whatsapp → phone.bubble.left ; logo-instagram → camera.
//
//  Cible : iOS 16.
//
import Foundation

/// Les trois canaux de partage, dans l'ordre du volet d'invitation.
enum EvShareChannel: String, CaseIterable, Identifiable {
    case sms, whatsapp, instagram

    var id: String { rawValue }

    /// Libellé affiché, mot pour mot de la source.
    var label: String {
        switch self {
        case .sms: return "Message"
        case .whatsapp: return "WhatsApp"
        case .instagram: return "Instagram"
        }
    }

    /// Symbole SF du canal, substitut du logo Ionicons.
    var symbol: String {
        switch self {
        case .sms: return "message"
        case .whatsapp: return "phone.bubble.left"
        case .instagram: return "camera"
        }
    }

    /// Libellé d'accessibilité, mot pour mot de la source.
    var accessibilityLabel: String {
        switch self {
        case .sms: return "Envoyer l’événement par message"
        case .whatsapp: return "Envoyer l’événement par WhatsApp"
        case .instagram: return "Partager l’événement par Instagram"
        }
    }
}

/// Message de partage et liens des canaux (`eventShareMessage`, `openShareChannel`).
enum EvEventShare {
    /// Lien de téléchargement embarqué (`${apiUrl}/download`).
    static let downloadUrl = DuelloAPI.baseURL.appendingPathComponent("download").absoluteString

    /// Message partagé, mot pour mot du composant Expo.
    static func message(for event: EvEvent) -> String {
        [
            "Concours blanc Duello : \(event.title), le \(event.date) à \(event.startTime ?? "").",
            "Rejoins-moi dans le classement !",
            "Télécharge Duello ici : \(downloadUrl)",
        ].joined(separator: "\n")
    }

    /// Lien WhatsApp prérempli du message.
    static func whatsappUrl(message: String) -> URL? {
        var components = URLComponents()
        components.scheme = "whatsapp"
        components.host = "send"
        components.queryItems = [URLQueryItem(name: "text", value: message)]
        return components.url
    }

    /// Boîte de réception Instagram, ouverte après copie du message.
    static func instagramInboxUrl() -> URL? {
        URL(string: "https://www.instagram.com/direct/inbox/")
    }
}
