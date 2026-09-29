//
//  HecJourneyAdmissionView.swift
//  Duello
//
//  Port de `src/components/HecJourneyAdmissionScreen.tsx`.
//
//  À raccorder (vague 2, 2026-09-29) : le blason PNG officiel
//  (`assets/league-badges/*.png`) n'est pas rendu — il doit être embarqué puis
//  branché dans `HecJourneyCrestView` (`Image(crest.schoolId)`), fichier hors de
//  cette unité (voir rapport, « À raccorder »). En attendant, le repli coloré du
//  catalogue reste le rendu nominal (voir `HecJourneyCrestView.swift`).
//
import SwiftUI

/// Écran « MON ADMISSION », dernière étape du parcours.
///
/// Porté de `src/components/HecJourneyAdmissionScreen.tsx` : blason de l'école
/// retenue, question « Où as-tu été admis·e ? », liste d'écoles filtrée par la
/// filière du profil (`hecJourneyAdmissionSchoolsForTrack`), nom libre pour
/// « Autre école », rang d'admission, puis « ENREGISTRER MON ADMISSION » et
/// « RÉINITIALISER ».
///
/// Les mesures, typos et styles d'interaction reproduisent fidèlement la
/// source RN :
/// - en-tête avec `BackButton` (chevron nu, 22), padding horizontal 14 ;
/// - pastille d'école : cercle 10×10 (`schoolDot`), sélection `checkmark-circle` 18 ;
/// - champs de texte : `minHeight` 52, padding horizontal 15, radius 14,
///   typo 16/700, auto-capitalisation par mot pour l'école, filtre numérique et
///   limite 6 pour le rang ;
/// - boutons : `minHeight` 52/48, radius 15, typo 10/900 letter-spacing 1.1,
///   opacité désactivée 0,32.
struct HecJourneyAdmissionView: View {
    let admission: HecJourneyAdmission?
    /// Filière du profil (`admissionTrack` côté Expo) : elle filtre les écoles.
    let admissionTrack: String
    let onBack: () -> Void
    let onSave: (HecJourneyAdmission) -> Void
    let onReset: () -> Void

    @State private var schoolId: String
    @State private var rankText: String
    @State private var customSchoolName: String
    @State private var confirmReset = false

    init(
        admission: HecJourneyAdmission?,
        admissionTrack: String,
        onBack: @escaping () -> Void,
        onSave: @escaping (HecJourneyAdmission) -> Void,
        onReset: @escaping () -> Void
    ) {
        self.admission = admission
        self.admissionTrack = admissionTrack
        self.onBack = onBack
        self.onSave = onSave
        self.onReset = onReset

        let schools = HecJourneyAdmissionCatalog.schools(forTrack: admissionTrack)
        let fallback = schools.first?.id ?? "other"
        let known = admission.map { candidate in
            schools.contains { $0.id == candidate.schoolId } ? candidate.schoolId : fallback
        }
        _schoolId = State(initialValue: known ?? fallback)
        _rankText = State(initialValue: admission.map { String($0.rank) } ?? "")
        _customSchoolName = State(initialValue: admission?.customSchoolName ?? "")
    }

    /// Écoles proposées pour la filière (`admissionTrack`).
    private var schools: [HecJourneyAdmissionSchool] {
        HecJourneyAdmissionCatalog.schools(forTrack: admissionTrack)
    }

    /// `draftAdmission` : école connue, rang entier de 1 à 100 000, et nom
    /// obligatoire pour « Autre école ». Nul, le bouton reste inactif.
    private var draftAdmission: HecJourneyAdmission? {
        guard schools.contains(where: { $0.id == schoolId }),
              let rank = Int(rankText),
              rank >= 1,
              rank <= 100_000
        else { return nil }
        let name = customSchoolName.trimmingCharacters(in: .whitespacesAndNewlines)
        if schoolId == "other" && name.isEmpty { return nil }
        return HecJourneyAdmission(
            schoolId: schoolId,
            rank: rank,
            customSchoolName: schoolId == "other" ? String(name.prefix(80)) : nil
        )
    }

