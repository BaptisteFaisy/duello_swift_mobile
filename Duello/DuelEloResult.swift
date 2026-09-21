//
//  DuelEloResult.swift
//  Duello
//
//  Cote arbitrée par le serveur pour un défi classé.
//
//  Porté de `AuthoritativeEloResult` (source Expo `src/utils/matchmaking.ts`) :
//
//      export interface AuthoritativeEloResult {
//        before: number;
//        after: number;
//        delta: number;
//        outcome: 'win' | 'loss' | 'draw' | 'forfeit_win' | 'forfeit_loss';
//      }
//
//  Ce type manquait : `DuelVerdict`, `DuelResultState`, `DuelGrading` et
//  `DuelloAPIDuel` le référencent, sans qu'aucune déclaration n'existe.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import Foundation

/// Cote avant/après un défi arbitré, avec la variation et l'issue.
///
/// `Equatable` est requis par `DuelResultState` (dont un cas porte un
/// `EloResult?`). L'issue reste une chaîne, telle que renvoyée par le serveur
/// (`win`, `loss`, `draw`, `forfeit_win`, `forfeit_loss`).
struct EloResult: Equatable {
    /// Cote du joueur avant le défi.
    var before: Int
    /// Cote du joueur après le défi.
    var after: Int
    /// Variation appliquée (`after - before`), positive ou négative.
    var delta: Int
    /// Issue arbitrée par le serveur.
    var outcome: String
}
