//
//  PlanStorage.swift
//  Duello
//
//  Écran « Plan » — persistance locale par compte (UserDefaults, clés com.duello.ios.plan.*).
//
import Foundation

// MARK: - Persistance locale

/// Équivalents iOS de `ACCOUNT_STORAGE_KEYS.programTasks`, `.classSchedule` et
/// `.ollamaSettings` (`prepapp-…` côté Expo). Les clés sont suffixées par
/// l'identifiant public du compte : deux élèves sur le même appareil ne
/// partagent pas leur programme.
enum PlanStorage {
    static func tasksKey(_ accountKey: String) -> String { "com.duello.ios.plan.tasks.\(accountKey)" }
    static func scheduleKey(_ accountKey: String) -> String { "com.duello.ios.plan.schedule.\(accountKey)" }
    static func ollamaKey(_ accountKey: String) -> String { "com.duello.ios.plan.ollama.\(accountKey)" }

    static func loadTasks(accountKey: String) -> [PlanTask]? {
        guard let data = UserDefaults.standard.data(forKey: tasksKey(accountKey)) else { return nil }
        return try? JSONDecoder().decode([PlanTask].self, from: data)
    }

    static func saveTasks(_ tasks: [PlanTask], accountKey: String) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: tasksKey(accountKey))
    }

    static func loadSchedule(accountKey: String) -> [PlanScheduleSlot]? {
        guard let data = UserDefaults.standard.data(forKey: scheduleKey(accountKey)) else { return nil }
        return try? JSONDecoder().decode([PlanScheduleSlot].self, from: data)
    }

    static func saveSchedule(_ slots: [PlanScheduleSlot], accountKey: String) {
        guard let data = try? JSONEncoder().encode(slots) else { return }
        UserDefaults.standard.set(data, forKey: scheduleKey(accountKey))
    }

    static func loadOllamaSettings(accountKey: String) -> PlanOllamaSettings? {
        guard let data = UserDefaults.standard.data(forKey: ollamaKey(accountKey)) else { return nil }
        return try? JSONDecoder().decode(PlanOllamaSettings.self, from: data)
    }

    static func saveOllamaSettings(_ settings: PlanOllamaSettings, accountKey: String) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: ollamaKey(accountKey))
    }
}
