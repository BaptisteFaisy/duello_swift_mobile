//
//  Ui2AddGradeSheet.swift
//  Duello
//
//  Lot 7-F « UI générique » (préfixe `Ui2`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/AddGradeModal.tsx (`AddGradeModal`, `gradeTypes`,
//      `DIALOG_MARGIN`)
//
//  Présenté en feuille SwiftUI (`.sheet`) : le parent décide de l'ouverture et
//  fournit `onClose`. Le type `GradeType` de `types.ts` est déjà porté sous le
//  nom `ChartGradeType` (lot « Graphiques ») et est réutilisé tel quel, sans le
//  redéfinir. Cible iOS 16.
//
import SwiftUI

/// Brouillon de note produit par la feuille (`Omit<Grade, 'id'>` de la source).
struct Ui2GradeDraft {
    let subject: String
    let type: ChartGradeType
    let grade: Double
    let outOf: Double
    let classAverage: Double?
    let date: Date
    let coefficient: Double
    let comment: String?
}

/// Fenêtre « Nouvelle note » (`AddGradeModal.tsx`).
struct Ui2AddGradeSheet: View {
    /// Matières proposées en puces (`subjects` de la source).
    let subjects: [String]
    /// Fermeture demandée par le parent (croix, « Annuler », fond).
    let onClose: () -> Void
    /// Note validée ; le parent referme s'il le souhaite, comme la source.
    let onSubmit: (Ui2GradeDraft) -> Void

    @State private var subject = ""
    @State private var type: ChartGradeType = .ds
    @State private var grade = ""
    @State private var outOf = "20"
    @State private var classAverage = ""
    @State private var coefficient = "1"
    @State private var comment = ""
    @State private var date = Date()
    @State private var formError: String?

    /// Ordre des puces de type (`gradeTypes` de la source).
    private static let gradeTypes: [ChartGradeType] = [.ds, .dm, .colle, .tp, .autre]

    private var canSubmit: Bool { !subject.isEmpty && !grade.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) { form }
            actions
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
    }

    // MARK: En-tête et actions

    private var header: some View {
        HStack {
            Text("Nouvelle note")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.ink)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Text("Annuler")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMedium)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            Button(action: handleSubmit) {
                Text("Enregistrer")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.surface)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.4)
        }
        .padding(16)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    // MARK: Formulaire

    private var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                fieldLabel("MATIÈRE *")
                chipRow(subjects, selected: subject) { subject = $0 }
            }

            Group {
                fieldLabel("TYPE *")
                chipRow(Self.gradeTypes.map(\.rawValue), selected: type.rawValue) { value in
                    if let parsed = ChartGradeType(rawValue: value) { type = parsed }
                }
            }

            Group {
                fieldLabel("NOTE *")
                gradeRow
            }

            Group {
                fieldLabel("MOYENNE DE CLASSE (optionnel)")
                inputField("11.5", text: $classAverage)
            }

            Group {
                fieldLabel("COEFFICIENT")
                inputField("1", text: $coefficient)
            }

            Group {
                fieldLabel("COMMENTAIRES (optionnel)")
                commentField
            }

            Group {
                if let formError { errorText(formError) }
                infoCard
            }
        }
        .padding(20)
    }

    private var gradeRow: some View {
        HStack(spacing: 12) {
            inputField("14.5", text: $grade)
            Text("/")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
            inputField("20", text: $outOf)
        }
    }

    private var commentField: some View {
        TextField("Revoir les demonstrations par recurrence...", text: $comment, axis: .vertical)
            .lineLimit(3...6)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }

    private var infoCard: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "camera")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.primary)
            Text("Prochainement : prends en photo ta copie pour extraction automatique.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .padding(.top, 16)
    }

    // MARK: Composants

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.8)
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    private func errorText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.like)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 14)
    }

    private func chipRow(
        _ options: [String],
        selected: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isActive = option == selected
                    Button { onSelect(option) } label: {
                        Text(option)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isActive ? Theme.surface : Theme.ink)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(isActive ? Theme.primary : Theme.background)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                                    .stroke(isActive ? Theme.primary : Theme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func inputField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }

    // MARK: Validation

    /// `handleSubmit` : valide puis émet le brouillon et remet le formulaire à zéro.
    private func handleSubmit() {
        guard !subject.isEmpty, !grade.isEmpty else {
            formError = "Choisis une matière et saisis une note."
            return
        }

        let gradeNum = Self.parse(grade)
        let outOfNum = Self.parse(outOf)
        let avgNum = classAverage.isEmpty ? nil : Self.parse(classAverage)
        let coefNum = Self.parse(coefficient)
        let valid = gradeNum.isFinite
            && outOfNum.isFinite && outOfNum > 0
            && coefNum.isFinite && coefNum > 0
            && (avgNum == nil || (avgNum?.isFinite ?? false))

        guard valid else {
            formError = "La note doit avoir un barème et un coefficient supérieurs à zéro."
            return
        }

        formError = nil
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        onSubmit(
            Ui2GradeDraft(
                subject: subject,
                type: type,
                grade: gradeNum,
                outOf: outOfNum,
                classAverage: avgNum,
                date: date,
                coefficient: coefNum,
                comment: trimmed.isEmpty ? nil : trimmed
            )
        )
        resetForm()
    }

    private func resetForm() {
        subject = ""
        type = .ds
        grade = ""
        outOf = "20"
        classAverage = ""
        coefficient = "1"
        comment = ""
        date = Date()
        formError = nil
    }

    /// `parseFloat(value.replace(',', '.'))` de la source ; `NaN` si illisible.
    private static func parse(_ value: String) -> Double {
        Double(value.replacingOccurrences(of: ",", with: ".")) ?? .nan
    }
}
