import Foundation

// Port de `createServerSessionRegistry` (`src/utils/serverSessionRegistry.ts`) :
// registre mono-écrivain dont toutes les mutations du cache et de sa
// représentation persistée partagent la même file, y compris le premier
// chargement. Le stockage iOS étant synchrone, la sérialisation tient à un
// verrou : une ancienne invalidation ne peut jamais couper une sauvegarde plus
// récente entre sa vérification et son écriture.

/// Registre mono-écrivain d'une session serveur.
final class DevRegSessionRegistry<Session: DevRegTokenized> {
    private let storage: DevRegSessionStoring
    private let storageKey: String
    private let parse: (String?) -> Session?
    private let lock = NSLock()
    private var loaded = false
    private var cached: Session?

    init(
        storage: DevRegSessionStoring,
        storageKey: String,
        parse: @escaping (String?) -> Session?
    ) {
        self.storage = storage
        self.storageKey = storageKey
        self.parse = parse
    }

    /// Session courante, chargée à la première demande (`current`).
    func current() -> Session? {
        lock.lock()
        defer { lock.unlock() }
        return loadLocked()
    }

    /// Enregistre une session et la persiste (`save`).
    @discardableResult
    func save(_ session: Session) -> Session {
        lock.lock()
        defer { lock.unlock() }
        cached = session
        loaded = true
        persistLocked(session)
        return session
    }

    /// Transforme la session courante ; `nil` si aucune session
    /// (`updateCurrent`).
    @discardableResult
    func updateCurrent(_ update: (Session) -> Session) -> Session? {
        lock.lock()
        defer { lock.unlock() }
        guard let session = loadLocked() else { return nil }
        let updated = update(session)
        cached = updated
        persistLocked(updated)
        return updated
    }

    /// Invalide la session si son jeton correspond (`invalidate`).
    func invalidate(token: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let session = loadLocked(), session.token == token else { return false }
        cached = nil
        storage.removeItem(storageKey)
        return true
    }

    /// Efface la session et renvoie celle qui existait (`clear`).
    func clear() -> Session? {
        lock.lock()
        defer { lock.unlock() }
        let session = loadLocked()
        cached = nil
        storage.removeItem(storageKey)
        return session
    }

    // MARK: Interne

    private func loadLocked() -> Session? {
        if loaded { return cached }
        cached = parse(storage.getItem(storageKey))
        loaded = true
        return cached
    }

    private func persistLocked(_ session: Session) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        storage.setItem(storageKey, String(data: data, encoding: .utf8) ?? "")
    }
}
