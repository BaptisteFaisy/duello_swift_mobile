//
//  AdmUI.swift
//  Duello
//
//  Petites briques d'interface communes aux écrans d'administration.
//
//  Fichiers source Expo portés :
//    - src/admin/AdminUsersScreen.tsx           (en-tête, barre de recherche,
//      carte d'état, libellé de section, tuile de métrique)
//    - src/admin/AdminWaitlistScreen.tsx        (carte d'état)
//    - src/admin/AdminFeedbackScreen.tsx        (barre de recherche)
//    - src/admin/AdminPromoCodesScreen.tsx      (libellé de champ)
//    - src/admin/AdminAnalyticsScreen.tsx       (tuile de métrique)
//    - src/admin/AdminExerciseReportsScreen.tsx (carte d'état)
//
//  Les couleurs, rayons et cartes viennent du kit partagé (`Theme`,
//  `.duelloCard()`) : rien n'est redéfini ici.
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

/// Titre de carte avec icône (« Accès aux données admin », « Sécurité… »).
struct AdmCardHeading: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.primary)
            Text(title)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// En-tête d'écran : intitulé, titre, sous-titre et bouton d'actualisation.
struct AdmPageHeader: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var refreshLabel: String? = nil
    var onRefresh: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .black))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.primary)
                Text(title)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer(minLength: 8)
            if let refreshLabel, let onRefresh {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.ink)
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
struct AdmSearchBar: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            TextField(placeholder, text: $text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
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
struct AdmStateCard: View {
    let icon: String
    let message: String
    var isLoading: Bool = false
    var tint: Color = Theme.inkSoft

    var body: some View {
        VStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .tint(Theme.primary)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
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

/// Tuile de métrique : valeur, libellé et précision facultative.
struct AdmMetricTile: View {
    var icon: String? = nil
    let label: String
    let value: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 32, height: 32)
                    .background(Theme.primaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
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
struct AdmNoticeCard: View {
    let icon: String
    let text: String
    var tint: Color = Theme.inkSoft

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }
}
