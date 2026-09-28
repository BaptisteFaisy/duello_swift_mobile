//
//  NotificationInstalledPager.swift
//  Duello
//
//  Tiroir de bureau du pager des notifications.
//
//  Fichier source Expo porté : `src/components/InstalledNotificationsPager.tsx`
//  (l. 8-17).
//
//  Sur le Web, quand l'application de bureau est installée
//  (`useInstalledDesktopLayout() && isDownloadedDesktopApp()`), le pager des
//  notifications se glisse dans le tiroir des classements
//  (`InstalledLeaderboardDrawer`, croix « Fermer les notifications »). Sur iOS
//  l'application n'est **jamais** la version bureau téléchargée : le test est
//  faux et le composant se réduit à son contenu (`OrderedTabPager`), comme la
//  branche `if (!installed || !props.onBack) return content` de la source.
//
//  V2 (28/09/2026, écart 20 #7) : ce fichier portait un « pager d'explications »
//  local, jamais monté et sans rapport avec la source ; il est réécrit en
//  portage fidèle (enveloppe neutre) et monté par `AcctIntNotificationsSheet`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Enveloppe du pager des notifications (`InstalledNotificationsPager`) : sur
/// iOS, le tiroir de bureau ne s'applique jamais, la vue rend donc son contenu.
struct InstalledNotificationsPager<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
    }
}
