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
//  La géométrie de la barre (capsule de fond + remplissage borné, via
//  `GeometryReader`) est portée par le composant partagé `DuelloProgressTrack`
//  (`DuelloUI.swift`, vague 2) : on lui passe la piste blanche de la source
//  (`progressTrack.backgroundColor: colors.white` → `track: Theme.surface`) et
//  le remplissage neutre (`PROGRESS_FILL_COLORS.current` #D8D8D8 → `tint`), au
//  lieu de ré-implémenter la piste localement. Le filet de 1 pt
//  (`progressTrack.borderWidth: 1` / `borderColor: colors.border`) n'est pas
//  couvert par le composant → il reste posé en `overlay` local (brief vague 3 :
//  aligner le style d'écran quand le composant ne couvre pas le cas).
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
    /// Part remplie, entre 0 et 1 (bornée par `DuelloProgressTrack`).
    let fraction: Double
    /// Version fine, pour les lignes de chapitre de la liste.
    var compact: Bool = false

    /// Hauteur pleine (`styles.progressTrack.height`).
    static let fullHeight: CGFloat = 8
    /// Hauteur fine (`styles.progressTrackCompact.height`).
    static let compactHeight: CGFloat = 5
    /// Marge haute de la version pleine (`styles.progressTrack.marginTop`).
    static let fullTopMargin: CGFloat = 12

    private var trackHeight: CGFloat { compact ? Self.compactHeight : Self.fullHeight }

    var body: some View {
        DuelloProgressTrack(
            fraction: fraction,
            tint: SubjProgressFill.current,
            track: Theme.surface,
            height: trackHeight
        )
        // `progressTrack.borderWidth: 1` / `borderColor: colors.border` : filet
        // non porté par `DuelloProgressTrack` (composant sans bordure) → aligné ici.
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        .padding(.top, compact ? 0 : Self.fullTopMargin)
        // La barre est décorative : le pourcentage et son libellé
        // d'accessibilité vivent sur la ligne qui la porte
        // (`styles.itemProgressRow`, `styles.chapterProgressBar`).
        .accessibilityHidden(true)
    }
}
