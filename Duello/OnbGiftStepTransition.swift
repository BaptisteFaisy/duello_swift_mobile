//
//  OnbGiftStepTransition.swift
//  Duello
//
//  LOT K — extras d’onboarding : le balayage horizontal entre les étapes.
//
//  Fichiers source Expo portés :
//    - src/components/OnboardingStepTransition.tsx (`OnboardingStepTransition`)
//    - src/utils/onboardingStepTransition.ts (`onboardingStepDirection`,
//      `resolveOnboardingSwipeDirection` et les constantes `SWIPE_DISTANCE`,
//      `SWIPE_FLICK_DISTANCE`, `SWIPE_FLICK_VELOCITY`,
//      `SWIPE_HORIZONTAL_DOMINANCE_RATIO`)
//
//  La source combine `react-native-gesture-handler` (activation manuelle :
//  l’axe vertical doit gagner tôt pour ne pas voler le défilement du
//  `ScrollView`) et `react-native-worklets`. `DragGesture` n’a pas ce conflit de
//  responder : la règle de résolution est appliquée à la fin du geste, et le
//  geste est posé en `simultaneousGesture` pour laisser le défilement intact.
//  `resolveHorizontalGestureIntent` (`utils/horizontalGesture.ts`) sert
//  uniquement à cette activation manuelle : hors périmètre.
//
//  ⚠️ `DragGesture` n’expose pas la vitesse de la source (`velocityX`, pt/s).
//  Le seuil de flick est donc porté sur le déplacement prédit par SwiftUI
//  (`predictedEndLocation - location`, proportionnel à la vitesse) : à
//  confirmer sur le Mac, avec un geste franc puis un geste lent.
//
//  Cible : iOS 16.
//
import SwiftUI

/// Enveloppe d’une étape : laisse le geste horizontal passer d’une étape à
/// l’autre, sans interrompre le défilement vertical du contenu.
struct OnbGiftStepTransition<Content: View>: View {
    /// Étape courante : conservée pour la parité avec les props de la source.
    var step: Int = 0
    /// Appelée sur un balayage vers la gauche (étape suivante).
    var onSwipeForward: (() -> Void)?
    /// Appelée sur un balayage vers la droite (étape précédente).
    var onSwipeBackward: (() -> Void)?
    /// Contenu de l’étape.
    @ViewBuilder var content: () -> Content

    var body: some View {
        if onSwipeBackward != nil || onSwipeForward != nil {
            content().simultaneousGesture(swipe)
        } else {
            content()
        }
    }

    /// Le geste, comme `.enabled(...)` de la source : la direction n’est
    /// décidée qu’au relâchement, exactement comme `onEnd`.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                let direction = OnbGiftSwipe.resolve(
                    translationX: value.translation.width,
                    translationY: value.translation.height,
                    predictedX: value.predictedEndLocation.x - value.location.x)
                switch direction {
                case .forward?:
                    onSwipeForward?()
                case .backward?:
                    onSwipeBackward?()
                case .none:
                    break
                }
            }
    }
}

/// Règles pures du balayage d’étape (`utils/onboardingStepTransition.ts`).
enum OnbGiftSwipe {
    /// Sens d’un changement d’étape (`OnboardingStepDirection`).
    enum Direction {
        case forward
        case backward
    }

    /// `onboardingStepDirection` : `nil` quand l’étape ne change pas.
    static func direction(previous: Int, next: Int) -> Direction? {
        if next == previous { return nil }
        return next > previous ? .forward : .backward
    }

    /// `resolveOnboardingSwipeDirection` : distance franchie, ou flick rapide.
    /// Un mouvement ambigu — trop vertical — ne décide rien.
    static func resolve(
        translationX: CGFloat,
        translationY: CGFloat,
        predictedX: CGFloat
    ) -> Direction? {
        let distanceX = abs(translationX)
        let isHorizontal = distanceX > abs(translationY) * 1.25
        let isFlick = distanceX >= 8 && abs(predictedX) >= 8
        guard isHorizontal, distanceX >= 32 || isFlick else { return nil }
        return translationX < 0 ? .forward : .backward
    }
}
