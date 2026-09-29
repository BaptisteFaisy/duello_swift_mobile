import Foundation
import SwiftUI

// MARK: - Feuille de classement

/// Version feuille du classement, présentée par les écrans qui affichent un
/// classement (coupes Maths et Défis). Portage de
/// `src/components/LeaderboardModal.tsx` : contenu plein écran, chevron de
/// fermeture **dans l'en-tête** (comme `BackButton` de `LeaderboardScreen.tsx`)
/// et classements identiques à `RankingsView`.
///
/// La source est un `Modal` transparent **sans animation native**
/// (`animationType="none"`) dont la page arrive de la droite : entrée
/// `withTiming(0, 260 ms, Easing.out(Easing.cubic))`, sortie
/// `withTiming(largeur, 200 ms, Easing.in(Easing.cubic))` et glisser-fermer
/// `withSpring(damping: 33, stiffness: 500, mass: 0.55)` (`LeaderboardModal.tsx`
/// l.34-44, 98-111, 166-189, 225-244, 291-303).
///
/// Extrait de l'ancien `RankingsView.swift` : dépend seulement de
/// `RankingScreenTabs` (`RankingsView`) et de ses deux onglets, sans renommage.
///
/// Écarts assumés (2026-09-29) :
/// 1. **Présentation** : les appelants présentent cette vue via `.sheet`
///    (`TrainingCatalogView+Entry.swift:126`, `ChalIntChallengesTab.swift:91`),
///    fichiers hors lot. La feuille garde donc son mouvement vertical natif et
///    son geste de fermeture vers le bas ; le `Modal` transparent plein écran de
///    la source ne peut pas être substitué depuis ce seul fichier. La source
///    n'a **pas de voile** (page transparente) : aucun voile ajouté.
/// 2. **Enfants maintenus pendant la sortie** (`lastVisibleChildren`) : SwiftUI
///    démonte la feuille à la fermeture ; non repris (la sortie rejoue le
///    contenu encore monté).
/// 3. **`overshootClamping`** : sans équivalent SwiftUI ; le ressort retenu
///    (`damping 33`) est quasi critique (ζ ≈ 0,995), donc sans dépassement.
/// 4. **Gestes** : `manualActivation` / `cancelAnimation` / worklets sans
///    équivalent ; l'intention d'axe réutilise `Ui2OrderedTabSwipe` (mêmes
///    seuils que `horizontalGesture.ts`, même résolution que
///    `orderedTabSwipe.ts` pour un pager à une page).
struct LeaderboardModalView: View {
    @Environment(\.dismiss) private var dismiss

    /// Onglet ouvert à l'ouverture de la feuille.
    var initialTab: RankingsView.RankingsTab = .subject
    /// Matière classée.
    var subject: String = "Mathématiques"
    /// Masque l'accès au classement XP (coupe de Défis).
    var eloOnly: Bool = false
    /// Masque l'accès aux ligues Elo (coupe d'Entraînement).
    var xpOnly: Bool = false
    /// Ouvre la fiche d'un joueur (`onOpenProfile`).
    var onOpenProfile: ((String) -> Void)? = nil
    /// Ferme toute la fenêtre d'un geste horizontal (`swipeToClose`).
    var swipeToClose: Bool = true

    /// Position horizontale de la page : 0 au repos, `largeur` hors écran.
    @State private var pageX: CGFloat = 0
    /// Largeur de la page, mesurée par `widthReader`.
    @State private var modalWidth: CGFloat = 0
    /// Position au début du glisser courant (`gestureOriginX`).
    @State private var dragOrigin: CGFloat = 0
    /// Un glisser horizontal est en cours.
    @State private var isDragging = false
    /// L'entrée a été lancée.
    @State private var entered = false
    /// Une sortie est en cours (bloque les fermetures concurrentes).
    @State private var closing = false

    /// - Parameters:
    ///   - initialTab: onglet ouvert à l'ouverture de la feuille.
    ///   - subject: matière classée.
    ///   - eloOnly: masque l'accès au classement XP.
    ///   - xpOnly: masque l'accès aux ligues Elo.
    ///   - swipeToClose: ferme la fenêtre d'un geste horizontal.
    init(
        initialTab: RankingsView.RankingsTab = .subject,
        subject: String = "Mathématiques",
        eloOnly: Bool = false,
        xpOnly: Bool = false,
        onOpenProfile: ((String) -> Void)? = nil,
        swipeToClose: Bool = true
    ) {
        self.initialTab = initialTab
        self.subject = subject
        self.eloOnly = eloOnly
        self.xpOnly = xpOnly
        self.onOpenProfile = onOpenProfile
        self.swipeToClose = swipeToClose
    }

