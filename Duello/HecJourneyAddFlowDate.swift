import Foundation

/// Date proposée par la feuille d'ajout : flèches du jour, calendrier et choix
/// d'une date de la grille.
///
/// Porté de `src/components/HecJourney.tsx` — `shiftDraftDate`,
/// `handleSelectCalendarDate` et l'ouverture du calendrier
/// (`setCalendarOpen`). Séparé de `HecJourneyAddFlow` pour que la machine à
/// états de la feuille et le réglage de la date restent deux responsabilités
/// distinctes.
extension HecJourneyAddFlow {

    /// `shiftDraftDate` : un jour en avant ou en arrière, jamais avant
    /// l'inscription.
    func shiftDraftDate(by days: Int) {
        let shifted = draftDate.addingTimeInterval(Double(days) * HecJourneyDates.dayInterval)
        draftDate = HecJourneyDates.normalize(shifted, registeredAt: registeredAt)
    }

    /// `handleSelectCalendarDate`.
    func selectCalendarDate(_ date: Date) {
        draftDate = HecJourneyDates.normalize(date, registeredAt: registeredAt)
        calendarOpen = false
    }

    /// Bouton calendrier : ouvre ou referme la grille.
    func toggleCalendar() {
        calendarOpen.toggle()
    }
}
