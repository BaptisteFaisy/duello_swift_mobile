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
//  Icônes Ionicons : chatbubble-outline, logo-whatsapp, logo-instagram (22),
//  comme la source — plus de substitution SF Symbol.
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

    /// Nom Ionicons du canal, repris mot pour mot de la source.
    var ionName: String {
        switch self {
        case .sms: return "chatbubble-outline"
        case .whatsapp: return "logo-whatsapp"
        case .instagram: return "logo-instagram"
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
