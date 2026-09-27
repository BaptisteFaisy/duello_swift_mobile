import Foundation

// Helpers de réinitialisation de mot de passe — état R1-AUTH (2026-09-27).
//
// Ce fichier portait une **seconde** implémentation de l'écran « Nouveau mot de
// passe » (`AcctSecPasswordResetForm`, en trois étapes demande / code / mot de
// passe) branchée sur le lien entrant en plus de `PasswordResetView`
// (`AccountPasswordResetView.swift`) : le point d'entrée était dédoublé.
//
// R1-AUTH (U04#3) : `DuelloApp.onOpenURL` ouvre désormais le **seul**
// `PasswordResetView` (jeton + appel serveur) et la feuille de connexion ouvre
// `ForgotPasswordView` (U03#1). L'écran dupliqué est retiré.
//
// Le transport `resetServerPassword` vit déjà, sur main, dans
// `AcctSecResetTransport` (`AcctSecResetTransport+Request.swift`), port fidèle
// de `passwordResetHttp.ts` (délai 8 s, classification des issues) : le helper
// local `AcctSecPasswordReset.sendReset` de V1 en faisait doublon et n'est pas
// repris (règle de réconciliation n°1 — main a déjà l'équivalent complet).
// `PasswordResetView` appelle directement
// `AcctSecResetTransport.resetServerPassword`.
//
// Cible : iOS 16. Aucune dépendance externe.
