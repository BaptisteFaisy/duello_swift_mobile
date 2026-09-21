//
//  AcctEvoPill.swift
//  Duello
//
//  Pastille d'évolution de performance (lot 10-B, préfixe `AcctEvo`).
//
//  Fichier source Expo porté (noms et libellés repris mot pour mot) :
//    - src/screens/AccountScreen.tsx, lignes 405-479
//      (`evolutionSign`, `spokenEvolutionSign`, `absoluteEvolutionText`,
//       `absoluteEvolutionSpokenText`, `PerformanceEvolutionPill`)
//
//  Réutilise : `Theme`, `DuelloPillTone` (fond de la pastille neutre) et
//  `ExGFormat.xp` (équivalent Swift de `formatXp`). La vue `DuelloPill` n'est
//  pas employée ici : elle force la casse majuscule et une taille fixe, alors
//  que la pastille source est interactive et conserve « pt »/« Elo » en
//  minuscules.
//
//  Cible iOS 16 ; aucune dépendance externe.
//
import SwiftUI

/// Formateurs de libellés d'évolution (signes, textes visibles et parlés).
enum AcctEvoEvolutionFormat {
    /// `evolutionSign` — signe typographique ; le moins est U+2212.
    static func evolutionSign(_ value: Double) -> String {
        value > 0 ? "+" : (value < 0 ? "\u{2212}" : "")
    }

    /// `spokenEvolutionSign` — signe prononcé, pour VoiceOver.
    static func spokenEvolutionSign(_ value: Double) -> String {
        value > 0 ? "plus " : (value < 0 ? "moins " : "")
    }

    /// `absoluteEvolutionText` — magnitude dans l'unité (« XP », « Elo », « pt »).
    static func absoluteEvolutionText(_ value: Double, unit: AcctEvoPerformanceEvolutionUnit) -> String {
        let magnitude = abs(value)
        switch unit {
        case .xp: return "\(ExGFormat.xp(magnitude)) XP"
        case .elo: return "\(ExGFormat.xp(magnitude)) Elo"
        case .grade: return "\(ExGFormat.xp(magnitude)) pt"
        }
    }

    /// `absoluteEvolutionSpokenText` — variante parlée ; « point(s) » au pluriel
    /// dès que la magnitude dépasse 1.
    static func absoluteEvolutionSpokenText(_ value: Double, unit: AcctEvoPerformanceEvolutionUnit) -> String {
        let magnitude = abs(value)
        switch unit {
        case .xp: return "\(ExGFormat.xp(magnitude)) XP"
        case .elo: return "\(ExGFormat.xp(magnitude)) Elo"
        case .grade: return "\(ExGFormat.xp(magnitude)) point\(magnitude > 1 ? "s" : "")"
        }
    }
}

/// `PerformanceEvolutionPill` : la variation relative entre les deux dernières
/// périodes se lit au signe et à la flèche, jamais à la seule couleur. Un tap
/// bascule entre pourcentage relatif et écart absolu.
struct AcctEvoPerformanceEvolutionPill: View {
    let percentage: Double
    let absolute: Double
    let unit: AcctEvoPerformanceEvolutionUnit

    @State private var showingAbsolute = false

    private var value: Double { showingAbsolute ? absolute : percentage }

    private var valueText: String {
        showingAbsolute
            ? AcctEvoEvolutionFormat.absoluteEvolutionText(value, unit: unit)
            : "\(ExGFormat.xp(abs(value))) %"
    }

    private var spokenValue: String {
        showingAbsolute
            ? AcctEvoEvolutionFormat.absoluteEvolutionSpokenText(value, unit: unit)
            : "\(ExGFormat.xp(abs(value))) pour cent"
    }

    /// Flèche de sens : jamais affichée quand la variation est nulle.
    private var arrowSymbol: String? {
        value > 0 ? "arrow.up" : (value < 0 ? "arrow.down" : nil)
    }

    var body: some View {
        Button {
            showingAbsolute.toggle()
        } label: {
            HStack(spacing: 2) {
                if let arrowSymbol {
                    Image(systemName: arrowSymbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                Text(AcctEvoEvolutionFormat.evolutionSign(value) + valueText)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(DuelloPillTone.neutral.background)
            .clipShape(Capsule())
            // `hitSlop={6}` d'origine : cible tactile élargie sans décaler la mise en page.
            .padding(6)
            .contentShape(Rectangle())
            .padding(-6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Afficher l\u{2019}évolution \(showingAbsolute ? "relative" : "absolue")")
        .accessibilityLabel(
            "Évolution \(showingAbsolute ? "absolue" : "relative") : "
                + AcctEvoEvolutionFormat.spokenEvolutionSign(value) + spokenValue
        )
    }
}
