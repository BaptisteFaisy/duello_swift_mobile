import SwiftUI

/// Écran « MON ADMISSION », dernière étape du parcours.
///
/// Porté de `src/components/HecJourneyAdmissionScreen.tsx` : blason de l'école
/// retenue, question « Où as-tu été admis·e ? », liste d'écoles filtrée par la
/// filière du profil (`hecJourneyAdmissionSchoolsForTrack`), nom libre pour
/// « Autre école », rang d'admission, puis « ENREGISTRER MON ADMISSION » et
/// « RÉINITIALISER ».
///
/// Limites assumées : le blason officiel (`leagueBadgeSourceForLeague`) est un
/// PNG absent de l'app Swift, donc le repli de la source est repris
/// (`HecJourneyCrestView`) ; et les alertes d'échec d'enregistrement n'ont pas
/// d'équivalent, l'écriture locale étant synchrone et sans erreur possible.
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
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                    Text(HecJourneyAdmissionCopy.subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                    schoolGrid
                        .padding(.top, 22)
                    if schoolId == "other" {
                        customNameField
                    }
                    rankField
                    saveButton
                        .padding(.top, 22)
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
                    systemName: "chevron.left",
                    label: HecJourneyCopy.a11yBackToJourney,
                    size: 18,
                    tint: Theme.ink,
                    frame: 40,
                    action: onBack
                )
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
        }
        .frame(minHeight: 64)
        .background(Theme.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    // MARK: Écoles

    private var schoolGrid: some View {
        VStack(spacing: 8) {
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
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: school.colorHex))
                    .frame(width: 18, height: 18)
                Text(school.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer(minLength: 6)
                if selected {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.surfaceMuted : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(selected ? Theme.ink : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(HecJourneyAdmissionCopy.a11ySchool(school.name))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: Saisies

    private var customNameField: some View {
        DuelloTextField(
            title: HecJourneyAdmissionCopy.schoolNameLabel,
            text: $customSchoolName
        )
        .padding(.top, 20)
    }

    private var rankField: some View {
        DuelloTextField(
            title: HecJourneyAdmissionCopy.rankLabel,
            text: $rankText,
            keyboard: .numberPad
        )
        .padding(.top, 20)
        .accessibilityLabel(HecJourneyAdmissionCopy.rankA11y)
    }

    // MARK: Actions

    private var saveButton: some View {
        Button {
            if let draft = draftAdmission { onSave(draft) }
        } label: {
            Text(HecJourneyAdmissionCopy.save)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Theme.surface)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        }
        .buttonStyle(.plain)
        .disabled(draftAdmission == nil)
        .opacity(draftAdmission == nil ? 0.45 : 1)
        .accessibilityLabel(HecJourneyAdmissionCopy.saveA11y)
    }

    private var resetButton: some View {
        Button {
            confirmReset = true
        } label: {
            Text(HecJourneyAdmissionCopy.reset)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusLarge)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(admission == nil)
        .opacity(admission == nil ? 0.45 : 1)
        .padding(.top, 10)
        .accessibilityLabel(HecJourneyAdmissionCopy.resetA11y)
    }
}
