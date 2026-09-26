//
//  SubjProgressBar.swift
//  Duello
//
//  Lot 9-H « lignes de chapitre, étiquettes et barre de progression »
//  (préfixe `Subj`).
//
//  Fichier source Expo porté (libellés et mesures repris mot pour mot) :
//    - src/screens/SubjectsScreen.tsx
//        · lignes 2974-2995 : `PROGRESS_FILL_COLORS`, `ProgressBar`
//        · styles `progressTrack`, `progressTrackCompact`, `progressFill`,
//          `subjectProgressTrack`, `subjectProgressFill`, `itemProgressBar`,
//          `itemProgressValue`
//
//  `DuelloProgressTrack` (kit partagé) remplit sa barre au vert de la réussite
//  (`Theme.progress`) : il ne convient donc pas ici. La source peint au
//  contraire la part parcourue d'un gris très pâle et neutre
//  (`PROGRESS_FILL_COLORS.current`, #D8D8D8), sans dominante colorée — c'est
//  cette barre-ci que portent la fiche d'item et les lignes de chapitre.
//  Cible iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Remplissage neutre des barres d'avancement (`PROGRESS_FILL_COLORS`).
enum SubjProgressFill {
    /// #D8D8D8 : noir très pâle et neutre, sans dominante colorée.
    static let currentHex = 0xD8D8D8
    static let current = Color(hex: currentHex)
}

/// Barre d'avancement d'un item, mise à jour par le parcours de l'exercice
/// (`ProgressBar`).
///
/// `compact` donne la version fine des lignes de chapitre — 5 pt de haut, sans
/// marge haute (styles `progressTrackCompact`). La version pleine — 8 pt, 12 pt
/// de marge haute (style `progressTrack`) — sert aux barres d'item et de
/// matière.
struct SubjProgressBar: View {
    /// Part remplie, entre 0 et 1 (bornée avant dessin).
    let fraction: Double
    /// Version fine, pour les lignes de chapitre de la liste.
    var compact: Bool = false

    /// Hauteur pleine (`styles.progressTrack.height`).
    static let fullHeight: CGFloat = 8
    /// Hauteur fine (`styles.progressTrackCompact.height`).
    static let compactHeight: CGFloat = 5
    /// Marge haute de la version pleine (`styles.progressTrack.marginTop`).
    static let fullTopMargin: CGFloat = 12

    private var clampedFraction: Double { min(1, max(0, fraction)) }
    private var trackHeight: CGFloat { compact ? Self.compactHeight : Self.fullHeight }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surface)
                Capsule()
                    .fill(SubjProgressFill.current)
                    .frame(width: clampedFraction * geometry.size.width)
            }
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        }
        .frame(height: trackHeight)
        .padding(.top, compact ? 0 : Self.fullTopMargin)
        // La barre est décorative : le pourcentage et son libellé
        // d'accessibilité vivent sur la ligne qui la porte
        // (`styles.itemProgressRow`, `styles.chapterProgressBar`).
        .accessibilityHidden(true)
    }
}
