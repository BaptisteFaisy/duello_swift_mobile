//
//  AdmAPIInbox.swift
//  Duello
//
//  Boîte de réception de l'administration : liste d'attente, feedbacks et
//  signalements.
//
//  Fichier source Expo porté : src/admin/adminApi.ts (`listAdminWaitlist`,
//  `listAdminFeedback`, `listAdminExerciseReports`, `listAdminUserReports`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

extension AdmAPI {
    /// `GET /admin/waitlist` (`listAdminWaitlist`).
    static func listWaitlist(token: String) async throws -> [AdmWaitlistEntry] {
        let data = try await request("admin/waitlist", token: token)
        let envelope = try? DuelloAPI.decoder.decode(WaitlistEnvelope.self, from: data)
        return envelope?.entries ?? []
    }

    /// `GET /admin/feedback` (`listAdminFeedback`).
    static func listFeedback(token: String) async throws -> [AdmFeedbackRecord] {
        let data = try await request("admin/feedback", token: token)
        let envelope = try? DuelloAPI.decoder.decode(FeedbackEnvelope.self, from: data)
        return envelope?.feedback ?? []
    }

    /// `GET /admin/exercise-reports` (`listAdminExerciseReports`).
    static func listExerciseReports(token: String) async throws -> [AdmExerciseReportRecord] {
        let data = try await request("admin/exercise-reports", token: token)
        let envelope = try? DuelloAPI.decoder.decode(ReportsEnvelope.self, from: data)
        return envelope?.reports ?? []
    }

    /// `GET /admin/user-reports` (`listAdminUserReports`).
    static func listUserReports(token: String) async throws -> [AdmUserReportRecord] {
        let data = try await request("admin/user-reports", token: token)
        let envelope = try? DuelloAPI.decoder.decode(UserReportsEnvelope.self, from: data)
        return envelope?.reports ?? []
    }

    /// Enveloppe `{ entries: [...] }`.
    private struct WaitlistEnvelope: Decodable {
        var entries: [AdmWaitlistEntry]?
    }

    /// Enveloppe `{ feedback: [...] }`.
    private struct FeedbackEnvelope: Decodable {
        var feedback: [AdmFeedbackRecord]?
    }

    /// Enveloppe `{ reports: [...] }` des signalements de contenus.
    private struct ReportsEnvelope: Decodable {
        var reports: [AdmExerciseReportRecord]?
    }

    /// Enveloppe `{ reports: [...] }` des signalements de comptes.
    private struct UserReportsEnvelope: Decodable {
        var reports: [AdmUserReportRecord]?
    }
}
