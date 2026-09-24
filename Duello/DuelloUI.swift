import SwiftUI
import Charts

/// Composants d'interface partagés par les écrans Duello.
///
/// Regroupés ici pour qu'aucun écran n'ait à réinventer ses cartes, ses
/// pastilles, ses barres de progression ou ses graphiques. Tous suivent la
/// même grammaire visuelle que `Theme.swift` : encre sur blanc, vert réservé à
/// la réussite, cartes à bord fin.

// MARK: - Titres

/// Titre de section en capitales, motif récurrent des écrans Expo
/// (`sectionLabel` : AccountScreen.tsx:5201, ChallengesScreen.tsx:3974 —
/// 9 / `900` / `letterSpacing: 1.4` / `inkFaint`).
struct DuelloSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .black))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkFaint)
            if let subtitle {
                // Ajout du port : `sectionLabel` n'a pas de sous-titre en RN.
                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Pastilles

/// Ton d'une pastille : la couleur porte le sens, jamais le texte seul.
enum DuelloPillTone {
    case neutral, ink, light, success, warning, danger

    var foreground: Color {
        switch self {
        case .neutral: return Theme.inkSoft
        case .ink: return Theme.surface
        case .light: return Theme.ink
        case .success: return Theme.gradingPerfect
        case .warning: return Theme.gradingPartial
        case .danger: return Theme.like
        }
    }

    var background: Color {
        switch self {
        case .neutral: return Theme.surfaceMuted
        case .ink: return Theme.ink
        case .light: return Theme.primaryLight
        case .success: return Theme.gradingPerfectLight
        case .warning: return Theme.gradingPartialLight
        case .danger: return Theme.like.opacity(0.12)
        }
    }

    /// Étiquette : la pastille « MOI » (`meBadge`, RankingsScreen.tsx:956) est
    /// minuscule et très grasse (7 / `900` / `letterSpacing: 0.6`) ; toutes les
    /// autres suivent `itemTagText` (SubjectsScreen.tsx:12244 : 10 / `800`).
    var font: Font {
        self == .ink
            ? .system(size: 7, weight: .black)
            : .system(size: 10, weight: .heavy)
    }

    var tracking: CGFloat { self == .ink ? 0.6 : 0 }

    /// Marges : `meBadge` 6 / 3 ; `itemTag` 8 / 4.
    var horizontalPadding: CGFloat { self == .ink ? 6 : 8 }
    var verticalPadding: CGFloat { self == .ink ? 3 : 4 }
}

/// Pastille compacte (statut, matière, catégorie).
struct DuelloPill: View {
    let text: String
    var tone: DuelloPillTone = .neutral
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(tone.font)
                .tracking(tone.tracking)
                .textCase(.uppercase)
        }
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, tone.horizontalPadding)
        .padding(.vertical, tone.verticalPadding)
        .background(tone.background)
        .clipShape(Capsule())
    }
}

// MARK: - Avatars

/// Avatar rond à initiale, repli sur une icône quand le profil est vide.
struct DuelloAvatar: View {
    let initial: String
    var size: CGFloat = 44
    var background: Color = Theme.primaryLight
    var foreground: Color = Theme.inkSoft

    var body: some View {
        ZStack {
            Circle().fill(background).frame(width: size, height: size)
            if initial.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(foreground)
            } else {
                Text(initial)
                    .font(.system(size: size * 0.4, weight: .black))
                    .foregroundStyle(foreground)
            }
        }
    }
}

// MARK: - État vide

/// État vide centré, icône + titre + explication facultative.
struct DuelloEmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Statistiques

/// Tuile de statistique : libellé, valeur, progression facultative.
struct DuelloStatTile: View {
    let label: String
    let value: String
    var fraction: Double? = nil
    var tint: Color = Theme.progress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkFaint)
            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.ink)
            if let fraction {
                DuelloProgressTrack(fraction: fraction, tint: tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
    }
}

/// Barre de progression fine.
struct DuelloProgressTrack: View {
    let fraction: Double
    var tint: Color = Theme.progress
    /// Fond de la piste : `colors.surfaceMuted` par défaut
    /// (`AffiliateMilestoneProgress.tsx:191`), `colors.border` pour le suivi de
    /// copie (`AnnaleCopyCorrectionModal.tsx:320`).
    var track: Color = Theme.surfaceMuted
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Puces et lignes

/// Puce sélectionnable, utilisée pour les filtres et les choix rapides.
///
/// Motif RN : pastille `surfaceMuted` (jamais de bordure), libellé 11 / `800`
/// `mutedSurfaceText`, sélection peinte en `primary` avec libellé blanc
/// (`chip` / `compactChip` + `chartFilterChip` + `chipText` / `documentTab`,
/// AccountScreen.tsx:5348-5422, AnnaleViewer.tsx:5259).
struct DuelloChip: View {
    let title: String
    let selected: Bool
    /// Hauteur minimale : 34 pour un filtre de graphique (`chartFilterChip`),
    /// 30 pour un onglet de document (`documentTab`).
    var minHeight: CGFloat = 34
    /// Marge horizontale : 13 (`chartFilterChip`), 14 (`documentTab`).
    var paddingHorizontal: CGFloat = 13
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .lineLimit(1)
                .foregroundStyle(selected ? Theme.surface : Theme.inkSoft)
                .padding(.horizontal, paddingHorizontal)
                .frame(minHeight: minHeight)
                .background(selected ? Theme.ink : Theme.surfaceMuted)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Ligne de liste avec icône, titre, sous-titre et chevron facultatif.
struct DuelloListRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var trailing: String? = nil
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// Ligne d'information libellé/valeur, pour les récapitulatifs.
struct DuelloInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Graphiques (Swift Charts, iOS 16+)

/// Un point d'une série de graphique.
struct DuelloChartPoint: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: Double
}

/// Graphique en barres simple (XP, notes, temps par matière).
struct DuelloBarChart: View {
    let points: [DuelloChartPoint]
    var tint: Color = Theme.ink

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Catégorie", point.label),
                y: .value("Valeur", point.value)
            )
            .foregroundStyle(tint)
            .cornerRadius(4)
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 180)
    }
}

/// Graphique en courbe simple (évolution XP, ELO, moyenne).
struct DuelloLineChart: View {
    let points: [DuelloChartPoint]
    var tint: Color = Theme.progress

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Étape", point.label),
                y: .value("Valeur", point.value)
            )
            .foregroundStyle(tint)
            .interpolationMethod(.catmullRom)
            PointMark(
                x: .value("Étape", point.label),
                y: .value("Valeur", point.value)
            )
            .foregroundStyle(tint)
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 180)
    }
}

/// Anneau de maîtrise (donut) avec valeur centrale.
struct DuelloDonut: View {
    let fraction: Double
    let centerText: String
    var tint: Color = Theme.progress
    var caption: String? = nil

    private var bounded: Double { max(0, min(1, fraction)) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Theme.border, lineWidth: 12)
                Circle()
                    .trim(from: 0, to: bounded)
                    .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(centerText)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: 120, height: 120)
            if let caption {
                Text(caption)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }
}

// MARK: - Utilitaires de couleur

extension Int {
    /// Convertit un code hexadécimal (`0xRRGGBB`) en couleur SwiftUI.
    var color: Color { Color(hex: self) }
}
