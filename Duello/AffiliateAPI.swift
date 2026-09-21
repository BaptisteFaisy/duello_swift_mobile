import Foundation

// MARK: - Réseau de l'espace affiliation
//
// Portage de `src/utils/socialApi.ts` : `fetchAffiliateWallet`,
// `createAffiliateOnboardingLink`, `requestAffiliateWithdrawal` et
// `retryAffiliateWithdrawal`. Les routes sont celles du backend Duello :
// `affiliate/wallet`, `affiliate/connect/onboarding`, `affiliate/withdrawals`
// et `affiliate/withdrawals/{id}/retry`, sous `DuelloAPI.baseURL`.
//
// La source identifie le compte par `accountId` (`duelloApiRequest`) ; ici
// l'identité est le jeton de session, seule disponible dans l'app native.
//
// La clé d'idempotence du retrait voyage dans l'en-tête `Idempotency-Key`, que
// `DuelloAPI.request` n'expose pas : `postWithIdempotencyKey` reprend donc le
// contrat exact du transport partagé (`DuelloAPITransport.swift`) en y ajoutant
// cet en-tête, sans modifier le socle. Aucune donnée bancaire n'est conservée.

/// Points d'entrée du programme d'affiliation.
enum AffiliateAPI {
    /// `GET affiliate/wallet` — solde du compte de la session courante.
    static func wallet(token: String?) async throws -> AffWallet {
        let data = try await DuelloAPI.request("affiliate/wallet", token: token)
        do { return try AffiliateDecoding.wallet(from: data) } catch {
            throw DirectoryError(message: "Réponse du solde affilié illisible")
        }
    }

    /// `POST affiliate/connect/onboarding` — lien Stripe temporaire.
    static func onboardingLink(token: String?) async throws -> AffOnboarding {
        let data = try await DuelloAPI.request(
            "affiliate/connect/onboarding",
            method: "POST",
            token: token,
            body: Data("{}".utf8)
        )
        do { return try AffiliateDecoding.onboarding(from: data) } catch {
            throw DirectoryError(message: "Réponse Stripe illisible")
        }
    }

    /// `POST affiliate/withdrawals` — réserve puis verse un montant entier.
    static func requestWithdrawal(
        amountMinor: Int,
        idempotencyKey: String,
        token: String?
    ) async throws -> AffWithdrawal {
        guard amountMinor > 0 else {
            throw DirectoryError(message: "Montant du retrait invalide")
        }
        guard isValidIdempotencyKey(idempotencyKey) else {
            throw DirectoryError(message: "Clé de retrait invalide")
        }
        let body = try DuelloAPI.encodeBody(["amountMinor": amountMinor])
        let data = try await postWithIdempotencyKey(
            "affiliate/withdrawals",
            body: body,
            key: idempotencyKey,
            token: token
        )
        do { return try AffiliateDecoding.withdrawalResult(from: data) } catch {
            throw DirectoryError(message: "Réponse de retrait illisible")
        }
    }

    /// `POST affiliate/withdrawals/{id}/retry` — relance la partie bancaire.
    ///
    /// `id` provient toujours d'un retrait déjà décodé, donc d'un UUID validé :
    /// il n'est pas réencodé, comme `encodeURIComponent` sur un UUID.
    static func retryWithdrawal(id: String, token: String?) async throws -> AffWithdrawal {
        let data = try await DuelloAPI.request(
            "affiliate/withdrawals/\(id)/retry",
            method: "POST",
            token: token,
            body: Data("{}".utf8)
        )
        do { return try AffiliateDecoding.retryWithdrawal(from: data) } catch {
            throw DirectoryError(message: "Réponse de relance illisible")
        }
    }

    // MARK: Transport

    /// `^[a-zA-Z0-9._:-]{8,100}$` — validation de `requestAffiliateWithdrawal`.
    private static func isValidIdempotencyKey(_ value: String) -> Bool {
        guard (8...100).contains(value.count) else { return false }
        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:-"
        )
        return value.unicodeScalars.allSatisfy(allowed.contains)
    }

    /// `POST` portant `Idempotency-Key`, même contrat que `DuelloAPI.request`.
    private static func postWithIdempotencyKey(
        _ path: String,
        body: Data,
        key: String,
        token: String?
    ) async throws -> Data {
        var request = URLRequest(url: DuelloAPI.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DirectoryError(message: "Le serveur Duello est injoignable.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? DuelloAPI.decoder.decode(DirectoryError.self, from: data)
            throw DirectoryError(
                message: payload?.message ?? "Service indisponible (\(http.statusCode)).",
                status: http.statusCode
            )
        }
        return data
    }
}
