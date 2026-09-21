//
//  OnbGiftLegalNotice.swift
//  Duello
//
//  LOT K — extras d’onboarding : la mention légale sous le formulaire.
//
//  Fichier source Expo porté : `src/components/OnboardingLegalNotice.tsx`
//  (`OnboardingLegalNotice` et son panneau `LegalPanel`).
//
//  Deux liens dans une phrase ouvrent les conditions d’utilisation et la
//  politique de confidentialité. La source présente chaque document dans un
//  `Modal` glissant occupant 85 % de la hauteur, avec un bouton « Fermer » ; ici
//  c’est une feuille système qui présente `TermsOfUseView` / `PrivacyPolicyView`,
//  déjà portées (`AccountLegalViews.swift`) et qui portent elles-mêmes leur
//  bouton « Fermer ». Les liens du texte attribué sont interceptés par
//  `OpenURLAction` : aucun navigateur n’est ouvert.
//
//  ⚠️ La source laisse l’appelant fournir le style (`style`); la vue porte ici
//  la typographie de l’onboarding sombre (`guestTermsText` : 11 pt, `#858585`,
//  centré, interligne 17).
//
//  Cible : iOS 16.
//
import Foundation
import SwiftUI

/// Mention légale : « En créant ton compte, tu acceptes les … de Duello. »
struct OnbGiftLegalNotice: View {
    @State private var page: OnbGiftLegalPage?

    var body: some View {
        Text(notice)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(Self.noticeColor)
            .tint(Self.noticeColor)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .environment(\.openURL, OpenURLAction { url in
                guard let target = OnbGiftLegalPage(url: url) else { return .systemAction }
                page = target
                return .handled
            })
            .sheet(item: $page) { target in
                switch target {
                case .terms:
                    TermsOfUseView()
                case .privacy:
                    PrivacyPolicyView()
                }
            }
    }

    /// La phrase exacte de la source, avec ses deux liens soulignés.
    private var notice: AttributedString {
        var text = AttributedString("En créant ton compte, tu acceptes les ")
        text.append(link("conditions d’utilisation", page: .terms))
        text.append(AttributedString(" et la "))
        text.append(link("politique de confidentialité", page: .privacy))
        text.append(AttributedString(" de Duello."))
        return text
    }

    /// Un lien souligné, de la couleur de la mention (`styles.link`).
    private func link(_ label: String, page: OnbGiftLegalPage) -> AttributedString {
        var run = AttributedString(label)
        if let url = page.url { run.link = url }
        run.underlineStyle = .single
        run.foregroundColor = Self.noticeColor
        return run
    }

    private static let noticeColor = Color(hex: 0x858585)
}

/// Page juridique ouverte depuis la mention d’onboarding.
enum OnbGiftLegalPage: String, Identifiable {
    case terms
    case privacy

    var id: String { rawValue }

    /// Schéma d’URL interne servant de lien dans le texte attribué.
    var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = rawValue
        return components.url
    }

    /// Reconnaît une URL de lien de la mention ; `nil` pour tout le reste.
    init?(url: URL) {
        guard url.scheme == Self.scheme, let host = url.host else { return nil }
        self.init(rawValue: host)
    }

    private static let scheme = "duello-legal"
}
