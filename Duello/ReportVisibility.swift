//
//  ReportVisibility.swift
//  Duello
//
//  Lot « Report » — visibilité sociale : tous les comptes élèves sont publics,
//  l'annuaire prime sur le téléphone pour la pastille d'abonnement.
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/utils/socialVisibility.ts (canViewFullProfile, followerProfiles,
//                                     viewedPremium, resolveViewedProfile)
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Visibilité et identité d'un profil consulté (`utils/socialVisibility.ts`).
enum ReportVisibility {

    /// Tous les comptes élèves sont publics (`canViewFullProfile`). La valeur
    /// historique `isPublic: false` peut encore provenir brièvement d'un cache
    /// ou d'un ancien serveur : elle ne verrouille jamais une fiche.
    static func canViewFullProfile(_ member: ReportSocialProfile, followerIds: [String]) -> Bool {
        true
    }

    /// Profils des abonnés, classés par nom (`followerProfiles`) : l'annuaire
    /// les renvoie dans l'ordre d'abonnement, qui ne veut rien dire à la lecture.
    static func followerProfiles(
        _ profiles: [ReportSocialProfile],
        followerIds: [String]
    ) -> [ReportSocialProfile] {
        let followers = Set(followerIds)
        return profiles
            .filter { followers.contains($0.id) }
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }

    /// Pastille d'abonné du profil affiché (`viewedPremium`).
    ///
    /// Sur son propre profil, l'abonnement se lit sur le téléphone ; sur celui
    /// d'un autre, seul l'annuaire sait. Un profil publié par une ancienne
    /// version ne dit rien : cette absence vaut « non abonné ».
    static func viewedPremium(ownPremium: Bool, selected: ReportSocialProfile?) -> Bool {
        guard let selected else { return ownPremium }
        return selected.isPremium
    }

    /// Identité rendue en tête de profil (`resolveViewedProfile`).
    ///
    /// Limite assumée : `currentTrackForProfile` / `normalizeAcademicPath`
    /// d'Expo ne sont pas reconstruits ici — `track` et `specialty` du profil
    /// local sont repris tels quels, et le champ historique `track` du profil
    /// distant prime sur `details.currentTrack`.
    static func resolveViewedProfile(
        own: UserProfile,
        selected: ReportSocialProfile?
    ) -> ReportViewedIdentity {
        guard let selected else {
            return ReportViewedIdentity(
                name: own.displayName.isEmpty ? "Préparationnaire" : own.displayName,
                photoUri: own.photoUri,
                prepName: own.prepName,
                track: own.track,
                year: own.year,
                targetSchool: own.targetSchool,
                specialty: own.specialty,
                personalGoal: own.personalGoal
            )
        }
        return ReportViewedIdentity(
            name: selected.displayName,
            photoUri: selected.photoUri,
            prepName: selected.prepName,
            track: selected.track,
            year: selected.year,
            targetSchool: selected.targetSchool,
            specialty: selected.specialty,
            personalGoal: selected.personalGoal
        )
    }
}