    /// Aperçu du blason : il suit la saisie, comme `previewAdmission`.
    private var previewCrest: HecJourneyAdmissionCrest {
        HecJourneyAdmissionCodec.crest(
            for: HecJourneyAdmission(
                schoolId: schoolId,
                rank: Int(rankText) ?? 1,
                customSchoolName: schoolId == "other" ? customSchoolName : nil
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    HecJourneyCrestView(crest: previewCrest, height: 144)
                        .padding(.top, 24)
                    Text(HecJourneyAdmissionCopy.question)
                        .font(.system(size: 24, weight: .black))
                        .lineSpacing(6)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                    Text(HecJourneyAdmissionCopy.subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineSpacing(6)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 350)
                        .padding(.top, 8)
                    schoolGrid
                        .padding(.top, 22)
                    if schoolId == "other" {
                        customNameField
                    }
                    rankField
                    saveButton
                    resetButton
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 42)
            }
        }
        .background(Theme.background)
        .alert(HecJourneyAdmissionCopy.resetQuestion, isPresented: $confirmReset) {
            Button(HecJourneyAdmissionCopy.cancel, role: .cancel) { }
            Button(HecJourneyAdmissionCopy.resetAction, role: .destructive) { onReset() }
        } message: {
            Text(HecJourneyAdmissionCopy.resetMessage)
        }
    }

    // MARK: En-tête

    private var header: some View {
        ZStack {
            VStack(spacing: 2) {
                Text(HecJourneyAdmissionCopy.eyebrow)
                    .font(.system(size: 8, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(Theme.inkFaint)
                Text(HecJourneyAdmissionCopy.title)
                    .font(.system(size: 15, weight: .black))
                    .tracking(1.1)
                    .foregroundStyle(Theme.ink)
            }
            HStack {
                HecJourneySheet.IconButton(
                    name: "chevron-back",
                    label: HecJourneyCopy.a11yBackToJourney,
                    size: 22,
                    tint: Theme.ink,
                    width: 40,
                    height: 40,
                    pressOpacity: 0.6,
                    action: onBack
                )
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 64)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    // MARK: Écoles

    private var schoolGrid: some View {
        LazyVStack(spacing: 8) {
            ForEach(schools) { school in
                schoolRow(school)
            }
        }
    }

    private func schoolRow(_ school: HecJourneyAdmissionSchool) -> some View {
        let selected = school.id == schoolId
        return Button {
            schoolId = school.id
        } label: {
            HStack(spacing: 11) {
                Circle()
                    .fill(Color(hex: school.colorHex))
                    .frame(width: 10, height: 10)
                Text(school.name)
                    .font(.system(size: 13, weight: .bold))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer(minLength: 6)
                if selected {
                    IonIcon(name: "checkmark-circle", size: 18, color: Theme.ink)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color(hex: 0xF0EEE9) : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Theme.ink : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(HecJourneySheet.PressOpacityStyle(pressed: 0.68))
        .accessibilityLabel(HecJourneyAdmissionCopy.a11ySchool(school.name))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: Saisies

    private var customNameField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(HecJourneyAdmissionCopy.schoolNameLabel)
                .font(.system(size: 9, weight: .black))
                .tracking(1.1)
                .foregroundStyle(Theme.inkSoft)
            TextField(
                "",
                text: Binding(
                    get: { customSchoolName },
                    set: { customSchoolName = String($0.prefix(80)) }
                ),
                prompt: Text(HecJourneyAdmissionCopy.schoolNamePlaceholder).foregroundColor(Theme.inkFaint)
            )
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 15)
            .frame(minHeight: 52)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .padding(.top, 20)
    }

    private var rankField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(HecJourneyAdmissionCopy.rankLabel)
                .font(.system(size: 9, weight: .black))
                .tracking(1.1)
                .foregroundStyle(Theme.inkSoft)
            TextField(
                "",
                text: Binding(
                    get: { rankText },
                    set: { newValue in
                        let digits = newValue.filter(\.isNumber)
                        rankText = String(digits.prefix(6))
                    }
                ),
                prompt: Text(HecJourneyAdmissionCopy.rankPlaceholder).foregroundColor(Theme.inkFaint)
            )
            .keyboardType(.numberPad)
            .autocorrectionDisabled()
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 15)
            .frame(minHeight: 52)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .accessibilityLabel(HecJourneyAdmissionCopy.rankA11y)
        }
        .padding(.top, 20)
    }

    // MARK: Actions

    private var saveButton: some View {
        Button {
            if let draft = draftAdmission { onSave(draft) }
        } label: {
            Text(HecJourneyAdmissionCopy.save)
                .font(.system(size: 10, weight: .black))
                .tracking(1.1)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(HecJourneySheet.PressOpacityStyle(pressed: 0.68))
        .disabled(draftAdmission == nil)
        .opacity(draftAdmission == nil ? 0.32 : 1)
        .padding(.top, 24)
        .accessibilityLabel(HecJourneyAdmissionCopy.saveA11y)
    }

    private var resetButton: some View {
        Button {
            confirmReset = true
        } label: {
            Text(HecJourneyAdmissionCopy.reset)
                .font(.system(size: 10, weight: .black))
                .tracking(1.1)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(HecJourneySheet.PressOpacityStyle(pressed: 0.68))
        .disabled(admission == nil)
        .opacity(admission == nil ? 0.32 : 1)
        .padding(.top, 10)
        .accessibilityLabel(HecJourneyAdmissionCopy.resetA11y)
    }
}
