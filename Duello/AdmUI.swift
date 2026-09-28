//
//  AdmUI.swift
//  Duello
//
//  Petites briques d'interface communes aux écrans d'administration.
//
//  Fichiers source Expo portés :
//    - src/admin/AdminUsersScreen.tsx           (en-tête, barre de recherche,
//      carte d'état, libellé de section, tuile de métrique, badge)
//    - src/admin/AdminWaitlistScreen.tsx        (carte d'état, bandeau)
//    - src/admin/AdminFeedbackScreen.tsx        (barre de recherche)
//    - src/admin/AdminPromoCodesScreen.tsx      (libellé de champ)
//    - src/admin/AdminAnalyticsScreen.tsx       (tuile de métrique, panneau)
//    - src/admin/AdminExerciseReportsScreen.tsx (carte d'état, barre de recherche)
//
//  Les couleurs, rayons et cartes viennent du kit partagé (`Theme`) : rien n'est
//  redéfini ici. Les icônes sont rendues avec la police Ionicons embarquée
//  (`IonIcon`), exactement comme la source (`<Ionicons name=… />`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI

/// Clé de rechargement d'un écran admin : actualisation demandée **et** clé
/// d'accès (`useEffect([reloadKey, token])` des écrans Expo — les deux entrées
/// relancent la requête).
struct AdmLoadKey: Equatable {
    var reload: Int
    var token: String
}

/// Message d'erreur affichable : texte du serveur, ou repli local en français.
enum AdmErrorText {
    static func message(_ error: Error, fallback: String) -> String {
        let text = error.localizedDescription
        return text.isEmpty ? fallback : text
    }
}

/// Ombre des cartes d'administration (`cardShadow` de `theme.ts` : opacité 0.04,
/// rayon 8, décalage `(0, 2)`).
extension View {
    func admCardShadow() -> some View {
        shadow(color: Theme.ink.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

/// Titre de carte avec icône (« Accès aux données admin », « Sécurité… »).
struct AdmCardHeading: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            IonIcon(name: icon, size: 20, color: Theme.primary)
            Text(title)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// En-tête d'écran : intitulé, titre, sous-titre et bouton d'actualisation.
/// `titleSize` vaut 28 partout sauf sur Analytics (30 dans la source) et
/// `eyebrowColor` reste l'encre partout sauf sur les signalements (rouge).
struct AdmPageHeader: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var refreshLabel: String? = nil
    var onRefresh: (() -> Void)? = nil
    var titleSize: CGFloat = 28
    var eyebrowColor: Color = Theme.primary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .black))
                    .textCase(.uppercase)
                    .foregroundStyle(eyebrowColor)
                Text(title)
                    .font(.system(size: titleSize, weight: .black))
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer(minLength: 8)
            if let refreshLabel, let onRefresh {
                Button(action: onRefresh) {
                    IonIcon(name: "refresh", size: 20, color: Theme.ink)
                        .frame(width: 42, height: 42)
                        .background(Theme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(refreshLabel)
            }
        }
    }
}

/// Barre de recherche des listes admin (nom, prépa, e-mail…).
/// Le bouton d'effacement est facultatif : la liste d'attente n'en a pas.
struct AdmSearchBar: View {
    let placeholder: String
    @Binding var text: String
    var showsClearButton: Bool = true

