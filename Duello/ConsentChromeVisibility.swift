//
//  ConsentChromeVisibility.swift
//  Duello
//
//  Visibilité du chrome de l'interface : la légende de progression d'un cours
//  (refermable) et le bandeau / la barre d'onglets pendant le défilement.
//
//  Fichiers source Expo portés :
//    - `src/hooks/useCourseLegendVisibility.ts` (visibilité persistée de la
//      légende, `readCourseLegendVisibility` / `dismiss`) ;
//    - `src/hooks/useScrollChromeVisibility.ts` (suivi de la direction du
//      défilement) ;
//    - `src/utils/trainingChromeVisibility.ts` (fonctions pures importées par
//      le hook précédent : seuils et session de défilement).
//
//  La source est un hook : il conserve `visible`, `reset` et les gestionnaires
//  `handleScrollBeginDrag` / `handleScroll` / `handleScrollEndDrag` /
//  `handleScrollMomentumEnd`. Un `enum` ne portant pas d'état, le portage
//  expose ici la logique pure ; l'état réactif et les rappels de défilement
//  restent à la charge de la vue hôte (`@State` + `GeometryReader`), comme les
//  cartes de réglages portées qui lisent directement `UserDefaults`.
//
//  Cible : iOS 16.
//
import Foundation

/// Légende de progression et chrome de défilement (`useCourseLegendVisibility`,
/// `useScrollChromeVisibility`).
enum ConsentChromeVisibility {

    // MARK: Légende de progression

    /// `ACCOUNT_STORAGE_KEYS.courseProgressLegendDismissed`. La source range la
    /// valeur par compte ; le portage conserve la clé logique, comme les autres
    /// stores portés (`CtdDocumentStore`, `AnnCopyModels`…).
    static let legendDismissedKey = "prepapp-course-progress-legend-dismissed:v1"

    /// `readCourseLegendVisibility` : la légende est visible tant qu'elle n'a
    /// pas été fermée ; une valeur illisible ou absente reste visible.
    static func isLegendVisible() -> Bool {
        UserDefaults.standard.string(forKey: legendDismissedKey) != "true"
    }

    /// `dismiss` : ferme la légende et l'enregistre pour le compte.
    static func dismissLegend() {
        UserDefaults.standard.set("true", forKey: legendDismissedKey)
    }

    // MARK: Chrome de défilement

    /// `TRAINING_CHROME_SWIPE_THRESHOLD` : descente qui masque les commandes.
    static let swipeThreshold: Double = 24
    /// `TRAINING_CHROME_REVEAL_THRESHOLD` : remontée qui les fait réapparaître.
    static let revealThreshold: Double = 12
    /// `TRAINING_CHROME_TOP_EPSILON` : tolérance autour du sommet de la liste.
    static let topEpsilon: Double = 1

    /// `ScrollChromeVisibilitySession` : visibilité demandée et position depuis
    /// laquelle mesurer la prochaine inversion de direction.
    struct Session: Equatable {
        var visible: Bool
        var anchorOffset: Double
    }

    /// `scrollChromeVisibilityAfterScroll` : visibilité après un déplacement.
    /// Les offsets négatifs du rebond en haut sont ramenés à zéro afin qu'un
    /// relâchement élastique ne masque pas les commandes.
    static func visibilityAfterScroll(
        visible: Bool,
        gestureStartOffset: Double,
        nextOffset: Double
    ) -> Bool {
        let start = max(0, gestureStartOffset)
        let next = max(0, nextOffset)
        let distance = next - start

        // Le sommet est une position canonique : les commandes n'y restent
        // jamais masquées.
        if !visible && next <= topEpsilon { return true }
        if distance >= swipeThreshold { return false }
        if distance <= -revealThreshold { return true }
        return visible
    }

    /// `beginScrollChromeVisibilitySession` : ouvre une session au début d'un
    /// geste ; au sommet, les commandes sont toujours visibles.
    static func beginSession(visible: Bool, startOffset: Double) -> Session {
        Session(
            visible: startOffset <= topEpsilon ? true : visible,
            anchorOffset: startOffset
        )
    }

    /// `scrollChromeVisibilitySessionAfterScroll` : fait avancer une session.
    /// Une inversion de direction par rapport à l'ancre décale seulement
    /// l'ancre ; sinon la visibilité est recalculée et l'ancre suit tout
    /// changement.
    static func sessionAfterScroll(_ session: Session, nextOffset: Double) -> Session {
        if (session.visible && nextOffset < session.anchorOffset)
            || (!session.visible && nextOffset > session.anchorOffset) {
            var reversed = session
            reversed.anchorOffset = nextOffset
            return reversed
        }

        let visible = visibilityAfterScroll(
            visible: session.visible,
            gestureStartOffset: session.anchorOffset,
            nextOffset: nextOffset
        )
        if visible == session.visible { return session }
        return Session(visible: visible, anchorOffset: nextOffset)
    }
}
