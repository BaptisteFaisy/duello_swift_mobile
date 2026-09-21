import Foundation

/// Construction de la frise affichée : les entrées persistées, plus les bornes
/// fixes du parcours (inscription, vacances d'été, blason d'admission).
///
/// Porté du `blocks` de `src/components/HecJourney.tsx` : chaque chapitre
/// reprend le statut de cours du catalogue (`courseStatus`, servi ici par
/// `TrainCourseStatusStore`), le bloc d'inscription n'apparaît que dans l'année
/// où l'élève a commencé son parcours (`startsHere`), la 1re année se referme
/// sur les vacances d'été (`SUMMER_BREAK_BLOCK_ID`) et la 2e année sur le
/// blason de l'école d'admission (`ADMISSION_BLOCK_ID`, dont le titre est le nom
/// de l'école et la date la fin de l'année scolaire plus une semaine).
enum HecJourneySceneBuilder {

    /// Statut de cours d'un chapitre, fourni par le magasin partagé avec le
    /// catalogue d'entraînement.
    typealias CourseStatusProvider = (String) -> TrainCourseStatus

    /// Les blocs de la frise, dans l'ordre de la source.
    static func blocks(
        entries: [HecJourneyEntry],
        admission: HecJourneyAdmission?,
        programYear: Int,
        startingProgramYear: Int,
        registeredAt: Date,
        timelineEndDate: Date?,
        courseStatus: CourseStatusProvider
    ) -> [HecJourneySceneBlock] {
        let yearEntries = entries.map { entry in
            HecJourneySceneBlock(
                id: entry.id,
                type: .block(entry.type),
                title: entry.title,
                createdAt: entry.createdAt,
                courseStatus: entry.chapterId.map(courseStatus) ?? .notStarted,
                chapterId: entry.chapterId
            )
        }
        let registration = registrationBlock(registeredAt: registeredAt)
        let summerBreak = summerBreakBlock(registeredAt: registeredAt)
        let startsHere = programYear == startingProgramYear

        if programYear == 1 {
            return (startsHere ? [registration] : []) + yearEntries + [summerBreak]
        }
        return (startsHere ? [registration] : [summerBreak])
            + yearEntries
            + [admissionBlock(admission: admission, registeredAt: registeredAt, timelineEndDate: timelineEndDate)]
    }

    /// Positions de la frise : les jalons principaux portent la frise, les
    /// repères latéraux s'intercalent, et la 2e année garde sa position finale
    /// ancrée au bout (`hecJourneyScenePositions`).
    static func positions(blocks: [HecJourneySceneBlock], programYear: Int) -> [Double] {
        HecJourneyLayout.scenePositions(
            blocks: blocks,
            maximumBlockGap: programYear == 2
                ? HecJourneyTimelineConstants.secondYearMaximumBlockGap
                : .infinity,
            finalPosition: programYear == 2
                ? HecJourneyTimelineConstants.secondYearFinalPosition
                : nil
        )
    }

    /// La première étape du parcours, toujours terminée.
    private static func registrationBlock(registeredAt: Date) -> HecJourneySceneBlock {
        HecJourneySceneBlock(
            id: HecJourneyTimelineConstants.registrationBlockId,
            type: .registration,
            title: HecJourneySceneBlockType.registration.label,
            createdAt: registeredAt,
            courseStatus: .completed
        )
    }

    /// Les vacances d'été qui séparent les deux frises.
    private static func summerBreakBlock(registeredAt: Date) -> HecJourneySceneBlock {
        HecJourneySceneBlock(
            id: HecJourneyTimelineConstants.summerBreakBlockId,
            type: .block(.holiday),
            title: "Vacances d’été",
            createdAt: HecJourneyDates.summerBreakDate(registeredAt: registeredAt),
            courseStatus: .notStarted
        )
    }

    /// Le blason final : nom, libellé et couleur de l'école retenue, ou HEC
    /// Paris par défaut.
    private static func admissionBlock(
        admission: HecJourneyAdmission?,
        registeredAt: Date,
        timelineEndDate: Date?
    ) -> HecJourneySceneBlock {
        let crest = HecJourneyAdmissionCodec.crest(for: admission)
        let end = timelineEndDate ?? HecJourneyDates.secondYearEndDate(registeredAt: registeredAt)
        return HecJourneySceneBlock(
            id: HecJourneyTimelineConstants.admissionBlockId,
            type: .admission,
            title: crest.schoolName,
            createdAt: end.addingTimeInterval(7 * HecJourneyDates.dayInterval),
            courseStatus: admission == nil ? .notStarted : .completed,
            crestLabel: crest.crestLabel,
            crestColorHex: crest.colorHex,
            crestSchoolId: crest.schoolId
        )
    }
}
