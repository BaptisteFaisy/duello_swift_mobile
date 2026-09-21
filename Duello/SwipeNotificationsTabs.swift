//
//  SwipeNotificationsTabs.swift
//  Duello
//
//  Pagination par geste des trois pages de notifications.
//
//  Fichier source Expo porté :
//    - src/utils/notificationsTabSwipe.ts
//        `NotificationsSwipePage`, `NOTIFICATIONS_SWIPE_PAGES`,
//        `resolveNotificationsTabSwipe`.
//
//  Les pages suivent leur ordre visuel : Notifications, Followers, Followings.
//  Comme dans le pager principal et les réglages, le doigt va à l'opposé de la
//  destination : vers la gauche pour avancer à droite, et inversement. Le calcul
//  est entièrement délégué au résolveur commun (`SwipeOrderedTabs`).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// Pages balayables de l'écran de notifications (`NotificationsSwipePage`).
enum SwipeNotificationsPage: String, CaseIterable, Equatable {
    case notifications
    case followers
    case followings
}

/// Ordre visuel des pages (`NOTIFICATIONS_SWIPE_PAGES`).
enum SwipeNotificationsTabs {
    /// Pages dans l'ordre d'affichage.
    static let pages: [SwipeNotificationsPage] = [.notifications, .followers, .followings]

    /// `resolveNotificationsTabSwipe` : cible du geste, `nil` si le doigt ne
    /// déclenche rien.
    static func resolve(
        currentPage: SwipeNotificationsPage,
        translationX: CGFloat,
        velocityX: CGFloat
    ) -> SwipeOrderedTabs.PageTarget<SwipeNotificationsPage>? {
        SwipeOrderedTabs.swipe(
            pages: pages,
            current: currentPage,
            translationX: translationX,
            velocityX: velocityX
        )
    }
}
