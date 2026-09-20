# Fichiers en quarantaine

## ExerciseRewardViews.swift

Doublon du lot C du portage (composants de récompense / gradation de
l'espace de travail d'exercice). Déposé par une **autre session** pendant le
lot 4, en parallèle du fichier prévu par le contrat (`Duello/ExerciseGradingViews.swift`,
préfixe `ExG`).

Conservé ici — **hors de la cible Xcode** — pour ne pas compiler deux
implémentations concurrentes du même écran :

- `Duello/ExerciseGradingViews.swift` : retenu (conforme au contrat
  `PORTING_BATCH4.md`, types préfixés `ExG`, unicité respectée).
- `_stray/ExerciseRewardViews.swift` : types **non préfixés**, ce qui viole la
  convention d'unicité du `PORTING_BRIEF.md`.

À trancher par l'humain : supprimer, ou fusionner les apports utiles dans
`ExerciseGradingViews.swift`.
