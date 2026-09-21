// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// Sous Linux, `Foundation` fournit déjà `CGFloat`, `CGPoint`, `CGSize` et
// `CGRect` : les 11 fichiers de Duello qui importent `CoreGraphics`
// n'utilisent que ces quatre-là (vérifié par grep — ni `CGColor`, ni
// `CGPath`, ni `CGContext`, ni `CGImage`, ni `CGAffineTransform`).
// Un simple réexport suffit donc.
//
// ⚠️ `CGVector` n'est PAS fourni par Foundation sous Linux (vérifié sur
// Swift 6.1.2 / Linux) contrairement à ce qu'annonce SHIM_SPEC.md ; aucun
// fichier de Duello ne l'utilise, il n'est donc pas déclaré ici (le déclarer
// ferait doublon si Foundation l'ajoutait).
@_exported import Foundation
