import SwiftUI

/// Pages de la feuille d'ajout, une par panneau de
/// `src/components/HecJourney.tsx` : grille des types (`typeGrid`), liste des
/// chapitres (`chapterList`), liste des vacances (`holidayList`), choix de la
/// zone (`holidayZonePanel`), confirmation de création
/// (`confirmationPanel`) et confirmation de suppression
/// (`deleteConfirmationPanel`).

// MARK: - Types de blocs

/// `typeGrid` : huit types sur deux colonnes (« width: '50%' », `minHeight`
/// 42, écart 10, icône 17 `#D9D6D1`), « DS » et « CB » gardant leurs
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
                    HStack(spacing: 10) {
                        IonIcon(
                            name: HecJourneyBlocks.iconName(type),
                            size: 17,
                            color: HecJourneyPalette.sheetAccent
                        )
                        Text(HecJourneyBlocks.optionLabel(type))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(HecJourneyPalette.sheetInk)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(HecJourneySheet.PressFillStyle())
                .accessibilityLabel(HecJourneyCopy.a11yAddType(type))
            }
        }
        .padding(8)
    }
}

// MARK: - Chapitres

/// `chapterList` : les chapitres du programme, numérotés, hauteur maximale de
/// 230 points comme la source. `chapterOption` : `minHeight` 52, écart 12,
/// index 22 large, nom 13/700, `add` 17 `#A9A49E`.
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
            leadingWidth: 22,
            trailingIcon: "add",
            trailingSize: 17,
            trailingTint: HecJourneyPalette.sheetInkSubtle,
            titleSize: 13,
            spacing: 12,
            horizontalPadding: 16,
            verticalPadding: 10,
            minHeight: 52,
            action: { flow.selectChapter(chapter) }
        )
        .overlay(alignment: .bottom) {
            HecJourneySheet.Separator(color: HecJourneyPalette.sheetRowSeparator)
        }
        .accessibilityLabel(HecJourneyCopy.a11yAddChapter(chapter.name))
    }
}

// MARK: - Vacances

/// `holidayList` : les six entrées de `HEC_JOURNEY_SCHOOL_HOLIDAYS`
/// (`maxHeight` 260, `holidayOption` : `minHeight` 43, écart 10, icône 16,
/// texte 11/700, chevron 14).
struct HecJourneyAddHolidaysPage: View {
    @ObservedObject var flow: HecJourneyAddFlow

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(HecJourneySchoolHoliday.allCases, id: \.self) { holiday in
                    HecJourneySheet.OptionRow(
                        title: holiday.label,
                        icon: holiday == .toutes ? "albums-outline" : "sunny-outline",
                        iconSize: 16,
                        trailingIcon: "chevron-forward",
                        trailingSize: 14,
                        titleSize: 11,
                        spacing: 10,
                        horizontalPadding: 16,
                        minHeight: 43,
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
        .frame(maxHeight: 260)
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
                        titleColor: HecJourneyPalette.sheetAccent,
                        background: Color.clear,
                        borderColor: HecJourneyPalette.sheetBorderSoft,
                        titleSize: 8,
                        tracking: 0.7,
                        minHeight: 36,
                        horizontalPadding: 0,
                        pressFill: Color.white.opacity(0.08),
                        action: { flow.selectHolidayZone(zone) }
                    )
                    .accessibilityLabel(HecJourneyCopy.a11yChooseZone(zone))
                }
            }
            .padding(.top, 12)
            HecJourneySheet.ActionButton(
                title: HecJourneyCopy.useCustomDate(HecJourneyDates.format(flow.draftDate)),
                titleColor: HecJourneyPalette.sheetInk,
                background: HecJourneyPalette.sheetSoftFill,
                borderColor: Color.clear,
                titleSize: 8,
                tracking: 0.7,
                minHeight: 38,
                icon: "calendar-outline",
                pressFill: Color.white.opacity(0.08),
                action: { flow.selectHolidayZone(nil) }
            )
            .padding(.top, 8)
        }
        .padding(.horizontal, 14)
        .padding(.top, 13)
        .padding(.bottom, 14)
    }
}

// MARK: - Confirmations

/// `deleteConfirmationPanel` : « Supprimer ce bloc neutre ? ».
struct HecJourneyAddDeletePage: View {
    @ObservedObject var flow: HecJourneyAddFlow

    var body: some View {
        VStack(spacing: 0) {
            IonIcon(name: "trash-outline", size: 18, color: HecJourneyPalette.sheetDangerStrong)
                .frame(width: 34, height: 34)
                .background(HecJourneyPalette.sheetDangerSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(HecJourneyCopy.deleteNeutralTitle)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(HecJourneyPalette.sheetStrong)
                .multilineTextAlignment(.center)
                .padding(.top, 5)
            Text(HecJourneyCopy.deleteBlockMessage)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(HecJourneyPalette.sheetInkHint)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
            HecJourneySheet.ActionRow(slots: [
                .init(flex: 0.8, button: HecJourneySheet.ActionButton(
                    title: HecJourneyCopy.cancelButton,
                    titleColor: HecJourneyPalette.sheetInkSubtle,
                    background: Color.clear,
                    borderColor: HecJourneyPalette.sheetBorderSoft,
                    pressFill: Color.white.opacity(0.08),
                    action: { flow.panel = .types }
                )),
                .init(flex: 1.2, button: HecJourneySheet.ActionButton(
                    title: HecJourneyCopy.deleteButton,
                    titleColor: .white,
                    background: HecJourneyPalette.sheetDangerFill,
                    pressOpacity: 0.72,
                    action: { flow.deleteNeutralBlock() }
                )),
            ])
            .padding(.top, 16)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
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
                IonIcon(
                    name: HecJourneyBlocks.iconName(entry.type),
                    size: 18,
                    color: HecJourneyPalette.sheetInk
                )
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
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    /// « MODIFIER » n'apparaît pas pour un chapitre, comme la source.
    @ViewBuilder
    private func actions(for entry: HecJourneyEntry) -> some View {
        if entry.type != .chapter {
            HecJourneySheet.ActionRow(slots: [
                .init(flex: 0.8, button: HecJourneySheet.ActionButton(
                    title: HecJourneyCopy.modifyButton,
                    titleColor: HecJourneyPalette.sheetInkSubtle,
                    background: Color.clear,
                    borderColor: HecJourneyPalette.sheetBorderSoft,
                    pressFill: Color.white.opacity(0.08),
                    action: { flow.back() }
                )),
                .init(flex: 1.2, button: HecJourneySheet.ActionButton(
                    title: HecJourneyCopy.confirmButton,
                    tracking: 0.9,
                    pressOpacity: 0.72,
                    action: { flow.confirmCreation() }
                )),
            ])
            .padding(.top, 16)
        } else {
            HecJourneySheet.ActionRow(slots: [
                .init(flex: 1.2, button: HecJourneySheet.ActionButton(
                    title: HecJourneyCopy.confirmButton,
                    tracking: 0.9,
                    pressOpacity: 0.72,
                    action: { flow.confirmCreation() }
                )),
            ])
            .padding(.top, 16)
        }
    }
}
