import SwiftUI

/// Un mois découpé en 42 cases (6 semaines), lundi en tête.
///
/// Reprend le calcul de `HecJourneyCalendarPicker.tsx` :
/// `(new Date(y, m, 1).getDay() + 6) % 7` place le premier jour sur une colonne
/// lundi = 0, et l'en-tête est le libellé `Intl.DateTimeFormat('fr-FR',
/// { month: 'long', year: 'numeric' })`.
struct HecJourneyCalendarMonth {
    let label: String
    let days: [Date?]

    init(month: Date) {
        let calendar = Calendar.current
        let first = HecJourneyDates.startOfMonth(month)
        label = HecJourneyDates.monthLabel(first)

        // `Calendar.component(.weekday:)` compte dimanche = 1 ; la source place
        // lundi en première colonne.
        let weekday = calendar.component(.weekday, from: first)
        let offset = (weekday + 5) % 7
        let dayCount = calendar.range(of: .day, in: .month, for: first)?.count ?? 30

        days = (0..<HecJourneyCalendarCopy.cellCount).map { index in
            let day = index - offset + 1
            guard day >= 1, day <= dayCount else { return nil }
            return calendar.date(byAdding: .day, value: day - 1, to: first)
        }
    }

    /// « Septembre 2026 » : la source demande `textTransform: 'capitalize'` sur
    /// un libellé français en minuscules.
    var title: String {
        guard let first = label.first else { return label }
        return first.uppercased() + label.dropFirst()
    }
}

/// Sélecteur de date de la feuille d'ajout.
///
/// Porté de `src/components/HecJourneyCalendarPicker.tsx` : flèches « Mois
/// précédent » / « Mois suivant », en-tête de semaine « L M M J V S D », dates
/// antérieures à l'inscription désactivées, jour choisi sur fond clair.
struct HecJourneyCalendarView: View {
    /// Premier jour du mois affiché.
    let month: Date
    let selectedDate: Date
    let minimumDate: Date
    let onChangeMonth: (Date) -> Void
    let onSelect: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var grid: HecJourneyCalendarMonth { HecJourneyCalendarMonth(month: month) }

    /// `normalizeHecJourneyDate(minimumDate, minimumDate)`.
    private var minimum: Date { HecJourneyDates.normalize(minimumDate, registeredAt: minimumDate) }

    var body: some View {
        let days = grid.days
        return VStack(spacing: 0) {
            header
            weekdayRow
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(days.indices, id: \.self) { index in
                    dayCell(days[index])
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
    }

    // MARK: En-tête

    private var header: some View {
        HStack(spacing: 0) {
            arrow(systemName: "chevron.left", label: HecJourneyCalendarCopy.previousMonth, offset: -1)
            Text(grid.title)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(HecJourneyPalette.sheetInk)
                .frame(maxWidth: .infinity)
            arrow(systemName: "chevron.right", label: HecJourneyCalendarCopy.nextMonth, offset: 1)
        }
        .frame(height: 46)
    }

    private func arrow(systemName: String, label: String, offset: Int) -> some View {
        Button {
            let current = HecJourneyDates.startOfMonth(month)
            let next = Calendar.current.date(byAdding: .month, value: offset, to: current) ?? current
            onChangeMonth(HecJourneyDates.startOfMonth(next))
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(HecJourneyPalette.sheetInkSoft)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(HecJourneyCalendarCopy.weekdays.indices, id: \.self) { index in
                Text(HecJourneyCalendarCopy.weekdays[index])
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(HecJourneyPalette.sheetInkMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 22)
            }
        }
    }

    // MARK: Cases

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let disabled = day < minimum
            let selected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
            Button {
                onSelect(day)
            } label: {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(dayColor(selected: selected, disabled: disabled))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(selected ? HecJourneyPalette.sheetHighlight : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .accessibilityLabel(HecJourneyCalendarCopy.a11yChooseDay(HecJourneyDates.format(day)))
        } else {
            Color.clear.frame(height: 34)
        }
    }

    private func dayColor(selected: Bool, disabled: Bool) -> Color {
        if selected { return HecJourneyPalette.sheetHighlightInk }
        if disabled { return HecJourneyPalette.sheetInkDisabled }
        return HecJourneyPalette.sheetInkSoft
    }
}
