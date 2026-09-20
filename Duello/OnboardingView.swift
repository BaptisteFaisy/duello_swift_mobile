import SwiftUI

/// Parcours de première configuration, affiché juste après l'inscription quand
/// le profil est vide. Reprend les étapes de programme de
/// `src/screens/OnboardingScreen.tsx` — année, filière actuelle, option, puis
/// récapitulatif — sur le thème clair de l'app.
///
/// Volontairement laissés de côté :
/// - les étapes `identity`, `auth-method` et `credentials`, déjà portées par
///   `WelcomeView` (inscription e-mail et Google) ;
/// - l'étape `premium-gift`, dont les animations ne sont pas reprises.
struct OnboardingView: View {
    /// Appelée une fois le parcours terminé et le profil écrit.
    let onFinish: () -> Void

    @EnvironmentObject private var session: SessionStore

    /// Indice de l'étape courante dans `steps`.
    @State private var stepIndex = 0
    /// Année retenue (« 1re année » ou « 2e année »).
    @State private var year = ""
    /// Filière retenue (MPSI, MP2I, ECG, MP, MPI, PSI).
    @State private var track = ""
    /// Option retenue ; vide quand la filière n'en propose pas.
    @State private var specialty = ""

    /// Années proposées, comme `YEARS` de l'écran Expo : la prépa seulement,
    /// les niveaux lycée restant hors périmètre.
    private let years = ["1re année", "2e année"]

    /// Filières de 1re année, reprises de `FIRST_YEAR_TRACKS`
    /// (`utils/academicPath.ts`) et limitées aux filières couvertes par Duello
    /// (PCSI, PTSI, BCPST et B/L n'ont pas de programme embarqué).
    private static let firstYearTracks = ["MPSI", "MP2I", "ECG"]

    /// Filières de 2e année, reprises de `SECOND_YEAR_TRACKS`
    /// (`utils/academicPath.ts`), même restriction.
    private static let secondYearTracks = ["MP", "MPI", "PSI", "ECG"]

    var body: some View {
        VStack(spacing: 0) {
            progressBar

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    stepContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 26)
                .padding(.bottom, 28)
            }

