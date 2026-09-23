//
//  SubjCourseProgressLegend.swift
//  Duello
//
//  Lot 9-B « légende de progression du cours » (préfixe `Subj`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/screens/SubjectsScreen.tsx (`COURSE_STATUS_ICONS`,
//      `COURSE_STATUS_COLORS`, `COURSE_STATUS_LABELS`, `CourseProgressLegend`,
//      styles `courseProgressHint*`, `courseLegendClose`, `courseStatusBadge`,
//      `chapterRow`, `chapterMain`, `chapterTitle`, `legend*`)
//
//  Les icônes, les teintes et les libellés des trois statuts ne sont pas
//  redéfinis ici : ils viennent de `TrainCourseStatus` (déjà porté dans
//  `TrainCourseStatus.swift`). Ce fichier ne porte que la présentation.
//  Cible iOS 16.
//
import SwiftUI

/// Libellé d'accessibilité de l'encart explicatif (repris mot pour mot).
private let subjCourseHintAccessibilityLabel =
    "Appuie sur le rond à gauche du nom du chapitre pour indiquer le statut du cours."

/// Libellé du bouton de fermeture de l'encart explicatif.
private let subjCourseLegendDismissLabel = "Masquer l’explication du statut du cours"

/// Titre de la légende statique (`styles.legendTitle` → « Statut cours »).
private let subjCourseLegendTitle = "Statut cours"

/// Nom du chapitre montré dans l'encart explicatif (maquette, pas de données).
private let subjCourseHintChapterTitle = "Nom du chapitre"

/// `CourseProgressLegend` de `src/screens/SubjectsScreen.tsx`.
///
/// Deux usages, exactement comme dans l'écran Expo :
/// - **sans `onDismiss`** : rappel statique des trois statuts de cours, affiché
///   sous la liste des chapitres (`{courseLegendVisible && <CourseProgressLegend />}`) ;
/// - **avec `onDismiss`** : encart explicatif animé, montré en tête de matière la
///   première fois. Une main dessinée vient appuyer sur le rond de statut, qui
///   défile « à venir → en cours → vu → à venir » (450 ms, puis 520 ms et 1 s
///   entre les étapes), et l'encart se referme au bouton.
///
/// `isDownloadedDesktopApp()` (`src/utils/downloadedDesktopApp.ts`) renvoie
/// toujours `false` sur mobile : la branche « application de bureau » de la
/// légende statique ne rend jamais rien et n'a donc pas été portée.
struct SubjCourseProgressLegend: View {
    /// Fourni quand l'encart explicatif doit pouvoir être masqué.
    var onDismiss: (() -> Void)? = nil

    /// Statut démontré par l'encart animé. Le statut réel d'un chapitre vit
    /// dans `TrainCourseStatusStore` ; la démonstration est purement visuelle.
    @State private var demoStatus: TrainCourseStatus = .notStarted

    /// Appui de la main dessinée (équivalent de `demoHandPress`).
    @State private var handPressed = false

    /// « Réduire les animations » : la main ne bouge plus, le statut défile.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let dismiss = onDismiss {
            hintCard(onDismiss: dismiss)
                .task { await runDemo() }
        } else {
            staticLegend
        }
    }

    // MARK: - Encart explicatif animé

    /// Encart bordé, refermable, montré une seule fois en tête de matière.
    ///
    /// La carte est dessinée à la main plutôt qu'avec `.duelloCard()` : le
    /// rappel Expo a des marges internes propres (11 px) et un bas plus haut
    /// (30 px) que le rembourrage uniforme de 16 px du modificateur partagé.
    private func hintCard(onDismiss: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Statut du cours : \(demoStatus.label)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, 11)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

            chapterRow
        }
        .padding(.top, 11)
        .padding(.bottom, 8)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) { closeButton(onDismiss: onDismiss) }
        .padding(.bottom, 12)
    }

    /// Ligne de chapitre de la maquette : rond de statut, titre, main.
    private var chapterRow: some View {
        HStack(spacing: 10) {
            statusBadge
            Text(subjCourseHintChapterTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.top, 8)
        .padding(.bottom, 30)
        .overlay(alignment: .topLeading) {
            // `courseProgressHintHand` : `position: 'absolute', left: 15,
            // top: 41` dans `SubjectsScreen.tsx`. Le repère est la ligne de
            // chapitre entière (paddingHorizontal 11, paddingTop 8) : la main
            // tombe donc **sous** le rond de statut (8 + 32 = 40), centrée sur
            // son axe (11 + 4 = 15), et non par-dessus.
            hand.padding(.leading, 15).padding(.top, 41)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(subjCourseHintAccessibilityLabel)
    }

    /// Rond de statut (`styles.courseStatusBadge`, 32 × 32, fond transparent).
    private var statusBadge: some View {
        Image(systemName: demoStatus.icon)
            .font(.system(size: 20))
            .foregroundStyle(demoStatus.tint)
            .frame(width: 32, height: 32)
    }

    /// Main dessinée (`hand-left-outline`), qui « appuie » sur le rond.
    private var hand: some View {
        Image(systemName: "hand.point.left")
            .font(.system(size: 22))
            .foregroundStyle(Theme.inkSoft)
            .frame(width: 24, height: 24)
            .offset(y: handPressed ? -7 : 0)
            .scaleEffect(handPressed ? 0.88 : 1)
    }

    /// Croix de fermeture, posée en absolu à 8 px des coins hauts et droits.
    private func closeButton(onDismiss: @escaping () -> Void) -> some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 20))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .padding(.trailing, 8)
        .accessibilityLabel(subjCourseLegendDismissLabel)
    }

    // MARK: - Légende statique

    /// Rappel « Statut cours » sous la liste des chapitres.
    private var staticLegend: some View {
        VStack(alignment: .leading, spacing: 0) {
            legendTitle
            HStack(spacing: 8) {
                ForEach(TrainCourseStatus.allCases, id: \.self) { status in
                    legendItem(status)
                }
            }
            .padding(.top, 8)
        }
        .padding(.top, 16)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
        .padding(.top, 16)
    }

    /// Titre du rappel statique : 10 pt noir, capitales, `tracking` 0,5
    /// (`styles.legendTitle` de `SubjectsScreen.tsx`) — plus petit que le titre
    /// de section partagé (`DuelloSectionHeader`, 13 pt), que ce rappel
    /// n'emploie donc pas.
    private var legendTitle: some View {
        Text(subjCourseLegendTitle)
            .font(.system(size: 10, weight: .black))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Pastille de légende : petit rond de statut + libellé.
    private func legendItem(_ status: TrainCourseStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 12))
                .foregroundStyle(status.tint)
            Text(status.label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Démonstration animée

    /// Boucle de démonstration : appui → statut suivant → relâchement, puis
    /// retour à « à venir ». Les délais reprennent ceux de l'effet Expo
    /// (450 ms au départ, 520 ms entre les étapes, 1 s avant la remise à zéro).
    private func runDemo() async {
        while !Task.isCancelled {
            await pause(0.45)
            await tapStep(.inProgress)
            await pause(0.52)
            await tapStep(.completed)
            await pause(1.0)
            demoStatus = .notStarted
            await pause(0.65)
        }
    }

    /// Un appui complet : la main descend (175 ms), le statut change, elle
    /// remonte (175 ms).
    private func tapStep(_ next: TrainCourseStatus) async {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.175)) {
            handPressed = true
        }
        await pause(0.175)
        demoStatus = next
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.175)) {
            handPressed = false
        }
        await pause(0.175)
    }

    /// Attente annulable (l'annulation est gérée par `Task.isCancelled`).
    private func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
