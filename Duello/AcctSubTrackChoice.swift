//
//  AcctSubTrackChoice.swift
//  Duello
//
//  Lot 15-A — compléments « parcours du compte ».
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/screens/AccountTrackScreen.tsx
//    - src/utils/academicPath.ts (CURRENT_TRACK_DESCRIPTIONS,
//                                currentTrackChoices, isFirstYear, isLyceeYear)
//
//  `TrackSettingsView` (lot Account) édite déjà filière/année/option/prépa/
//  ville via des `Picker` segmentés, sans description. Cette vue-ci porte **ce
//  qui manque** : le choix de filière en cartes radio, avec la description de
//  chaque filière, le sous-titre dépendant de l'année et l'état accessible
//  radio/coché. Aucun type existant n'est redéfini (`OnbFlowAcademic` reste
//  utilisé par l'onboarding, il n'est pas touché).
//
import SwiftUI

/// Catalogue des filières (`utils/academicPath.ts`).
enum AcctSubTrackCatalog {
    /// `CURRENT_TRACK_DESCRIPTIONS` — description affichée sous chaque filière.
    static let descriptions: [String: String] = [
        "MPSI": "Mathématiques, physique et sciences de l’ingénieur",
        "MP2I": "Mathématiques, physique, ingénierie et informatique",
        "PCSI": "Physique, chimie et sciences de l’ingénieur",
        "PTSI": "Physique, technologie et sciences de l’ingénieur",
        "MP": "Mathématiques et physique",
        "MPI": "Mathématiques, physique et informatique",
        "PC": "Physique et chimie",
        "PT": "Physique et technologie",
        "PSI": "Physique et sciences de l’ingénieur",
        "BCPST": "Biologie, chimie, physique et sciences de la Terre",
        "B/L": "Lettres et sciences sociales",
        "ECG": "Économique et commerciale, voie générale",
        "Lycée": "Seconde, première ou terminale",
    ]

    /// `FIRST_YEAR_TRACKS` / `SECOND_YEAR_TRACKS` / `LYCEE_TRACKS`.
    static let firstYearTracks = ["MPSI", "MP2I", "PCSI", "PTSI", "BCPST", "B/L", "ECG"]
    static let secondYearTracks = ["MP", "MPI", "PC", "PT", "PSI", "BCPST", "B/L", "ECG"]
    static let lyceeTracks = ["Lycée"]

    /// `LYCEE_YEARS`.
    static let lyceeYears = ["2de", "1re", "Terminale"]

    /// `isFirstYear` (`academicPath.ts`).
    static func isFirstYear(_ year: String) -> Bool { year == "1re année" }

    /// `isLyceeYear` (`academicPath.ts`).
    static func isLyceeYear(_ year: String) -> Bool { lyceeYears.contains(year) }

    /// `currentTrackChoices` : filières proposées selon l'année du profil.
    static func choices(forYear year: String) -> [String] {
        if isLyceeYear(year) { return lyceeTracks }
        return isFirstYear(year) ? firstYearTracks : secondYearTracks
    }

    /// `CURRENT_TRACK_DESCRIPTIONS[track]`.
    static func description(for track: String) -> String {
        descriptions[track] ?? ""
    }
}

/// Choix de la filière en cartes radio, tel que `AccountTrackScreen.tsx`.
struct AcctSubTrackChoiceList: View {
    let year: String
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading
            VStack(spacing: 10) {
                ForEach(AcctSubTrackCatalog.choices(forYear: year), id: \.self) { track in
                    optionRow(track)
                }
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Choisis ta filière")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Theme.ink)
            Text("Les filières proposées correspondent à ta \(year).")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Carte radio : fond encre et coche quand la filière est retenue.
    private func optionRow(_ track: String) -> some View {
        let isSelected = track == selected
        let description = AcctSubTrackCatalog.description(for: track)
        return Button {
            onSelect(track)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(track)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(isSelected ? Theme.surface : Theme.ink)
                    Text(description)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.primaryLight : Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.surface)
                }
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(isSelected ? Theme.ink : Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(description.isEmpty ? track : "\(track) — \(description)")
    }
}
