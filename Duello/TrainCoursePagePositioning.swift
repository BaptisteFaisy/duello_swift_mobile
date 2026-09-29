import SwiftUI

// V3 2026-09-29 (complexité) : extension extraite de `TrainCoursePage.swift`.
// Repère de progression de la page « Mon cours » (`placeCourseProgress`,
// `SubjectsScreen.tsx:8207-8243`). Les membres étaient `private` dans
// `TrainCoursePage.swift` ; `private` en Swift est limité au FICHIER, ils sont
// donc élargis à `internal` (corps inchangés).
//
// R07 2026-09-29 (U06#3) : le repère se pose désormais **en faisant défiler le
// cours** face à la ligne rouge du lecteur (`CtdDocumentViewer` reçoit
// `positioning`/`initialPosition`/`onPositionChange`, cf.
// `TrainCoursePageDocument.documentFrame`). La glissière de repli est retirée :
// le lecteur publie la position courante, que `placeProgress()` enregistre.

extension TrainCoursePage {
    /// Bouton de repère + hint d'enregistrement ou position mémorisée
    /// (`placeCourseProgress`, `SubjectsScreen.tsx:8207-8243`) :
    @ViewBuilder
    func positionBlock(document: CtdStoredCourseDocument) -> some View {
        Button {
            placeProgress()
        } label: {
            HStack(spacing: 8) {
                IonIcon(
                    name: positioning ? "checkmark" : "locate-outline",
                    size: 18,
                    color: positioning ? Theme.surface : Theme.ink
                )
                Text(positioning ? "Enregistrer cette position" : "Indiquer où j’en suis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(positioning ? Theme.surface : Theme.ink)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(positioning ? Theme.ink : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: positioning ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(positioning
            ? "Enregistrer la position atteinte dans le cours"
            : "Indiquer où le cours en classe est arrivé")
        positioningHint(document: document)
    }

    /// U06#3 (R07) : la source place le repère **en faisant défiler le cours** et
    /// en le posant face à une ligne rouge (`CourseDocumentViewer` `positioning`
    /// + `onPositionChange`, `SubjectsScreen.tsx:8391-8405`). Le lecteur partagé
    /// (`CtdDocumentViewer`) reçoit désormais ces trois paramètres
    /// (`documentFrame`) : le geste est le défilement, la glissière de repli est
    /// retirée. Le hint ci-dessous ne fait plus qu'expliquer le geste ; la
    /// position courante arrive par `onPositionChange` (`positionDraft`).
    @ViewBuilder
    func positioningHint(document: CtdStoredCourseDocument) -> some View {
        if positioning {
            Text("Fais défiler le cours jusqu’au dernier point vu en classe et place-le face au repère rouge. Le bouton ou le retour enregistrera cette position.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        } else if let progress = document.classProgress {
            Text("Progression du cours enregistrée à \(Int((progress.position * 100).rounded())) %.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// `placeCourseProgress` : premier appui = armer le placement, second appui
    /// = enregistrer la position (bornée 0–1) et poser le statut de cours.
    func placeProgress() {
        guard let current = document else { return }
        if !positioning {
            positionDraft = current.classProgress?.position ?? 0
            positioning = true
            return
        }
        let position = min(1, max(0, positionDraft))
        var updated = current
        updated.classProgress = CtdStoredCourseDocument.ClassProgress(
            position: position,
            updatedAt: TrainChapterFlashcards.now()
        )
        document = updated
        positioning = false
        onCourseStatus?(status(at: position))
        TrainCourseDocument.save(updated, year: programYear, chapterId: chapter.id)
    }

    /// `courseStatusAtPosition` : 0 = À venir, 1 = Vu, entre les deux = En cours.
    func status(at position: Double) -> TrainCourseStatus {
        if position <= 0 { return .notStarted }
        if position >= 1 { return .completed }
        return .inProgress
    }
}
