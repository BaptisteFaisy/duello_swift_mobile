//
//  SubjChapterRows.swift
//  Duello
//
//  Lot 9-H « lignes de chapitre, étiquettes et barre de progression »
//  (préfixe `Subj`).
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx
//        · lignes 3408-3433 : `ChapterRowContainer`
//        · lignes 3435-3541 : `ChapterRow` (statut de cours, résumé de mode,
//          barre d'avancement, chevron)
//        · lignes 3543-3607 : `CourseChapterRow`
//        · lignes 3510-3533 : cascade du résumé de chapitre
//        · styles `chapterRow`, `chapterReturnHighlight`, `courseStatusBadge`,
//          `chapterMain`, `chapterTitle`, `chapterTitleDone`,
//          `chapterSummary`, `chapterSummaryStrong`,
//          `chapterProgressAccessory`, `chapterProgressBar`
//
//  Réutilisés, jamais redéfinis : `TrainCourseStatus` (icône, teinte, libellé),
//  `TrainChapterSummary` (`progressTotal(kind:)`), `SubjModeCopy`
//  (`availability` / `success`), `TrainCopy.solutions`, `SubjProgressBar`,
//  `SubjReturnHighlightBackground`, `SubjCourseProgress`.
//
//  Écart assumé avec `TrainChapterRow` (déjà porté, version simplifiée avec
//  dépliage sur place) : cette ligne-ci garde le comportement de la source —
//  appui sur le rond pour le statut, appui sur la ligne pour ouvrir la liste,
//  chevron fixe à droite, résumé accordé au mode et libellé d'accessibilité
//  nommant le mode. La source ne duplique pas les deux : `TrainChapterRow` sert
//  le catalogue, `SubjChapterRow` sert la liste de chapitres d'une matière.
//  Cible iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Fond transitoire et gabarit communs aux lignes de chapitre
/// (`ChapterRowContainer`).
///
/// Le calque laisse toute la ligne interactive et s'efface après le retour à la
/// liste (`SubjReturnHighlightBackground`).
struct SubjChapterRowContainer<Content: View>: View {
    let highlighted: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            SubjReturnHighlightBackground(
                highlighted: highlighted,
                cornerRadius: Theme.radiusMedium
            )
            HStack(spacing: 10) {
                content()
            }
            .padding(.vertical, 10)
            .padding(.trailing, 12)
        }
        .padding(.top, 8)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }
}

/// Texte du résumé d'une ligne de chapitre, et son niveau d'encre.
struct SubjChapterRowSummary: Equatable {
    let text: String
    /// Vrai quand le chapitre pourvu annonce ses sujets : encre pleine
    /// (`chapterSummaryStrong`) plutôt que gris clair (`chapterSummary`).
    let isStrong: Bool

    /// Port de la cascade des lignes 3510-3533.
    ///
    /// Le dénominateur du compteur de réussites est celui du mode
    /// (`chapterModeProgressTotal` : les colles comptent aussi les sujets
    /// seulement catalogués), tandis que la part « corrigés » et la part sans
    /// nom restent sur les sujets réellement servis.
    static func make(
        subjectId: String,
        mode: SubjChapterTrainingMode,
        summary: TrainChapterSummary
    ) -> SubjChapterRowSummary {
        let progressTotal = summary.progressTotal(kind: mode.kind)

        guard progressTotal > 0 else {
            if let catalogued = summary.catalogued {
                return SubjChapterRowSummary(
                    text: SubjModeCopy.availability(mode, count: catalogued),
                    isStrong: false
                )
            }
            return SubjChapterRowSummary(text: "Aucun sujet disponible", isStrong: false)
        }

        // Les maths en exercices et les colles annoncent directement le
        // compteur de réussites ; les autres modes détaillent d'abord ce que le
        // chapitre contient.
        let showsSuccessOnly =
            (subjectId == SubjSubjectRules.mathsSubjectId && mode == .exercices)
            || mode == .colles
        if showsSuccessOnly {
            return SubjChapterRowSummary(
                text: SubjModeCopy.success(
                    mode,
                    succeeded: summary.succeeded,
                    available: progressTotal
                ),
                isStrong: true
            )
        }

        var text = SubjModeCopy.availability(mode, count: summary.available)
        if summary.withSolution > 0 {
            text += " · \(TrainCopy.solutions(count: summary.withSolution))"
        }
        text += " · " + SubjModeCopy.success(
            mode,
            succeeded: summary.succeeded,
            available: summary.available,
            withNoun: false
        )
        return SubjChapterRowSummary(text: text, isStrong: true)
    }
}