    var body: some View {
        RankingsView(
            initialTab: initialTab,
            subject: subject,
            eloOnly: eloOnly,
            xpOnly: xpOnly,
            onOpenProfile: onOpenProfile,
            onBack: { close() }
        )
        .background(Theme.background)
        .background(widthReader)
        .offset(x: pageX)
        .opacity(entered ? 1 : 0)
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(swipeGesture)
        .onPreferenceChange(LeaderboardModalWidthKey.self) { width in
            modalWidth = width
            if !entered, width > 0 { startEntrance(width: width) }
        }
    }

    /// Mesure la largeur de la page sans modifier sa mise en page.
    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: LeaderboardModalWidthKey.self, value: proxy.size.width)
        }
    }

    /// Entrée latérale hors écran → 0 (`ENTRANCE_DURATION_MS`, out cubic).
    private func startEntrance(width: CGFloat) {
        guard !entered else { return }
        entered = true
        pageX = width
        DispatchQueue.main.async {
            withAnimation(LeaderboardModalMotion.entrance) { pageX = 0 }
        }
    }

    /// Sortie latérale 0 → hors écran (`EXIT_DURATION_MS`, in cubic), puis ferme.
    private func close() {
        guard !closing else { return }
        closing = true
        withAnimation(LeaderboardModalMotion.exit) { pageX = max(modalWidth, 1) }
        DispatchQueue.main.asyncAfter(deadline: .now() + LeaderboardModalMotion.exitDuration) {
            dismiss()
        }
    }

    /// Fermeture par glisser : ressort `SWIPE_SPRING_CONFIG` vers hors écran.
    private func swipeClose() {
        guard !closing else { return }
        closing = true
        withAnimation(LeaderboardModalMotion.swipeSpring) { pageX = max(modalWidth, 1) }
        DispatchQueue.main.asyncAfter(deadline: .now() + LeaderboardModalMotion.swipeSettle) {
            dismiss()
        }
    }

    /// Glisser de fermeture (`swipeGesture` de la source) : intention d'axe,
    /// suivi du doigt (`modalDragPosition`), relâchement vers `.back` ou repos.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard swipeToClose else { return }
                if !isDragging {
                    guard case .horizontal = Ui2OrderedTabSwipe.intent(
                        translationX: value.translation.width,
                        translationY: value.translation.height
                    ) else { return }
                    isDragging = true
                    dragOrigin = pageX
                }
                pageX = LeaderboardModalMotion.dragPosition(
                    originX: dragOrigin,
                    translationX: value.translation.width,
                    viewportWidth: max(modalWidth, 1)
                )
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false
                let velocity = value.predictedEndTranslation.width - value.translation.width
                let target = Ui2OrderedTabSwipe.target(
                    pageCount: 1,
                    currentIndex: 0,
                    translationX: value.translation.width,
                    velocityX: velocity
                )
                if target == .back {
                    swipeClose()
                } else {
                    withAnimation(LeaderboardModalMotion.swipeSpring) { pageX = 0 }
                }
            }
    }
}

/// Largeur mesurée de la page, remontée par `widthReader`.
private struct LeaderboardModalWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Durées, courbes, ressort et résistance de `LeaderboardModal.tsx`.
private enum LeaderboardModalMotion {
    /// `ENTRANCE_DURATION_MS`.
    static let entranceDuration: Double = 0.26
    /// `EXIT_DURATION_MS`.
    static let exitDuration: Double = 0.20
    /// Temps d'établissement estimé du ressort de fermeture avant `dismiss`.
    static let swipeSettle: Double = 0.4
    /// `EDGE_RESISTANCE`.
    static let edgeResistance: CGFloat = 0.16

    /// `withTiming(0, 260 ms, Easing.out(Easing.cubic))`. Courbe d'appui
    /// cubique sortante, comme les autres ports Duello (`.timingCurve` ceaser).
    static var entrance: Animation {
        .timingCurve(0.215, 0.61, 0.355, 1, duration: entranceDuration)
    }

    /// `withTiming(largeur, 200 ms, Easing.in(Easing.cubic))`. Courbe d'appui
    /// cubique entrante.
    static var exit: Animation {
        .timingCurve(0.55, 0.055, 0.675, 0.19, duration: exitDuration)
    }

    /// `SWIPE_SPRING_CONFIG` : `damping 33, stiffness 500, mass 0.55` (ζ ≈ 0,995).
    static var swipeSpring: Animation {
        .interpolatingSpring(mass: 0.55, stiffness: 500, damping: 33)
    }

    /// `modalDragPosition` : suit le doigt, résiste hors bornes (`EDGE_RESISTANCE`).
    static func dragPosition(originX: CGFloat, translationX: CGFloat,
                             viewportWidth: CGFloat) -> CGFloat {
        let raw = originX + translationX
        if raw < 0 { return raw * edgeResistance }
        if raw > viewportWidth {
            return viewportWidth + (raw - viewportWidth) * edgeResistance
        }
        return raw
    }
}
