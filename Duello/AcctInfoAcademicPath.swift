//
//  AcctInfoAcademicPath.swift
//  Duello
//
//  Lot 10-C (extrait) — parcours scolaire et dropdown maison des réglages
//  « informations » (préfixe `AcctInfo`).
//
//  Détaché de `AcctInfoPages.swift` (ratchet ≤ 500 l.) :
//    - `AcctInfoAcademic` : `changeDraftYear` / `changeDraftOrigin` /
//      `normalizeAcademicPath` (`AccountScreen.tsx:1423-1464`) ;
//    - `AcctInfoDropdown` : dropdown maison (`specialtyDropdown*`,
//      `AccountScreen.tsx:4026-4084`) — bouton (valeur + chevron) et menu en
//      superposition avec coche `checkmark`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - Parcours scolaire du profil

/// Recalcul de la filière (`changeDraftYear` / `changeDraftOrigin` de
/// `AccountScreen.tsx:1423-1464`) sur les champs du profil Swift. Le chemin est
/// relu depuis `profile.academicPath` quand il est présent, sinon reconstruit
/// (`normalizeAcademicPath` d'`academicPath.ts`).
enum AcctInfoAcademic {
    /// `normalizeAcademicPath` : chemin cohérent avec l'année et les filières
    /// admises, en relisant `academicPath` du profil quand il est valide.
    static func path(_ profile: UserProfile) -> AcademicPath {
        let allowed = OnbFlowAcademic.currentTrackChoices(year: profile.year)
        let fallback = OnbFlowAcademic.defaultCurrentTrack(track: profile.track, year: profile.year)
        let savedTrack = profile.academicPath?.currentTrack
        let currentTrack = (savedTrack.flatMap { allowed.contains($0) ? $0 : nil })
            ?? (allowed.contains(fallback) ? fallback : (allowed.first ?? ""))
        let origins = OnbFlowAcademic.originChoices(currentTrack: currentTrack)
        let savedOrigin = profile.academicPath?.firstYearTrack
        let firstYearTrack = (savedOrigin.flatMap { origins.contains($0) ? $0 : nil })
            ?? (origins.first ?? currentTrack)
        return AcademicPath(
            currentTrack: currentTrack,
            firstYearTrack: firstYearTrack,
            firstYearOption: OnbFlowAcademic.normalizedOption(
                track: firstYearTrack,
                candidate: profile.academicPath?.firstYearOption ?? profile.specialty,
                firstYear: true
            ),
            currentOption: OnbFlowAcademic.normalizedOption(
                track: currentTrack,
                candidate: profile.academicPath?.currentOption ?? profile.specialty,
                firstYear: false
            )
        )
    }

    /// `changeDraftYear` : nouvelle année, filière de repli si elle ne convient
    /// plus, puis `synchronizeLegacyAcademicFields` (`track`/`specialty`).
    static func changeYear(_ profile: UserProfile, to year: String) -> UserProfile {
        let currentPath = path(profile)
        let choices = OnbFlowAcademic.currentTrackChoices(year: year)
        let currentTrack: String
        if choices.contains(currentPath.currentTrack) {
            currentTrack = currentPath.currentTrack
        } else if currentPath.currentTrack == "ECG" {
            currentTrack = "ECG"
        } else if currentPath.currentTrack == "PT" && year == "1re année" {
            currentTrack = "PTSI"
        } else {
            currentTrack = year == "1re année" ? "MPSI" : "MP"
        }
        var next = profile
        next.year = year
        next.academicPath = AcademicPath(
            currentTrack: currentTrack,
            firstYearTrack: currentPath.firstYearTrack,
            firstYearOption: currentPath.firstYearOption,
            currentOption: currentPath.currentOption
        )
        return synchronized(next)
    }

    /// `changeDraftOrigin` : l'élève PSI précise sa filière de 1re année.
    static func changeOrigin(_ profile: UserProfile, firstYearTrack: String) -> UserProfile {
        let currentPath = path(profile)
        let options = OnbFlowAcademic.firstYearOptions[firstYearTrack] ?? []
        let firstYearOption = options.contains(currentPath.firstYearOption)
            ? currentPath.firstYearOption
            : (options.count == 1 ? (options.first ?? "") : "")
        var next = profile
        next.academicPath = AcademicPath(
            currentTrack: currentPath.currentTrack,
            firstYearTrack: firstYearTrack,
            firstYearOption: firstYearOption,
            currentOption: currentPath.currentOption
        )
        return synchronized(next)
    }

    /// `synchronizeLegacyAcademicFields` : reclampe le chemin puis reporte
    /// `track`/`specialty` (`programTrackFor`, `currentOption`).
    private static func synchronized(_ profile: UserProfile) -> UserProfile {
        var result = profile
        let normalized = path(profile)
        result.academicPath = normalized
        result.track = OnbFlowAcademic.programTrackFor(normalized.currentTrack)
        result.specialty = normalized.currentOption
        return result
    }
}

// MARK: - Dropdown maison (`specialtyDropdown*`)

/// Dropdown de filière / année (`AccountScreen.tsx:4026-4084`) : bouton
/// (valeur + chevron), puis un menu en superposition (`specialtyDropdownMenu`)
/// avec coche `checkmark` sur l'option choisie. Remplace le `Menu` natif.
struct AcctInfoDropdown: View {
    let icon: String
    /// Libellé au-dessus du champ (`fieldLabel`) ; absent pour l'année.
    var label: String? = nil
    let value: String
    let options: [String]
    let accessibilityLabel: String
    let onSelect: (String) -> Void

    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let label {
                Text(label)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
            }
            ZStack(alignment: .top) {
                field
                if open { menu }
            }
            .zIndex(open ? 1 : 0)
        }
    }

    /// `informationFieldColumn` + `specialtyDropdownButton`.
    private var field: some View {
        HStack(spacing: 14) {
            IonIcon(name: icon, size: AcctInfoRowMetrics.iconSize, color: Theme.ink)
                .frame(width: AcctInfoRowMetrics.iconPill, height: AcctInfoRowMetrics.iconPill)
            Button { open.toggle() } label: {
                HStack(spacing: 8) {
                    Text(value)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    IonIcon(name: open ? "chevron-up" : "chevron-down", size: 17, color: Theme.ink)
                }
                .frame(minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            // `accessibilityState={{ expanded: … }}` (`AccountScreen.tsx:4231,4321`).
            .accessibilityValue(open ? "Déplié" : "Replié")
        }
        .frame(minHeight: 64)
        .padding(.horizontal, 8)
    }

    /// `specialtyDropdownMenu` : panneau flottant sous le champ.
    private var menu: some View {
        VStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                optionRow(option)
            }
        }
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.leading, 56)
        .padding(.trailing, 8)
        .offset(y: 64)
    }

    /// `specialtyDropdownOption` : libellé + coche quand l'option est choisie.
    private func optionRow(_ option: String) -> some View {
        let selected = option == value
        return Button {
            onSelect(option)
            open = false
        } label: {
            HStack(spacing: 8) {
                Text(option)
                    .font(.system(size: 12, weight: selected ? .black : .bold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                if selected {
                    IonIcon(name: "checkmark", size: 17, color: Theme.ink)
                }
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.surface : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // `accessibilityRole="menuitem"` (`AccountScreen.tsx:4255,4346`) : la
        // ligne retenue porte l'état sélectionné.
        .accessibilityLabel(option)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
