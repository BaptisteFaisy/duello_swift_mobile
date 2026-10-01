//
//  ExGCorrectionHourglassShapes.swift
//  Duello
//
//  Formes du sablier de correction (`CorrectionHourglass.tsx`) : contour du
//  verre, polygone de sable et filet. Découpé de
//  `ExGCorrectionCountdownAndBars.swift` le 2026-09-29 (ratchet : 12 fonctions
//  > 10) — contenu repris **ligne pour ligne**.
//
//  Vague 8 (2026-10-02, lot I8-11) : `ExGHourglassGlassShape`,
//  `ExGHourglassSandShape`, `ExGHourglassStreamShape` et leur repère
//  `ExGHourglassBox` n'avaient pour seul appelant que `AnnCorrectionHourglass`,
//  retiré par I8-06 (`AnnCorrectionDock.swift` porte désormais
//  `ExGAnimatedHourglass(size: 26)`, dont les tracés vivent dans
//  `ExGCorrectionCountdownAndBars.swift`). Orphelins après vérification par
//  grep sur tout le dépôt, ils sont supprimés. Le fichier est conservé (vide)
//  pour ne pas rompre la référence `Duello.xcodeproj/project.pbxproj`
//  (`ExGCorrectionHourglassShapes.swift in Sources`).
//
//  Cible : iOS 16.
//
