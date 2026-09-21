import SwiftUI

/// Pages de la feuille d'ajout, une par panneau de
/// `src/components/HecJourney.tsx` : grille des types (`typeGrid`), liste des
/// chapitres (`chapterList`), liste des vacances (`holidayList`), choix de la
/// zone (`holidayZonePanel`), confirmation de création
/// (`confirmationPanel`) et confirmation de suppression
/// (`deleteConfirmationPanel`).

// MARK: - Types de blocs

/// `typeGrid` : huit types sur deux colonnes, « DS » et « CB » gardant leurs
/// capitales.
struct HecJourneyAddTypesPage: View {
    @ObservedObject var flow: HecJourneyAddFlow

    private let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(HecJourneyBlocks.addable, id: \.self) { type in
                Button {
                    flow.selectType(type)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: HecJourneyBlocks.icon(type))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(HecJourneyPalette.sheetAccent)
                            .frame(width: 20)
                        Text(HecJourneyBlocks.optionLabel(type))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(HecJourneyPalette.sheetInk)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(HecJourneyCopy.a11yAddType(type))
            }
        }
        .padding(8)
    }
}

// MARK: - Chapitres

/// `chapterList` : les chapitres du programme, numérotés, hauteur maximale de
/// 230 points comme la source.
struct HecJourneyAddChaptersPage: View {
    @ObservedObject var flow: HecJourneyAddFlow
    let chapters: [HecJourneyChapter]

    var body: some View {
        Group {
            if chapters.isEmpty {
                // État vide ajouté côté Swift : la source reçoit toujours la
                // liste de chapitres de son parent.
                DuelloEmptyState(
                    icon: "book",
                    title: "Aucun chapitre disponible",
                    message: "Les chapitres du programme s’afficheront ici."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(chapters.indices, id: \.self) { index in
                            row(index: index, chapter: chapters[index])
                        }
                    }
                }
                .frame(maxHeight: 230)
            }
        }
    }

    private func row(index: Int, chapter: HecJourneyChapter) -> some View {
        HecJourneySheet.OptionRow(
            title: chapter.name,
            leading: String(format: "%02d", index + 1),
            trailingIcon: "plus",
            action: { flow.selectChapter(chapter) }
        )
        .overlay(alignment: .bottom) {
            HecJourneySheet.Separator(color: HecJourneyPalette.sheetRowSeparator)
        }
        .accessibilityLabel(HecJourneyCopy.a11yAddChapter(chapter.name))
    }
}

// MARK: - Vacances

/// `holidayList` : les six entrées de `HEC_JOURNEY_SCHOOL_HOLIDAYS`.
struct HecJourneyAddHolidaysPage: View {
    @ObservedObject var flow: HecJourneyAddFlow

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(HecJourneySchoolHoliday.allCases, id: \.self) { holiday in
                    HecJourneySheet.OptionRow(
                        title: holiday.label,
                        icon: holiday == .toutes ? "square.stack" : "sun.max",
                        trailingIcon: "chevron.right",
                        action: {
                            flow.selectedHoliday = holiday
                            flow.panel = .holidayZone
                        }
                    )
                    .overlay(alignment: .bottom) {
                        HecJourneySheet.Separator(color: HecJourneyPalette.sheetRowSeparator)
                    }
                    .accessibilityLabel(HecJourneyCopy.a11yChooseHoliday(holiday.label))
                }
            }
        }
        .frame(maxHeight: 230)
    }
}

/// `holidayZonePanel` : zone scolaire A/B/C, ou la date réglée à la main.
struct HecJourneyAddHolidayZonePage: View {
    @ObservedObject var flow: HecJourneyAddFlow