            footer
        }
        .background(Theme.background)
    }

    // MARK: Étapes

    /// Étapes réellement parcourues : l'option ne se demande que pour les
    /// filières qui en proposent une (voir `optionChoices`).
    private var steps: [OnboardingStep] {
        var result: [OnboardingStep] = [.year, .track]
        if !optionChoices.isEmpty { result.append(.option) }
        result.append(.ready)
        return result
    }

    /// Étape courante, bornée : changer de filière peut retirer l'étape
    /// d'option sous les pieds de l'indice courant.
    private var currentStep: OnboardingStep {
        steps[min(stepIndex, steps.count - 1)]
    }

    /// Indice borné de l'étape courante, pour la barre de progression.
    private var currentStepIndex: Int {
        min(stepIndex, steps.count - 1)
    }

    // MARK: Progression et en-tête

    /// Barre fine de progression, comme `progressTrack` / `progressFill` de
    /// l'écran Expo : un rail gris, un remplissage vert à hauteur de l'étape.
    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.surfaceMuted)
                Rectangle()
                    .fill(Theme.progress)
                    .frame(width: proxy.size.width * progressFraction)
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel("Progression")
        .accessibilityValue(Text("Étape \(currentStepIndex + 1) sur \(steps.count)"))
    }

    /// Part du parcours déjà remplie : l'étape courante sur le total.
    private var progressFraction: Double {
        Double(currentStepIndex + 1) / Double(steps.count)
    }

    /// Surtitre de l'étape, dans l'esprit de `STEP_COPY` de l'écran Expo.
    private var header: some View {
        Group {
            if let eyebrow = currentStep.eyebrow {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.ink)
            }
        }
    }

    /// Contenu de l'étape courante.
    private var stepContent: some View {
        Group {
            switch currentStep {
            case .year:
                choiceList(years, selected: year) { select(year: $0) }
            case .track:
                choiceList(trackChoices, selected: track) { select(track: $0) }
            case .option:
                optionStep
            case .ready:
                readyStep
            }
        }
    }

    /// Liste verticale de pastilles pleine largeur, comme les puces `wide` de
    /// l'écran Expo.
    private func choiceList(
        _ labels: [String],
        selected: String,
        action: @escaping (String) -> Void
    ) -> some View {
        VStack(spacing: 10) {
            ForEach(labels, id: \.self) { label in
                OnboardingChoiceChip(label: label, isSelected: label == selected) {
                    action(label)
                }
            }
        }
    }

    /// Étape « Ton option » : le niveau de mathématiques en ECG, l'option
    /// informatique en MPSI / MPI / MP.
    private var optionStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let prompt = optionPrompt {
                Text(prompt)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }

            VStack(spacing: 10) {
                ForEach(optionChoices, id: \.value) { choice in
                    OnboardingChoiceChip(
                        label: choice.label,
                        isSelected: choice.value == specialty
                    ) {
                        specialty = choice.value
                    }
                }
            }
        }
    }

    /// Étape « Prêt » : récapitulatif du parcours retenu.
    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.progress)
                Text("Prêt")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Theme.ink)
            }

            VStack(alignment: .leading, spacing: 12) {
                recapRow("Année", year)
                Divider()
                recapRow("Filière", track)
                Divider()
                recapRow("Option", optionSummary)
            }
            .duelloCard()
        }
    }

    /// Ligne du récapitulatif : libellé à gauche, valeur à droite.
    private func recapRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkFaint)
            Spacer(minLength: 0)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: Pied d'écran

    /// Pied d'écran : retour discret à gauche, action principale à droite,
    /// comme `footer` de l'écran Expo.
    private var footer: some View {
        HStack(spacing: 11) {
            if stepIndex > 0 {
                Button(action: goBack) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("Retour")
                    }
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(minHeight: 54)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Étape précédente")
            }

            Button(action: advance) {
                HStack(spacing: 9) {
                    Text(isLastStep ? "Commencer" : "Continuer")
                    Image(systemName: isLastStep ? "checkmark" : "arrow.right")
                }
                .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(DuelloPrimaryButton())
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.45)
        }
        .padding(.horizontal, 22)
        .padding(.top, 13)
        .padding(.bottom, 10)
        .background(Theme.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }

    // MARK: Parcours

    /// Filières proposées selon l'année choisie.
    private var trackChoices: [String] {
        year == "1re année" ? Self.firstYearTracks : Self.secondYearTracks
    }

    /// Change d'année et abandonne une filière devenue invalide.
    private func select(year newYear: String) {
        year = newYear
        if !trackChoices.contains(track) {
            track = ""
            specialty = ""
        }
    }

    /// Change de filière et repart de son option par défaut.
    private func select(track newTrack: String) {
        track = newTrack
        specialty = Self.defaultSpecialty(for: newTrack)
    }

    /// Option retenue quand la filière ne pose pas la question : PSI n'a qu'une
    /// option (`TRACK_OPTIONS.PSI`), les filières sans étape d'option (MP2I) et
    /// celles dont l'option reste à choisir n'en portent aucune.
    private static func defaultSpecialty(for track: String) -> String {
        track == "PSI" ? "Sciences industrielles" : ""
    }

    /// Une option de filière : libellé affiché et valeur conservée dans le
    /// profil, alignés sur `TRACK_OPTIONS` et `onboardingMathOptionChoices`
    /// (`utils/academicPath.ts`).
    private struct OptionChoice {
        let label: String
        let value: String
    }

    /// Options proposées pour la filière retenue.
    ///
    /// - ECG : le niveau de mathématiques, seule option demandée par
    ///   l'onboarding Expo (`onboardingMathOptionChoices`), les deux années —
    ///   sans elle, le programme de maths appliquées ou approfondies ne peut
    ///   pas être choisi ;
    /// - MPSI, MPI, MP : l'option informatique, l'autre branche étant les
    ///   sciences industrielles ;
    /// - PSI et MP2I : aucune question, la filière porte son option d'office.
    private var optionChoices: [OptionChoice] {
        switch track {
        case "ECG":
            return [
                OptionChoice(label: "Maths appliquées", value: "Maths appliquées + ESH"),
                OptionChoice(label: "Maths approfondies", value: "Maths approfondies + ESH"),
            ]
        case "MPSI", "MPI", "MP":
            return [
                OptionChoice(label: "Oui", value: "Informatique"),
                OptionChoice(label: "Non", value: "Sciences industrielles"),
            ]
        default:
            return []
        }
    }

    /// Question posée au-dessus des options, propre à la filière.
    private var optionPrompt: String? {
        switch track {
        case "ECG": return "Quel niveau de mathématiques suis-tu ?"
        case "MPSI", "MPI", "MP": return "Suis-tu l'option informatique ?"
        default: return nil
        }
    }

    /// Option retenue, telle qu'affichée au récapitulatif.
    private var optionSummary: String {
        guard !specialty.isEmpty else { return "Aucune" }
        // L'étape ECG nomme un niveau de maths, les autres l'option suivie.
        if track == "ECG", let choice = optionChoices.first(where: { $0.value == specialty }) {
            return choice.label
        }
        return specialty
    }

    /// Dernière étape : l'action principale ouvre Duello.
    private var isLastStep: Bool {
        currentStep == .ready
    }

    /// L'étape courante a-t-elle reçu sa réponse ?
    private var canAdvance: Bool {
        switch currentStep {
        case .year: return !year.isEmpty
        case .track: return !track.isEmpty
        case .option: return !specialty.isEmpty
        case .ready: return true
        }
    }

    /// Passe à l'étape suivante, ou clôt le parcours sur la dernière.
    private func advance() {
        guard canAdvance else { return }
        if isLastStep {
            finish()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                stepIndex += 1
            }
        }
    }

    /// Revient à l'étape précédente.
    private func goBack() {
        guard stepIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            stepIndex -= 1
        }
    }

    /// Écrit le parcours retenu dans le profil, puis rend la main.
    private func finish() {
        session.profile.year = year
        session.profile.track = track
        session.profile.specialty = specialty
        session.persistProfile()
        onFinish()
    }
}

/// Étape du parcours, dans l'ordre de `resolveOnboardingSteps` (mode compte,
/// étapes de programme seulement).
private enum OnboardingStep {
    case year
    case track
    case option
    case ready

    /// Surtitre de l'étape, repris de `STEP_COPY` de l'écran Expo ; `nil` pour
    /// le récapitulatif, qui porte son propre titre « Prêt ».
    var eyebrow: String? {
        switch self {
        case .year: return "Ton année"
        case .track: return "Ta filière actuelle"
        case .option: return "Ton option"
        case .ready: return nil
        }
    }
}

/// Pastille de choix, sur le motif `choiceChip` de l'écran Expo : bordure fine
/// sur fond blanc, encre pleine une fois sélectionnée.
private struct OnboardingChoiceChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(isSelected ? Theme.surface : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(isSelected ? Theme.ink : Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(isSelected ? Theme.ink : Theme.border, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
