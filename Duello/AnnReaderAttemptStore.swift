//
//  AnnReaderAttemptStore.swift
//  Duello
//
//  Lecture et repères du lecteur d'annale : tentative persistée du sujet et
//  repère « classement vu » du trophée (18#8).
//
//  Fichier source Expo porté : `src/components/AnnaleViewer.tsx` (chargement de
//  la tentative à l'ouverture, `openExerciseLeaderboard`).
//
//  Cible : iOS 16.
//
import SwiftUI

extension AnnReaderView {
    /// Charge la tentative enregistrée du sujet pour le compte courant, ou une
    /// tentative vide (`loadAnnaleAttempt`).
    func loadAttempt() {
        let stored = AnnAttemptStore.loadAnnaleAttempts(accountId: accountId)[entry.id]
        attempt = stored ?? emptyAnnaleAttempt(itemId: entry.id)
    }

    /// `loadExerciseRankingSeen` : repères « classement vu » du compte.
    func loadRankingSeen() {
        rankingSeen = CollExerciseRankingSeen.load()
    }

    /// `openExerciseLeaderboard` : éteint la pastille « nouveau résultat » du
    /// trophée quand le classement s'ouvre, et retient la soumission vue.
    func markRankingSeen() {
        guard let latest = CollExerciseRankingSeen.latestSubmissionId(attempt?.metricHistory ?? [])
        else { return }
        rankingSeen[entry.id] = latest
        CollExerciseRankingSeen.mark(itemId: entry.id, submissionId: latest)
    }

    /// `setResultCardDismissedId` : referme le bilan pour la soumission en cours ;
    /// une nouvelle soumission le rouvrira.
    func dismissResultCard() {
        guard let correction else { return }
        resultCardDismissedId = correction.submissionId
    }
}
