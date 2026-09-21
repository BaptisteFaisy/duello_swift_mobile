//
//  ScheduleEditorView.swift
//  Duello
//
//  Réglages annexes — éditeur d'horaires de cours.
//
//  Source Expo portée (lecture seule) :
//   • expo_ref/src/components/ScheduleEditor.tsx — composant `ScheduleEditor`
//
//  Le modèle de créneau (`ClassSlot` de la source) est déjà porté par le lot
//  « Plan » sous le nom `PlanScheduleSlot` (`PlanModels.swift`) : il est
//  réutilisé tel quel, jamais redéclaré ici. Seuls le catalogue d'interface
//  (jours, matières, valeurs par défaut) et les vues sont propres à ce fichier.
//
//  Écarts assumés, faute d'équivalent natif :
//   • la source empile un `Modal` `pageSheet` et réserve les marges Android ;
//     ici le contenu est une vue nue, destinée à être présentée en `.sheet` par
//     l'écran hôte — iOS n'a pas de barre système à contourner comme Android ;
//   • l'auto-défilement du clavier (`keepMessageVisible`) n'est pas repris :
//     `ScrollView` gère déjà l'insertion du clavier sur iOS.
//

import SwiftUI

// MARK: - Catalogue de l'éditeur

/// Jours et matières de l'éditeur, mot pour mot de la source (`DAYS`,
/// `SUBJECTS` et valeurs par défaut de `addSlot`).
enum ExtraScheduleCatalog {
    /// `DAYS` : six jours ouvrés, dans l'ordre de la source.
    static let days: [String] = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"]

    /// `SUBJECTS` : treize matières, dans l'ordre de la source.
    static let subjects: [String] = [
        "Mathématiques", "Physique", "Chimie", "Français", "Philosophie",
        "Anglais", "LV2", "Histoire", "Géographie", "Informatique",
        "TIPE", "Sport", "Autre",
    ]

    /// Valeurs du créneau créé par « Ajouter » (`addSlot`).
    static let defaultStart = "08:00"
    static let defaultEnd = "10:00"
    static let defaultSubject = "Mathématiques"

    /// Jour sélectionné à l'ouverture (`useState('Lundi')`).
    static var firstDay: String { days[0] }

    /// `id: \`slot-${Date.now()}\`` de la source (millisecondes epoch).
    static func newSlotId() -> String {
        "slot-\(Int(Date().timeIntervalSince1970 * 1000))"
    }
}

// MARK: - Éditeur

/// Édition des créneaux d'un emploi du temps : onglets par jour, création,
/// modification et suppression, puis validation en bloc.
///
/// Contrat aligné sur `ScheduleEditor` : l'écran reçoit les créneaux courants,
/// rend une copie validée via `onSave` et referme via `onClose`. Une fermeture
/// sans validation restitue la copie d'origine (`handleClose`).
struct ScheduleEditorView: View {
    let schedule: [PlanScheduleSlot]
    let onSave: ([PlanScheduleSlot]) -> Void
    let onClose: () -> Void

    @State private var localSchedule: [PlanScheduleSlot]
    @State private var selectedDay: String