/// Une ligne de chapitre : statut du cours et avancement du mode ouvert
/// (`ChapterRow`).
struct SubjChapterRow: View {
    let subjectId: String
    let chapter: SubjChapter
    let mode: SubjChapterTrainingMode
    let summary: TrainChapterSummary
    var isReturnHighlighted: Bool = false
    let onToggleCourseStatus: () -> Void
    let onOpen: () -> Void

    /// Dénominateur d'avancement ; 0 masque la barre (`progressTotal > 0`).
    private var progressTotal: Int { summary.progressTotal(kind: mode.kind) }

    private var summaryText: SubjChapterRowSummary {
        SubjChapterRowSummary.make(subjectId: subjectId, mode: mode, summary: summary)
    }

    var body: some View {
        SubjChapterRowContainer(highlighted: isReturnHighlighted) {
            statusButton
            mainButton
            accessory
        }
    }

    /// Rond de statut : chaque appui fait avancer le cycle à venir → en cours →
    /// vu → à venir.
    private var statusButton: some View {
        Button(action: onToggleCourseStatus) {
            Image(systemName: chapter.courseStatus.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(chapter.courseStatus.tint)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Statut cours — \(chapter.name)")
        .accessibilityValue(chapter.courseStatus.label)
    }

    /// L'appui se voit immédiatement : la liste du chapitre met quelques images
    /// à se monter, et sans retour visuel l'appui semble ignoré.
    private var mainButton: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.name)
                    .font(.system(size: 14, weight: titleWeight))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                if progressTotal > 0 {
                    SubjProgressBar(
                        fraction: Double(summary.succeeded) / Double(progressTotal),
                        compact: true
                    )
                }
                Text(summaryText.text)
                    .font(.system(size: 11, weight: summaryText.isStrong ? .bold : .semibold))
                    .foregroundStyle(summaryText.isStrong ? Theme.inkSoft : Theme.inkFaint)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ouvrir les \(mode.label(lowercase: true)) — \(chapter.name)")
    }

    /// Un chapitre vu passe en gras (`chapterTitleDone`).
    private var titleWeight: Font.Weight {
        chapter.courseStatus == .completed ? .bold : .semibold
    }

    private var accessory: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Theme.inkFaint)
            .accessibilityHidden(true)
    }
}

/// Vue Cours : le chapitre sert directement à mettre à jour son avancement
/// (`CourseChapterRow`).
///
/// La barre montre la part lue du cours (`SubjCourseProgress.fraction`), pas un
/// compteur de sujets ; il n'y a donc ni résumé ni chevron, l'appui sur la ligne
/// ouvrant le cours du chapitre.
struct SubjCourseChapterRow: View {
    let chapter: SubjChapter
    /// Repère placé dans le cours (`coursePosition`), absent tant qu'aucun
    /// document n'a été importé.
    var coursePosition: Double?
    var hasCourseDocument: Bool = false
    var isReturnHighlighted: Bool = false
    let onToggleCourseStatus: () -> Void
    let onOpen: () -> Void

    private var fraction: Double {
        SubjCourseProgress.fraction(
            position: coursePosition,
            status: chapter.courseStatus,
            hasCourseDocument: hasCourseDocument
        )
    }

    var body: some View {
        SubjChapterRowContainer(highlighted: isReturnHighlighted) {
            statusButton
            mainButton
        }
    }

    private var statusButton: some View {
        Button(action: onToggleCourseStatus) {
            Image(systemName: chapter.courseStatus.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(chapter.courseStatus.tint)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Statut cours — \(chapter.name)")
    }

    private var mainButton: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.name)
                    .font(.system(
                        size: 14,
                        weight: chapter.courseStatus == .completed ? .bold : .semibold
                    ))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                SubjProgressBar(fraction: fraction, compact: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ouvrir le cours du chapitre — \(chapter.name)")
    }
}
