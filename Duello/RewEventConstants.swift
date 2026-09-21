//
//  RewEventConstants.swift
//  Duello
//
//  Constantes des récompenses d'événement.
//
//  Fichier source Expo porté (valeurs et commentaires repris mot pour mot) :
//    - src/utils/eventConstants.ts
//
//  Le sujet Elo crédité par un concours blanc est le sujet général des
//  classements de mathématiques ; les XP de participation restent
//  proportionnels à la durée (300 XP par heure), comme côté serveur.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import Foundation

/// `eventConstants.ts` : constantes partagées des récompenses d'événement.
enum RewEventConstants {
    /// `SUBJECT_ELO` : sujet Elo crédité, identique à celui des classements de
    /// mathématiques.
    static let subjectElo = "Mathématiques"

    /// `EVENT_XP_PER_HOUR` : XP de participation pour un sujet d'une heure.
    static let eventXpPerHour = 300
}
