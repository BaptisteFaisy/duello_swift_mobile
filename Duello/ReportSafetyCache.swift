//
//  ReportSafetyCache.swift
//  Duello
//
//  Lot T06 (vague 4 « couche transverse ») — TR-06 : éviction des caches à
//  l'occasion d'un blocage social.
//
//  Fichier source Expo porté (règle reprise mot pour mot) :
//    - src/utils/socialApi.ts (`evictBlockedMemberFromCaches`, appelé par
//      `blockSocialProfile` après le `POST /user-safety/blocks`).
//
//  `ReportSafetyAPI.block` posait le blocage sans toucher aux caches : le
//  compte bloqué restait affiché dans les classements déjà chargés, en mémoire
//  comme dans les instantanés persistés. Ce module les évince sans relire le
//  réseau.
//
//  Limite assumée : le cache de l'annuaire (`directoryBrowseCache`) vit dans
//  `AcctSearchDirectory.swift`, fichier de la vague W (un seul écrivain) : son
//  éviction reste à raccorder (vague 5). Les caches de classement, eux, sont
//  traités ici via l'API publique de `RankingsSnapshotCache`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Éviction des caches à l'occasion d'un blocage social (`socialApi.ts`).
enum ReportSafetyCache {

    /// `evictBlockedMemberFromCaches` : retire un compte bloqué des classements
    /// en cache — mémoire et instantanés persistés — sans relire le réseau.
    static func evictBlockedMember(_ memberId: String) async {
        guard !memberId.isEmpty else { return }
        let cache = RankingsSnapshotCache.shared
        guard let snapshots = await cache.load() else { return }
        for snapshot in snapshots {
            let filtered = snapshot.entries.filter { $0.id != memberId }
            cache.save(snapshot.cache, key: snapshot.key, entries: filtered)
        }
    }

    /// `blockSocialProfile` : pose le blocage puis évince immédiatement les deux
    /// comptes des surfaces sociales déjà chargées.
    static func blockAndEvict(targetId: String, token: String?) async throws -> ReportSafetyState {
        let state = try await ReportSafetyAPI.block(targetId: targetId, token: token)
        await evictBlockedMember(targetId)
        return state
    }
}
