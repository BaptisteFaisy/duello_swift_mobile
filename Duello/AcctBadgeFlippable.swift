//
//  AcctBadgeFlippable.swift
//  Duello
//
//  Blason retournable de la vitrine de profil — port de `FlippableLeagueBadge`
//  de `src/screens/AccountScreen.tsx` (l. 298-369), avec l'ajout de la PR #426
//  (`muse/presence-dot-blason`) : la pastille de présence de vitrine
//  (`SHOWCASE_PRESENCE_DOT_SIZE = 10`) est posée sur le bord sud-est du blason
//  au recto, et sur le bord sud-ouest de la photo au verso.
//
//  Le recto est le PNG du blason (chargé à distance, cf. `LeagueBadges`), le
//  verso la photo ronde (`AcctBadgeRoundPhoto`). Le retournement — 420 ms,
//  `Easing.inOut(Easing.cubic)`, `perspective: 700` — est transposé par
//  `rotation3DEffect` ; `perspective: 700` de React Native est approché par
//  `perspective: 0.5`, comme `LeagueBadgeFlipHint`. La géométrie de la pastille
//  est celle de `FlipBadgePresence` (réutilisée telle quelle), son dessin celui
//  de `SocOnlineDot`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Mesures du blason de vitrine (`AccountScreen.tsx`).
enum AcctBadgeMetrics {
    /// `SHOWCASE_PRESENCE_DOT_SIZE` (PR #426) : diamètre de la pastille de
    /// présence posée sur le blason retournable.
    static let showcasePresenceDotSize: CGFloat = 10

    /// Durée du retournement (`Animated.timing`, 420 ms).
    static let flipDuration: Double = 0.42
}

/// Blason de ligue à deux faces : le blason au recto, la photo au verso, et la
/// pastille de présence sur le bord de la face visible (`FlippableLeagueBadge`).
struct AcctBadgeFlippable: View {
    /// Adresse du blason ; `nil` ⇒ repli bouclier.
    let badgeURL: URL?
    /// Libellé de la ligue, lu par VoiceOver.
    let leagueLabel: String
    /// Nom affiché sur la photo du verso.
    let name: String
    /// Photo publiée du verso (miniature JPEG `data:` ou adresse distante).
    let photoUri: String?
    /// Côté du carré, en points.
    let size: CGFloat
    /// Vrai lorsque l'identifiant public est connecté (PR #426).
    var online: Bool = false

    /// Face actuellement visible : faux = blason, vrai = photo.
    @State private var showingPhoto = false

    var body: some View {
        Button(action: toggleFace) {
            ZStack {
                badgeFace
                photoFace
            }
            .frame(width: size, height: size)
            .overlay(alignment: .topLeading) { presenceDot }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: AcctBadgeMetrics.flipDuration), value: showingPhoto)
        .accessibilityLabel(faceLabel)
    }

    /// Recto : le blason, tourné de 0 à 180°.
    private var badgeFace: some View {
        badgeImage
            .frame(width: size, height: size)
            .rotation3DEffect(.degrees(showingPhoto ? 180 : 0),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .opacity(showingPhoto ? 0 : 1)
    }

    /// Verso : la photo ronde, tournée de 180 à 360°.
    private var photoFace: some View {
        AcctBadgeRoundPhoto(name: name, photoUri: photoUri, size: size)
            .rotation3DEffect(.degrees(showingPhoto ? 360 : 180),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .opacity(showingPhoto ? 1 : 0)
    }

    /// Blason chargé à distance (`resizeMode="contain"`), repli bouclier.
    @ViewBuilder
    private var badgeImage: some View {
        if let badgeURL {
            AsyncImage(url: badgeURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
        } else {
            Image(systemName: "shield")
                .font(.system(size: size * 0.7))
                .foregroundStyle(Theme.ink)
        }
    }

    /// Pastille de présence : bord sud-est du blason au recto, bord sud-ouest
    /// de la photo au verso (`FlipBadgePresence.dots`, `SocOnlineDot`).
    private var presenceDot: some View {
        let dots = FlipBadgePresence.dots(
            boxSize: size,
            dotSize: AcctBadgeMetrics.showcasePresenceDotSize
        )
        let anchor = showingPhoto ? dots.back : dots.front
        return SocOnlineDot(online: online, size: AcctBadgeMetrics.showcasePresenceDotSize)
            .offset(x: anchor.left, y: anchor.top)
    }

    /// Bascule d'une face à l'autre (`toggleFace`).
    private func toggleFace() {
        showingPhoto.toggle()
    }

    /// Libellé VoiceOver du bouton, selon la face visible (`accessibilityLabel`).
    private var faceLabel: String {
        showingPhoto
            ? "Afficher le blason de la ligue \(leagueLabel) de \(name)"
            : "Afficher la photo de profil de \(name) au verso du blason"
    }
}
