import SwiftUI

/// En-tête de l'écran « Progression » : filtre de matières à sélection multiple
/// puis, en mode embarqué, résumé compact de toutes les matières. Extension de
/// `DuelloProgressView` (voir `ProgressScreen.swift` pour le découpage).
extension DuelloProgressView {

    // MARK: Filtre de matières (sélection multiple)

    /// En-tête du filtre (compteur `Matières · n/N`) puis, déplié, les cases à
    /// cocher d'une matière, les raccourcis « Tout »/« Aucune ».
    var subjectPickerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                subjectPickerOpen.toggle()
            } label: {
                HStack(spacing: 8) {
                    IonIcon(name: "funnel-outline", size: 16, color: Theme.primary)
                    Text("Matières · \(activeSubjectNames.count)/\(subjectNames.count)")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    IonIcon(
                        name: subjectPickerOpen ? "chevron-up" : "chevron-down",
                        size: 18,
                        color: Theme.inkSoft
                    )
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                .duelloShadow()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Choisir les matières affichées")
            .accessibilityValue(subjectPickerOpen ? "Déplié" : "Replié")

            if subjectPickerOpen {
                subjectPickerPanel
                    .padding(.top, 8)
            }
        }
    }

    /// Panneau déplié du filtre : raccourcis, puis une case par matière.
    private var subjectPickerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                quickButton("Tout") { selectedSubjectNames = Set(subjectNames) }
                quickButton("Aucune") { selectedSubjectNames = [] }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)

            ForEach(subjects) { subject in
                Button {
                    toggleSubject(subject.name)
                } label: {
                    HStack(spacing: 10) {
                        checkBox(activeSubjectNames.contains(subject.name))
                        Text(subject.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // `accessibilityRole="checkbox"` + `accessibilityState={{ checked }}`
                // (`EnhancedProgressScreen.tsx:350-351`).
                .accessibilityAddTraits(
                    activeSubjectNames.contains(subject.name)
                        ? [.isButton, .isSelected]
                        : [.isButton]
                )
                .accessibilityValue(activeSubjectNames.contains(subject.name) ? "coché" : "non coché")
            }
        }
        .padding(8)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .duelloShadow()
    }

    /// Raccourci de sélection du filtre (« Tout », « Aucune »).
    private func quickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.primary)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Theme.primaryLight)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Case à cocher d'une matière du filtre.
    private func checkBox(_ checked: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(checked ? Theme.primary : Color.clear)
            RoundedRectangle(cornerRadius: 6)
                .stroke(checked ? Theme.primary : Theme.inkFaint, lineWidth: 2)
            if checked {
                IonIcon(name: "checkmark", size: 14, color: Theme.surface)
            }
        }
        .frame(width: 22, height: 22)
    }

    /// Coche ou décoche une matière (`toggleSubject` d'Expo).
    func toggleSubject(_ name: String) {
        var selection = activeSubjectNames
        if selection.contains(name) {
            selection.remove(name)
        } else {
            selection.insert(name)
        }
        selectedSubjectNames = selection
    }

    // MARK: Résumé compact (mode embarqué)

    /// Une matière du résumé embarqué : son nom, puis une ligne compacte par
    /// type de travail. Toutes les matières sont listées, séparées par un filet.
    var embeddedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(subjects) { subject in
                let exercises = trainingStat(for: subject, kind: .exercises)
                let colles = trainingStat(for: subject, kind: .colles)
                let challenges = duelStat(for: subject)

                VStack(alignment: .leading, spacing: 14) {
                    Text(subject.name)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.ink)

                    EmbeddedMetric(
                        label: "Exercices",
                        value: exercises.total > 0
                            ? "\(exercises.mastered)/\(exercises.total) maîtrisés"
                            : "Contenu à venir",
                        progress: exercises.fraction
                    )
                    EmbeddedMetric(
                        label: "Colles",
                        value: colles.total > 0
                            ? "\(colles.mastered)/\(colles.total) maîtrisées"
                            : "Contenu à venir",
                        progress: colles.fraction
                    )
                    EmbeddedMetric(
                        label: "Défis",
                        value: "\(challenges.won)/\(challenges.played) gagnés · \(elo(for: subject)) Elo",
                        progress: challenges.fraction
                    )
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(height: 1)
                }
            }
        }
        .padding(.bottom, 12)
    }
}