    init(
        schedule: [PlanScheduleSlot],
        onSave: @escaping ([PlanScheduleSlot]) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.schedule = schedule
        self.onSave = onSave
        self.onClose = onClose
        _localSchedule = State(initialValue: schedule)
        _selectedDay = State(initialValue: ExtraScheduleCatalog.firstDay)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ExtraScheduleInfoCard()
                    dayTabs
                    slotsSection
                }
                .padding(.bottom, 32)
            }
        }
        .background(Theme.background)
    }

    // MARK: En-tête

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: handleClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer")

            Spacer(minLength: 0)

            Text("Mes horaires de cours")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Theme.ink)

            Spacer(minLength: 0)

            Button(action: handleSave) {
                Text("Valider")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.surface)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Valider les horaires")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    // MARK: Onglets de jour

    private var dayTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ExtraScheduleCatalog.days, id: \.self) { day in
                    ExtraScheduleDayTab(
                        day: day,
                        count: daySlots(day).count,
                        selected: day == selectedDay
                    ) {
                        selectedDay = day
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 16)
    }

    // MARK: Créneaux du jour

    private var slotsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDay)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                addButton
            }
            .padding(.horizontal, 20)

            slotsList
        }
    }

    private var addButton: some View {
        Button(action: addSlot) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Ajouter")
                    .font(.system(size: 13, weight: .heavy))
            }
            .foregroundStyle(Theme.ink)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Theme.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ajouter un créneau")
    }

    /// Chaque carte reçoit une liaison directe sur son créneau : la frappe écrit
    /// dans `localSchedule`, sans copie intermédiaire (le curseur ne saute pas).
    @ViewBuilder
    private var slotsList: some View {
        if daySlots(selectedDay).isEmpty {
            ExtraScheduleEmptyState()
        } else {
            ForEach(daySlots(selectedDay)) { slot in
                if let index = localSchedule.firstIndex(where: { $0.id == slot.id }) {
                    ExtraScheduleSlotCard(
                        slot: $localSchedule[index],
                        onDelete: { deleteSlot(slot.id) }
                    )
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: Logique

    /// `daySlots` de la source : filtre sur le jour, puis tri par heure de début
    /// (`localeCompare` en JS, comparaison lexicographique ici).
    private func daySlots(_ day: String) -> [PlanScheduleSlot] {
        localSchedule
            .filter { $0.day == day }
            .sorted { $0.startTime < $1.startTime }
    }

    /// `addSlot` : nouveau créneau du jour sélectionné, valeurs par défaut.
    private func addSlot() {
        let slot = PlanScheduleSlot(
            id: ExtraScheduleCatalog.newSlotId(),
            day: selectedDay,
            startTime: ExtraScheduleCatalog.defaultStart,
            endTime: ExtraScheduleCatalog.defaultEnd,
            subject: ExtraScheduleCatalog.defaultSubject
        )
        localSchedule.append(slot)
    }

    /// `deleteSlot` : retire le créneau de la copie locale.
    private func deleteSlot(_ id: String) {
        localSchedule.removeAll { $0.id == id }
    }

    /// `handleSave` : la copie locale validée part vers l'hôte, puis fermeture.
    private func handleSave() {
        onSave(localSchedule)
        onClose()
    }

    /// `handleClose` : abandon sans validation, la copie d'origine est restituée.
    private func handleClose() {
        localSchedule = schedule
        onClose()
    }
}

// MARK: - Bandeau d'information

/// `infoCard` : rappel de l'usage des horaires (fond `primaryLight`).
private struct ExtraScheduleInfoCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Renseigne tes heures de cours pour que Duello adapte ton programme en fonction de ton emploi du temps réel.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
}

// MARK: - Onglet de jour

/// Bouton d'un jour, actif ou non, surmonté du nombre de créneaux (`dayBadge`).
private struct ExtraScheduleDayTab: View {
    let day: String
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(day)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(selected ? Theme.ink : Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMedium)
                        .stroke(selected ? Theme.ink : Theme.border, lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    if count > 0 { badge }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count > 0 ? "\(day), \(count) cours" : day)
    }

    /// `dayBadge` : pastille du nombre de cours du jour (fond `accent` = encre).
    private var badge: some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(Theme.surface)
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 20)
            .background(Theme.ink)
            .clipShape(Capsule())
            .offset(x: 6, y: -6)
    }
}

// MARK: - Carte de créneau

/// `slotCard` : heures, matière et salle d'un créneau, avec suppression.
private struct ExtraScheduleSlotCard: View {
    @Binding var slot: PlanScheduleSlot
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            timesRow
            subjectField
            roomField
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.bottom, 12)
    }

    private var timesRow: some View {
        HStack(spacing: 8) {
            timeField($slot.startTime, placeholder: "08:00")
            Text("-")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
            timeField($slot.endTime, placeholder: "10:00")
            Spacer(minLength: 8)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Supprimer ce créneau")
        }
    }

    private var subjectField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Matière")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExtraScheduleCatalog.subjects, id: \.self) { subject in
                        ExtraScheduleSubjectButton(
                            subject: subject,
                            active: slot.subject == subject
                        ) {
                            slot.subject = subject
                        }
                    }
                }
            }
        }
    }

    private var roomField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Salle (optionnel)")
            TextField("Ex: A203", text: roomBinding)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Theme.background)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
    }

    /// `room` est facultatif : la chaîne vide du champ le ramène à `nil`.
    private var roomBinding: Binding<String> {
        Binding(
            get: { slot.room ?? "" },
            set: { slot.room = $0.isEmpty ? nil : $0 }
        )
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(Theme.inkSoft)
    }

    private func timeField(_ text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numbersAndPunctuation)
            .multilineTextAlignment(.center)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Theme.ink)
            .frame(width: 78)
            .padding(.vertical, 8)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

// MARK: - Bouton de matière

/// `subjectButton` : matière sélectionnable d'un créneau.
private struct ExtraScheduleSubjectButton: View {
    let subject: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(subject)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(active ? Theme.surface : Theme.inkSoft)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(active ? Theme.ink : Theme.background)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .stroke(active ? Theme.ink : Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - État vide

/// `emptyState` : aucun cours le jour sélectionné.
private struct ExtraScheduleEmptyState: View {
    var body: some View {
        DuelloEmptyState(
            icon: "calendar",
            title: "Aucun cours ce jour",
            message: "Appuie sur \"Ajouter\" pour créer un créneau."
        )
        .padding(.horizontal, 20)
    }
}
