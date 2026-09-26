import SwiftUI

/// Feuille « NOUVEAU BLOC » du parcours : en-tête, ligne de date et pages.
///
/// Porté de `src/components/HecJourney.tsx` — `addPanelHeader`, `panelEyebrow`,
/// `datePickerRow`, la grille `typeGrid`, la liste `chapterList`, la liste
/// `holidayList`, le panneau `holidayZonePanel` et les panneaux
/// `confirmationPanel` / `deleteConfirmationPanel`. Les libellés sont ceux de
/// la source, rassemblés dans `HecJourneyCopy`.
///
/// L'état de la feuille vit dans `HecJourneyAddFlow` ; cette vue ne fait que
/// projeter l'état et relayer les gestes.
struct HecJourneyAddPanelView: View {
    @ObservedObject var flow: HecJourneyAddFlow
    let chapters: [HecJourneyChapter]
    let registeredAt: Date

    /// Mois affiché par la grille, recalé sur la date du bloc à chaque
    /// ouverture du calendrier (`setCalendarMonth(startOfMonth(draftDate))`).
    @State private var calendarMonth: Date = Date()

    private var panel: HecJourneyAddFlow.Panel { flow.panel ?? .types }

    var body: some View {
        VStack(spacing: 0) {
            header
            if showsDateRow {
                dateRow
            }
            if flow.calendarOpen {
                HecJourneyCalendarView(
                    month: calendarMonth,
                    selectedDate: flow.draftDate,
                    minimumDate: registeredAt,
                    onChangeMonth: { calendarMonth = $0 },
                    onSelect: { flow.selectCalendarDate($0) }
                )
            } else {
                page
            }
        }
        .background(HecJourneyPalette.sheet)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(HecJourneyPalette.sheetBorder, lineWidth: 1)
        )
        .onChange(of: flow.calendarOpen) { isOpen in
            if isOpen {
                calendarMonth = HecJourneyDates.startOfMonth(flow.draftDate)
            }
        }
    }

    // MARK: En-tête

    private var header: some View {
        ZStack {
            Text(panelTitle)
                .font(.system(size: 8, weight: .black))
                .tracking(1.4)
                .foregroundStyle(HecJourneyPalette.sheetInkFaint)
            HStack(spacing: 0) {
                if panel != .types {
                    HecJourneySheet.IconButton(
                        systemName: "chevron.left",
                        label: HecJourneyCopy.a11yBackStep,
                        size: 15,
                        tint: HecJourneyPalette.sheetInkSoft,
                        frame: 30,
                        action: { flow.back() }
                    )
                }
                Spacer(minLength: 0)
                if panel == .types, flow.targetNeutralId != nil {
                    HecJourneySheet.IconButton(
                        systemName: "trash",
                        label: HecJourneyCopy.a11yDeleteNeutral,
                        size: 15,
                        tint: HecJourneyPalette.sheetDanger,
                        frame: 30,
                        action: { flow.requestNeutralDeletion() }
                    )
                }
            }
            .padding(.horizontal, 7)
        }
        .frame(minHeight: 34)
        .overlay(alignment: .bottom) {
            HecJourneySheet.Separator()
        }
    }

    /// `panelEyebrow` : le titre dépend du panneau, du bloc visé et du nombre
    /// de blocs de vacances préparés.
    private var panelTitle: String {
        switch panel {
        case .chapters:
            return HecJourneyCopy.panelChapters
        case .holidays:
            return HecJourneyCopy.panelHolidays
        case .holidayZone:
            return HecJourneyCopy.panelHolidayZone
        case .deleteConfirmation:
            return HecJourneyCopy.panelDeleteConfirmation
        case .confirmation:
            return flow.pendingHolidayEntries.count > 1
                ? HecJourneyCopy.panelConfirmationPlural
                : HecJourneyCopy.panelConfirmation
        case .types:
            return flow.targetNeutralId != nil
                ? HecJourneyCopy.panelTypesForBlock
                : HecJourneyCopy.panelTypes
        }
    }

    /// La ligne de date accompagne les trois premiers panneaux.
    private var showsDateRow: Bool {
        panel == .types || panel == .chapters || panel == .holidayZone
    }

    // MARK: Ligne de date

    private var dateRow: some View {
        HStack(spacing: 0) {
            HecJourneySheet.IconButton(
                systemName: "chevron.left",
                label: HecJourneyCopy.a11yPreviousDay,
                size: 17,
                tint: HecJourneyPalette.sheetInkSoft,
                frame: 34,
                action: { flow.shiftDraftDate(by: -1) }
            )
            VStack(spacing: 0) {
                Text(HecJourneyCopy.dateRowLabel)
                    .font(.system(size: 7, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(HecJourneyPalette.sheetInkMuted)
                Text(HecJourneyDates.format(flow.draftDate))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(HecJourneyPalette.sheetInk)
            }
            .frame(maxWidth: .infinity)
            HecJourneySheet.IconButton(
                systemName: "calendar",
                label: HecJourneyCopy.a11yOpenCalendar,
                size: 17,
                tint: HecJourneyPalette.sheetInkSoft,
                frame: 34,
                action: { flow.toggleCalendar() }
            )
            HecJourneySheet.IconButton(
                systemName: "chevron.right",
                label: HecJourneyCopy.a11yNextDay,
                size: 17,
                tint: HecJourneyPalette.sheetInkSoft,
                frame: 34,
                action: { flow.shiftDraftDate(by: 1) }
            )
        }
        .frame(minHeight: 48)
        .overlay(alignment: .bottom) {
            HecJourneySheet.Separator(color: HecJourneyPalette.sheetSeparatorSoft)
        }
    }

    // MARK: Pages

    @ViewBuilder
    private var page: some View {
        switch panel {
        case .types:
            HecJourneyAddTypesPage(flow: flow)
        case .chapters:
            HecJourneyAddChaptersPage(flow: flow, chapters: chapters)
        case .holidays:
            HecJourneyAddHolidaysPage(flow: flow)
        case .holidayZone:
            HecJourneyAddHolidayZonePage(flow: flow)
        case .deleteConfirmation:
            HecJourneyAddDeletePage(flow: flow)
        case .confirmation:
            HecJourneyAddConfirmationPage(flow: flow)
        }
    }
}
