// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// Combine n'existe pas sous Linux. Les fichiers portables n'utilisent que
// `ObservableObject` et `@Published` (sans projection `$`, sans éditeur) :
// ce shim minimal suffit à satisfaire le vérificateur de types.
import Foundation

public protocol ObservableObject: AnyObject {}

@propertyWrapper
public struct Published<Value> {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public var projectedValue: Published<Value> { self }
}
