// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// Combine n'existe pas sous Linux. Les fichiers portables n'utilisent que
// `ObservableObject` et `@Published` (sans projection `$`, sans éditeur) :
// ce shim minimal suffit à satisfaire le vérificateur de types.
import Foundation

public protocol ObservableObject: AnyObject {}

/// Éditeur factice de `objectWillChange` : `send()` sans effet, `sink` rend un
/// `AnyCancellable` inerte. Assez pour `SessionStore` (relais du sous-store).
public final class ObservableObjectPublisher {
    public init() {}

    public func send() {}

    public func sink(receiveValue: @escaping () -> Void) -> AnyCancellable {
        AnyCancellable()
    }
}

public extension ObservableObject {
    /// `objectWillChange` (vrai Combine : `ObservableObjectPublisher`).
    var objectWillChange: ObservableObjectPublisher { ObservableObjectPublisher() }
}

/// Jeton d'annulation (`AnyCancellable`) — inerte sous Linux.
public final class AnyCancellable: Hashable {
    public init() {}

    public func cancel() {}

    public func store(in set: inout Set<AnyCancellable>) { set.insert(self) }

    public static func == (lhs: AnyCancellable, rhs: AnyCancellable) -> Bool { lhs === rhs }

    public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

@propertyWrapper
public struct Published<Value> {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public var projectedValue: Published<Value> { self }
}
