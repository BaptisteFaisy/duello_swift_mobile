//
//  AdmAPIUsers.swift
//  Duello
//
//  Comptes utilisateurs et exception d'inscription, vus par l'administration.
//
//  Fichier source Expo porté : src/admin/adminApi.ts (`listAdminUsers`,
//  `registrationIpAccessRequest`, `getAdminRegistrationIpAccess`,
//  `setAdminRegistrationIpAccess`).
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

extension AdmAPI {
    /// `GET /admin/users` — registre complet des comptes (`listAdminUsers`).
    /// Une enveloppe illisible donne une liste vide, comme l'écran Expo.
    static func listUsers(token: String) async throws -> [AdmUserRecord] {
        let data = try await request("admin/users", token: token)
        let envelope = try? DuelloAPI.decoder.decode(UsersEnvelope.self, from: data)
        return envelope?.users ?? []
    }

    /// `GET /admin/registration-ip-allowlist`.
    static func getRegistrationIpAccess(token: String) async throws -> AdmRegistrationIpAccess {
        try await registrationIpAccessRequest(token: token, method: "GET")
    }

    /// `POST` (activer) ou `DELETE` (retirer) l'exception d'inscription.
    static func setRegistrationIpAccess(
        token: String,
        unlimited: Bool
    ) async throws -> AdmRegistrationIpAccess {
        try await registrationIpAccessRequest(token: token, method: unlimited ? "POST" : "DELETE")
    }

    /// `registrationIpAccessRequest` : une réponse incomplète est refusée
    /// (`Réponse du serveur admin illisible.`).
    private static func registrationIpAccessRequest(
        token: String,
        method: String
    ) async throws -> AdmRegistrationIpAccess {
        try await request(
            AdmRegistrationIpAccess.self,
            "admin/registration-ip-allowlist",
            token: token,
            method: method
        )
    }

    /// Enveloppe `{ users: [...] }`.
    private struct UsersEnvelope: Decodable {
        var users: [AdmUserRecord]?
    }
}