    var body: some View {
        VStack(spacing: 0) {
            Text(flow.selectedHoliday?.label ?? HecJourneyCopy.panelHolidays)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(HecJourneyPalette.sheetStrong)
            Text(HecJourneyCopy.holidayZoneHint)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(HecJourneyPalette.sheetInkHint)
                .padding(.top, 5)
            HStack(spacing: 7) {
                ForEach(HecJourneySchoolZone.allCases, id: \.self) { zone in
                    HecJourneySheet.ActionButton(
                        title: HecJourneyCopy.zoneButton(zone),
                        filled: false,
                        action: { flow.selectHolidayZone(zone) }
                    )
                    .accessibilityLabel(HecJourneyCopy.a11yChooseZone(zone))
                }
            }
            .padding(.top, 12)
            HecJourneySheet.ActionButton(
                title: HecJourneyCopy.useCustomDate(HecJourneyDates.format(flow.draftDate)),
                filled: false,
                action: { flow.selectHolidayZone(nil) }
            )
            .padding(.top, 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}

// MARK: - Confirmations

/// `deleteConfirmationPanel` : « Supprimer ce bloc neutre ? ».
struct HecJourneyAddDeletePage: View {
    @ObservedObject var flow: HecJourneyAddFlow

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "trash")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HecJourneyPalette.sheetDangerStrong)
                .frame(width: 34, height: 34)
                .background(HecJourneyPalette.sheetDangerSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(HecJourneyCopy.deleteNeutralTitle)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(HecJourneyPalette.sheetStrong)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
            Text(HecJourneyCopy.deleteBlockMessage)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(HecJourneyPalette.sheetInkHint)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
            HStack(spacing: 8) {
                HecJourneySheet.ActionButton(
                    title: HecJourneyCopy.cancelButton,
                    filled: false,
                    action: { flow.panel = .types }
                )
                .accessibilityLabel(HecJourneyCopy.a11yCancelDelete)
                HecJourneySheet.ActionButton(
                    title: HecJourneyCopy.deleteButton,
                    danger: true,
                    action: { flow.deleteNeutralBlock() }
                )
                .accessibilityLabel(HecJourneyCopy.a11yDeleteBlockConfirm)
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

/// `confirmationPanel` : récapitulatif du bloc à créer, puis « MODIFIER » ou
/// « CONFIRMER ». Le récapitulatif couvre aussi le lot de vacances (« 5 BLOCS
/// DE VACANCES », du premier au dernier jour).
struct HecJourneyAddConfirmationPage: View {
    @ObservedObject var flow: HecJourneyAddFlow

    /// `pendingHolidayEntries.length > 1` : plusieurs blocs de vacances.
    private var isHolidayBatch: Bool { flow.pendingHolidayEntries.count > 1 }

    /// Type, titre et date du récapitulatif (`confirmationType`,
    /// `confirmationTitle`, `confirmationDate`).
    private var summary: (type: String, title: String, date: String) {
        guard let entry = flow.pendingEntry else { return ("", "", "") }
        guard isHolidayBatch,
              let first = flow.pendingHolidayEntries.first,
              let last = flow.pendingHolidayEntries.last
        else {
            return (
                HecJourneyBlocks.label(entry.type).uppercased(),
                entry.title,
                HecJourneyDates.format(entry.createdAt)
            )
        }
        return (
            HecJourneyCopy.holidayBlockCount(flow.pendingHolidayEntries.count),
            HecJourneyCopy.allHolidaysBlockTitle,
            "\(HecJourneyDates.format(first.createdAt)) – \(HecJourneyDates.format(last.createdAt))"
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if let entry = flow.pendingEntry {
                Image(systemName: HecJourneyBlocks.icon(entry.type))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(HecJourneyPalette.sheetInk)
                    .frame(width: 34, height: 34)
                    .background(HecJourneyPalette.sheetIconSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(summary.type)
                    .font(.system(size: 8, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(HecJourneyPalette.sheetInkHint)
                    .padding(.top, 10)
                Text(summary.title)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(HecJourneyPalette.sheetStrong)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.top, 5)
                Text(summary.date)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(HecJourneyPalette.sheetInkFaint)
                    .padding(.top, 5)
                actions(for: entry)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    /// « MODIFIER » n'apparaît pas pour un chapitre, comme la source.
    private func actions(for entry: HecJourneyEntry) -> some View {
        HStack(spacing: 8) {
            if entry.type != .chapter {
                HecJourneySheet.ActionButton(
                    title: HecJourneyCopy.modifyButton,
                    filled: false,
                    action: { flow.back() }
                )
            }
            HecJourneySheet.ActionButton(
                title: HecJourneyCopy.confirmButton,
                action: { flow.confirmCreation() }
            )
        }
        .padding(.top, 16)
    }
}
