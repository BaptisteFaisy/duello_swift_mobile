// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// `UserNotifications` n'existe pas sous Linux. Couvre `OnbFlowCredentials.swift`,
// `PushNotifNative.swift` et `NotificationScheduler.swift` : centre, réglages,
// autorisation, contenu mutable, déclencheur calendaire, requête.
//
// `UNAuthorizationStatus` reste une énumération non `@frozen` (importée d'un
// autre module) : les `@unknown default` des appelants restent donc licites.
import Foundation

public struct UNAuthorizationOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    public static let badge = UNAuthorizationOptions(rawValue: 1 << 0)
    public static let sound = UNAuthorizationOptions(rawValue: 1 << 1)
    public static let alert = UNAuthorizationOptions(rawValue: 1 << 2)
    public static let carPlay = UNAuthorizationOptions(rawValue: 1 << 3)
    public static let criticalAlert = UNAuthorizationOptions(rawValue: 1 << 4)
    public static let provisional = UNAuthorizationOptions(rawValue: 1 << 5)
}

public enum UNAuthorizationStatus: Int, Sendable {
    case notDetermined = 0
    case denied = 1
    case authorized = 2
    case provisional = 3
    case ephemeral = 4
}

open class UNNotificationSettings: NSObject {
    public var authorizationStatus: UNAuthorizationStatus { .notDetermined }
}

open class UNNotificationSound: NSObject {
    public static let `default` = UNNotificationSound()
}

open class UNNotificationContent: NSObject {
    public var title: String = ""
    public var subtitle: String = ""
    public var body: String = ""
    public var sound: UNNotificationSound?
    public var badge: NSNumber?
    public var userInfo: [AnyHashable: Any] = [:]
}

open class UNMutableNotificationContent: UNNotificationContent {}

open class UNNotificationTrigger: NSObject {}

open class UNCalendarNotificationTrigger: UNNotificationTrigger {
    public init(dateMatching dateComponents: DateComponents, repeats: Bool) { super.init() }
}

open class UNNotificationRequest: NSObject {
    public let identifier: String
    public let content: UNNotificationContent
    public let trigger: UNNotificationTrigger?

    public init(identifier: String, content: UNNotificationContent, trigger: UNNotificationTrigger?) {
        self.identifier = identifier
        self.content = content
        self.trigger = trigger
        super.init()
    }
}

open class UNUserNotificationCenter: NSObject {
    public static func current() -> UNUserNotificationCenter { UNUserNotificationCenter() }

    public func notificationSettings() async -> UNNotificationSettings { UNNotificationSettings() }

    public func requestAuthorization(options: UNAuthorizationOptions = []) async throws -> Bool {
        false
    }

    public func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }

    public func deliveredNotifications() async -> [UNNotificationRequest] { [] }

    public func add(_ request: UNNotificationRequest) async throws {}

    public func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}

    public func removeAllPendingNotificationRequests() {}

    public func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}

    public func removeAllDeliveredNotifications() {}
}
