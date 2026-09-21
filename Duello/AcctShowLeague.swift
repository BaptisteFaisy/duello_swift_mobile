//
//  AcctShowLeague.swift
//  Duello
//
//  Vitrine du profil — blason de ligue et carte de ligue (lot 10-E, préfixe
//  `AcctShow`).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx, l. 1838-1840
//        (`viewedLeague`, `viewedLeagueBadge`, `leagueBadgeDisplaySize`)
//    - src/screens/AccountScreen.tsx, l. 2738-2810
//        (`showcase`, `showcaseHeader`, `showcaseIdentityRow`, `BadgeFlipHint`,
//         `FlippableLeagueBadge`, `leagueProgressInline`)
//    - src/utils/leagueBadges.ts (`leagueBadgeDisplaySize` → `LeagueBadges`)
//
//  Réutilise le kit et les lots déjà livrés : `LeagueBadges` (dont
//  `displaySize`, jamais redéfini ici), `AcctBadgeFlippable`,
//  `AcctBadgeRoundPhoto`, `LeagueBadgeFlipHint`, `PremPremiumBadge`, `Theme`.
//
//  La sélection du blason (`viewedLeagueBadge`) est reconstruite : la source
//  choisit un `ImageSource` local par `leagueBadgeSourceForLeague` (assets
//  embarqués), indisponibles en Swift ; on passe donc par l'identifiant de la
//  ligue consultée et `LeagueBadges.badgeURL(forLeague:)`.
//
//  Cible : iOS 16, aucune API iOS 17 ; aucune dépendance externe.
//
import SwiftUI

/// Mesures de la vitrine de ligue (`AccountScreen.tsx`).
enum AcctShowLeagueMetrics {
    /// `leagueBadgeDisplaySize(viewedLeague.id, 84)` : côté du blason de vitrine.
    static let badgeBaseSize: CGFloat = 84

    /// `PremiumBadge size={18}` : coche d'abonné dans la rangée du nom.
    static let premiumBadgeSize: CGFloat = 18

    /// `RoundProfilePhoto size={42}` : verso de la démonstration de retournement.
    static let hintPhotoSize: CGFloat = 42
}

/// Blason de ligue de la vitrine (`FlippableLeagueBadge`) : choisit le PNG de la
/// ligue consultée, le dimensionne par `leagueBadgeDisplaySize` et le rend
/// retournable, pastille de présence comprise.
struct AcctShowLeagueBadge: View {
    /// Ligue atteinte par le profil consulté (`viewedLeague`).
    let league: EloLeague
    /// Nom affiché au verso du blason.
    let name: String
    /// Photo publiée au verso (miniature `data:` ou adresse distante).
    let photoUri: String?
    /// Vrai lorsque l'identifiant public est connecté (PR #426).
    var online: Bool = false

    var body: some View {
        AcctBadgeFlippable(
            badgeURL: LeagueBadges.badgeURL(forLeague: league.id),
            leagueLabel: league.label,
            name: name,
            photoUri: photoUri,
            size: CGFloat(LeagueBadges.displaySize(
                forLeague: league.id,
                baseSize: Double(AcctShowLeagueMetrics.badgeBaseSize)
            )),
            online: online
        )
    }
}

/// Carte de ligue de la vitrine (`showcaseIdentityRow`) : identité à gauche
/// (nom, coche Premium, parcours) et blason de ligue à droite.
struct AcctShowLeagueCard: View {
    /// Nom du profil consulté (`viewedName`).
    let name: String
    /// Lignes du parcours : filière, année, option facultative.
    let pathLines: [String]
    /// Vrai si le profil consulté est abonné (`isViewedPremium`).
    var isPremium: Bool = false
    /// Bascule l'encart « membre Premium » au tap sur la coche.
    var onPremiumTap: (() -> Void)? = nil
    /// Ligue consultée ; `nil` masque le blason (`viewedLeagueBadge` absent).
    var league: EloLeague? = nil
    /// Photo publiée du verso du blason (`viewedPhotoUri`).
    var photoUri: String? = nil
    /// Vrai lorsque l'identifiant public est connecté.
    var online: Bool = false
    /// Compte privé : la vitrine masque alors le blason (`isMemberLocked`).
    var isLocked: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                nameRow
                path
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !isLocked, let league {
                AcctShowLeagueBadge(
                    league: league,
                    name: name,
                    photoUri: photoUri,
                    online: online
                )
                .padding(.top, 8)
            }
        }
    }

    /// Nom et coche Premium (`showcaseNameRow`) : la coche est un bouton dès
    /// qu'un geste est fourni.
    private var nameRow: some View {
        HStack(spacing: 7) {
            Text(name)
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)

            if isPremium {
                if let onPremiumTap {
                    Button(action: onPremiumTap) {
                        PremPremiumBadge(size: AcctShowLeagueMetrics.premiumBadgeSize)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Afficher le statut Premium de \(name)")
                } else {
                    PremPremiumBadge(size: AcctShowLeagueMetrics.premiumBadgeSize)
                }
            }
        }
    }

    /// Parcours publié (`showcasePath`) : une ligne par élément non vide.
    private var path: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
            }
        }
        .padding(.top, 6)
    }

    /// Lignes non vides, dans l'ordre d'Expo (filière, année, option).
    private var lines: [String] {
        pathLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

/// Encart « membre Premium » au pied de la carte de ligue
/// (`leagueProgressInline`) : bandeau gris, texte centré.
struct AcctShowLeaguePremiumNotice: View {
    /// Nom du profil consulté (`viewedName`).
    let name: String

    /// `premiumStatusMessage` : « … est un membre Premium. ».
    private var message: String { "\(name) est un membre Premium." }

    var body: some View {
        Text(message)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .padding(.top, 8)
            .accessibilityLabel(message)
    }
}

/// Démonstration du blason retournable posée au-dessus de la vitrine
/// (`BadgeFlipHint`, l. 2742-2756) : la face arrière est la photo ronde.
struct AcctShowLeagueFlipHint: View {
    /// Adresse du blason montré au recto.
    let badgeURL: URL?
    /// Nom porté par la photo du verso.
    let name: String
    /// Photo publiée du verso.
    let photoUri: String?
    /// Masque l'explication (`dismissProfilePhotoHint`).
    let onDismiss: () -> Void

    var body: some View {
        LeagueBadgeFlipHint(
            accessibilityLabel: "Démonstration du blason retournable",
            badgeURL: badgeURL,
            dismissAccessibilityLabel: "Masquer l’explication de la photo de profil",
            onDismiss: onDismiss
        ) {
            AcctBadgeRoundPhoto(
                name: name,
                photoUri: photoUri,
                size: AcctShowLeagueMetrics.hintPhotoSize
            )
        }
    }
}
