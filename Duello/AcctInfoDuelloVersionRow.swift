//
//  AcctInfoDuelloVersionRow.swift
//  Duello
//
//  Ligne « Version X.Y.Z » de la page Paramètres « Duello », portée de
//  `src/screens/AccountScreen.tsx` (4090-4112) : un 4e bloc sous
//  « Conditions d'utilisation », **non cliquable** (`accessibilityRole="text"`)
//  et **sans chevron**, au gabarit compact des liens légaux.
//
//  `APP_VERSION` de la source (`Constants.expoConfig?.version`,
//  `AccountScreen.tsx:461-462`) : l'équivalent iOS est la version du bundle
//  (`CFBundleShortVersionString`). La source ne rend rien quand la version est
//  absente (`{APP_VERSION ? … : null}`) : la ligne disparaît alors ici aussi.
//
//  Cible : iOS 16. Aucune dépendance externe.
//
import SwiftUI

struct AcctInfoDuelloVersionRow: View {
    /// `APP_VERSION` : version publiée du bundle, chaîne vide si absente.
    static var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
    }

    var body: some View {
        if !Self.appVersion.isEmpty {
            HStack(spacing: AcctInfoActionMetrics.compact.gap) {
                // `compactSettingsIcon` : pastille 34 × 34 blanche, icône 22 `primary`.
                IonIcon(
                    name: "information-circle-outline",
                    size: AcctInfoRowMetrics.iconSize,
                    color: Theme.primary
                )
                .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
                .background(Theme.surface)
                Text("Version \(Self.appVersion)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
            }
            .frame(minHeight: AcctInfoActionMetrics.compact.minHeight)
            .padding(.horizontal, 8)
            .padding(.vertical, AcctInfoActionMetrics.compact.verticalPadding)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Version \(Self.appVersion)")
        }
    }
}
