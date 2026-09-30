import Foundation
import UserNotifications

// Découpage par responsabilité (fichiers de ce module) :
// `NotificationPreferences.swift`, `NotificationScheduler.swift`,
// `NotificationSettingsCard.swift`, `NotificationInstalledPager.swift`.

// MARK: - Programmation des rappels locaux
//
// Écart A7-12 #26 (2026-09-30) — **code mort retiré**.
//
// Ce fichier portait `LocalNotificationScheduler`, un espace de noms qui
// programmait deux rappels locaux récurrents (entraînement quotidien, classement
// hebdomadaire) via `UNCalendarNotificationTrigger`. Il n'avait **aucun
// appelant** : `apply(_:)` était la seule entrée de programmation, jamais
// appelée, et ses identifiants n'étaient relus par personne. La source RN ne
// connaît aucune de ces deux relances : ses alertes sont **poussées par le
// serveur** (`src/utils/pushNotifications.ts`) et les seuls rappels locaux
// qu'elle pose sont ceux des **événements** (`src/utils/eventReminders.ts`,
// `Notifications.scheduleNotificationAsync`). Le portage conservait donc un
// pan de fonctionnalité absent du RN.
//
// Le pan est retiré : Swift ne programme plus de rappel local quotidien ni de
// classement, comme le RN. `NotificationPreferencesStore`
// (`NotificationPreferences.swift`) reste le magasin des préférences
// persistées, lu par les réglages ; ses valeurs ne pilotent plus aucun rappel
// local (elles n'en pilotaient déjà aucun).