    var body: some View {
        HStack(spacing: 9) {
            IonIcon(name: "search", size: 18, color: Theme.inkSoft)
            TextField(placeholder, text: $text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if showsClearButton && !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    IonIcon(name: "close-circle", size: 19, color: Theme.inkFaint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

/// Carte d'état d'une liste : chargement, erreur ou liste vide.
///
/// `showsIconWhenLoading` reproduit les deux formes de la source : les cartes
/// `StateCard` (comptes, liste d'attente, codes promo) empilent l'icône, le
/// message puis l'indicateur ; les cartes écrites en ligne (analytics,
/// feedback, signalements) n'affichent que l'indicateur pendant le chargement.
struct AdmStateCard: View {
    let icon: String
    let message: String
    var isLoading: Bool = false
    var tint: Color = Theme.inkSoft
    var iconSize: CGFloat = 24
    var padding: CGFloat = 28
    var background: Color = Theme.surface
    var showsBorder: Bool = true
    var showsIconWhenLoading: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            if isLoading {
                if showsIconWhenLoading {
                    IonIcon(name: icon, size: iconSize, color: tint)
                }
                messageText
                ProgressView()
                    .tint(Theme.primary)
            } else {
                IonIcon(name: icon, size: iconSize, color: tint)
                messageText
            }
        }
        .frame(maxWidth: .infinity)
        .padding(padding)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            Group {
                if showsBorder {
                    RoundedRectangle(cornerRadius: Theme.radiusLarge)
                        .stroke(Theme.border, lineWidth: 1)
                }
            }
        )
    }

    private var messageText: some View {
        Text(message)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
    }
}

/// Intitulé de section en majuscules fines (« VUE D'ENSEMBLE »).
struct AdmSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .black))
            .textCase(.uppercase)
            .foregroundStyle(Theme.inkFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Variante d'affichage d'une tuile de métrique : les deux écrans qui l'utilisent
/// n'ont pas les mêmes mesures dans la source.
enum AdmMetricVariant {
    /// Fiche d'un compte (`metric` de `AdminUsersScreen.tsx`) : sans icône.
    case compact
    /// Écran Analytics (`metric` de `AdminAnalyticsScreen.tsx`) : avec icône.
    case analytics
}

/// Tuile de métrique : valeur, libellé et précision facultative.
struct AdmMetricTile: View {
    var icon: String? = nil
    let label: String
    let value: String
    var detail: String? = nil
    var variant: AdmMetricVariant = .compact

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let icon, variant == .analytics {
                IonIcon(name: icon, size: 18, color: Theme.ink)
                    .frame(width: 34, height: 34)
                    .background(Theme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 14)
            }
            Text(value)
                .font(.system(size: valueSize, weight: .black))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: labelSize, weight: labelWeight))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            if let detail {
                Text(detail)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Theme.border, lineWidth: 1)
        )
        // La tuile d'Analytics porte `...cardShadow`, celle de la fiche de
        // compte non (`metric` de `AdminUsersScreen.tsx`).
        .shadow(
            color: variant == .analytics ? Theme.ink.opacity(0.04) : .clear,
            radius: variant == .analytics ? 8 : 0,
            x: 0,
            y: variant == .analytics ? 2 : 0
        )
    }

    /// `metric` de `AdminAnalyticsScreen.tsx` : `padding:16`, rayon `large`,
    /// valeur 23, libellé 11/800.
    private var padding: CGFloat { variant == .analytics ? 16 : 15 }
    private var cornerRadius: CGFloat {
        variant == .analytics ? Theme.radiusLarge : Theme.radiusMedium
    }
    private var valueSize: CGFloat { variant == .analytics ? 23 : 17 }
    private var labelSize: CGFloat { variant == .analytics ? 11 : 10 }
    private var labelWeight: Font.Weight { variant == .analytics ? .heavy : .bold }
}

/// Libellé de champ de formulaire (« Remise % », « Expire dans… »).
struct AdmFieldLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(Theme.inkSoft)
    }
}

/// Bandeau d'information (isolation de l'espace, confidentialité des données).
/// Les mesures suivent celles de la source pour chaque écran : le bandeau de la
/// liste d'attente est sur `primaryLight` et centré, ceux de la fiche de compte
/// et d'Analytics sont sur `surfaceMuted`.
struct AdmNoticeCard: View {
    let icon: String
    let text: String
    var tint: Color = Theme.inkSoft
    var iconSize: CGFloat = 19
    var textSize: CGFloat = 12
    var padding: CGFloat = 13
    var background: Color = Theme.surfaceMuted
    var alignment: VerticalAlignment = .top
    var topPadding: CGFloat = 0

    var body: some View {
        HStack(alignment: alignment, spacing: 9) {
            IonIcon(name: icon, size: iconSize, color: tint)
            Text(text)
                .font(.system(size: textSize, weight: .regular))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .padding(.top, topPadding)
    }
}

/// Barre de progression des écrans admin (`track` / `pageTrack` de la source) :
/// piste `surfaceMuted`, part pleine à la teinte demandée.
struct AdmProgressTrack: View {
    let fraction: Double
    var tint: Color = Theme.primary
    var height: CGFloat = 7
    /// Plancher de la part pleine (`Math.max(2, …)` de la fiche de compte).
    var minimumFraction: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceMuted)
                Capsule()
                    .fill(tint)
                    .frame(width: filledWidth(in: geo.size.width))
            }
        }
        .frame(height: height)
    }

    /// Largeur de la part pleine, arrondie au pour cent comme la source.
    private func filledWidth(in total: CGFloat) -> CGFloat {
        guard fraction > 0 else { return 0 }
        let percent = (fraction * 100).rounded() / 100
        let effective = minimumFraction > 0 ? max(minimumFraction, percent) : percent
        return CGFloat(min(1, effective)) * total
    }
}

/// Pastille d'un écran admin (`badge` / `targetBadge` de `AdminUsersScreen.tsx`
/// et `AdminExerciseReportsScreen.tsx`) : la casse du libellé reste celle de la
/// source, aucune mise en majuscules.
struct AdmPill: View {
    let text: String
    var foreground: Color = Theme.ink
    var background: Color = Theme.primaryLight
    var fontSize: CGFloat = 10
    var weight: Font.Weight = .heavy
    var verticalPadding: CGFloat = 5
    var horizontalPadding: CGFloat = 10

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: weight))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(background)
            .clipShape(Capsule())
    }
}
