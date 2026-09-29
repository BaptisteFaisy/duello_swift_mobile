//
//  ProgressSummary.swift
//  Duello
//
//  Port de src/screens/EnhancedProgressScreen.tsx — en-tête de l'écran
//  « Progression » : filtre de matières (sélection multiple) puis, en mode
//  embarqué, résumé compact de toutes les matières. Extension de
//  `DuelloProgressView` (voir `ProgressScreen.swift` pour le découpage).
//
//  V2 (2026-09-29) — écart U12#3 « panneau du filtre : overlay ancré vs panneau
//  en flux » : le panneau n'est plus inséré dans le flux (il ne pousse plus les
//  cartes vers le bas) ; il est présenté en superposition **ancrée au
//  déclencheur**, mesuré en coordonnées globales (`DropdownOverlay`, source
//  `EnhancedProgressScreen.tsx:321-361`), et se ferme au tap extérieur.
//
//  Écarts assumés :
//    - la coordination multi-menus d'un même `coordinationScope`
//      (`dropdownDismiss.ts`) n'est pas portée : cet écran n'a qu'un menu ;
//    - la couche plein écran s'appuie sur `UIScreen.main.bounds` (iOS 16) ;
//      le panneau reste confiné à la fenêtre visible de la `ScrollView` hôte.
//
import SwiftUI
import UIKit

/// Cadre global du déclencheur du filtre, mesuré à l'affichage.
private struct ProgressPickerAnchorKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

extension DuelloProgressView {

    // MARK: Filtre de matières (sélection multiple)

    /// Déclencheur `Matières · n/N` puis panneau en superposition ancrée
    /// (`renderSubjectPicker`, `EnhancedProgressScreen.tsx:300-361`).
    var subjectPickerCard: some View {
        ProgressSubjectPickerCard(
            subjectNames: subjectNames,
            subjects: subjects,
            activeSubjectNames: activeSubjectNames,
            isOpen: $subjectPickerOpen,
            onSelectAll: { selectedSubjectNames = Set(subjectNames) },
            onSelectNone: { selectedSubjectNames = [] },
            onToggle: { toggleSubject($0) }
        )
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

// MARK: - Filtre : déclencheur + panneau ancré

/// Filtre de matières : déclencheur puis panneau en superposition **ancré** au
/// déclencheur (`DropdownOverlay`), fermé au tap extérieur — au lieu du panneau
/// en flux qui poussait les cartes vers le bas.
private struct ProgressSubjectPickerCard: View {
    let subjectNames: [String]
    let subjects: [TrackSubject]
    let activeSubjectNames: Set<String>
    @Binding var isOpen: Bool
    let onSelectAll: () -> Void
    let onSelectNone: () -> Void
    let onToggle: (String) -> Void

    /// Cadre global du déclencheur, mesuré à l'affichage.
    @State private var anchor: CGRect = .zero

    var body: some View {
        trigger
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ProgressPickerAnchorKey.self,
                        value: proxy.frame(in: .global)
                    )
                }
            )
            .onPreferenceChange(ProgressPickerAnchorKey.self) { anchor = $0 }
            .overlay(alignment: .topLeading) { if isOpen { overlay } }
            .zIndex(isOpen ? 1 : 0)
    }

    /// `pickerHeader` : entonnoir, compteur `Matières · n/N`, chevron.
    private var trigger: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 8) {
                IonIcon(name: "funnel-outline", size: 16, color: Theme.primary)
                Text("Matières · \(activeSubjectNames.count)/\(subjectNames.count)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                IonIcon(
                    name: isOpen ? "chevron-up" : "chevron-down",
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
        .accessibilityValue(isOpen ? "Déplié" : "Replié")
    }

    /// Couche plein écran : voile transparent (fermeture au tap extérieur) puis
    /// le panneau, posé juste sous le déclencheur.
    private var overlay: some View {
        let screen = UIScreen.main.bounds
        return ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { isOpen = false }
                .accessibilityLabel("Fermer le menu déroulant")
            panel(width: anchor.width > 0 ? anchor.width : screen.width - 40)
                .offset(x: 0, y: anchor.height + 6)
        }
        .frame(width: screen.width, height: screen.height, alignment: .topLeading)
        .offset(x: -anchor.minX, y: -anchor.minY)
        .ignoresSafeArea()
    }

    /// `pickerPanel` : raccourcis puis une case par matière.
    private func panel(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                quickButton("Tout", action: onSelectAll)
                quickButton("Aucune", action: onSelectNone)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)

            ForEach(subjects) { subject in
                row(subject)
            }
        }
        .padding(8)
        .frame(width: width, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .duelloShadow()
    }

    /// Une ligne cochable (`pickerRow`) : case, libellé, et zone d'appui pleine.
    private func row(_ subject: TrackSubject) -> some View {
        let checked = activeSubjectNames.contains(subject.name)
        return Button {
            onToggle(subject.name)
        } label: {
            HStack(spacing: 10) {
                checkBox(checked)
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
        .accessibilityAddTraits(checked ? [.isButton, .isSelected] : [.isButton])
        .accessibilityValue(checked ? "coché" : "non coché")
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
}
