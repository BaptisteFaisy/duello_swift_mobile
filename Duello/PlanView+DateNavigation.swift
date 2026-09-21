//
//  PlanView+DateNavigation.swift
//  Duello
//
//  Écran « Plan » — navigation dans le programme et champ de date (extension de PlanView).
//
import Foundation
import SwiftUI

extension PlanView {

    // MARK: Navigation interne

    /// `selectDay` (lignes 107-113) : le champ de date suit le jour affiché.
    private func goToDay(_ offset: Int) {
        selectedDayOffset = max(0, min(max(0, days.count - 1), offset))
    }

    private func goToToday() {
        dateInput = PlanDateEngine.longDate(day(for: 0).date)
        dateError = nil
        goToDay(0)
    }

    private func startEditingDate() {
        dateInput = PlanDateEngine.inputDate(selectedDay.date)
        isEditingDate = true
    }

    /// `handleDateInput` (lignes 120-128) : masque la saisie, et dès qu'une date
    /// du programme est reconnue, y conduit.
    private func handleDateInput(_ value: String) {
        guard isEditingDate else { return }
        let masked = PlanDateEngine.maskInput(value)
        if masked != value {
            dateInput = masked
            return
        }
        if let target = PlanDateEngine.findDay(for: masked, in: days) {
            dateError = nil
            goToDay(target.dayOffset)
        }
    }

    /// `submitDateInput` (lignes 136-150) : seule la validation explicite signale
    /// une saisie inutilisable.
    private func submitDateInput() {
        isEditingDate = false
        if let target = PlanDateEngine.findDay(for: dateInput, in: days) {
            dateError = nil
            dateInput = PlanDateEngine.longDate(target.date)
            goToDay(target.dayOffset)
            return
        }
        let reference = days.first?.date ?? Date()
        dateError = PlanDateEngine.parseDate(dateInput, reference: reference) == nil
            ? "Format attendu : JJ/MM/AAAA."
            : "Cette date est en dehors de ton programme."
        dateInput = PlanDateEngine.longDate(selectedDay.date)
    }
}
