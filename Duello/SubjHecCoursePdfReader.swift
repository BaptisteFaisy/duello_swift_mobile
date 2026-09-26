//
//  SubjHecCoursePdfReader.swift
//  Duello
//
//  Lecteur du cours de maths de l'étape « génération » du parcours HEC guidé :
//  en-tête de page, pages factices et suivi de la position de lecture.
//
//  Fichiers source Expo portés :
//    - src/screens/SubjectsScreen.tsx (lignes 484-552)
//        `HecCoursePdfReader({ value, onChange })` : le `ScrollView` calcule
//        `min(1, max(0, contentOffset.y / (contentSize.height -
//        layoutMeasurement.height)))` à chaque défilement (`scrollEventThrottle`
//        16), trois pages sont empilées (`coursePdfPage`), chaque page porte son
//        numéro et un filet (`coursePdfPageHeader`), un titre, une formule
//        encadrée et six lignes de texte grises dont la dernière est plus
//        courte ; une glissière fixe (`coursePdfScrollRail`) porte un curseur
//        (`coursePdfScrollCursor`) positionné à `min(92, max(8, value * 100)) %`.
//    - src/screens/SubjectsScreen.tsx (lignes 547-549, 11858-11955)
//        légende sous le lecteur et styles associés.
//
//  Limite documentée : ce composant n'embarque **aucun moteur PDF** — le source
//  Expo lui-même dessine des pages factices (numéro, titre, formule, lignes
//  grises) et n'affiche pas le document réel ; le PDF du cours est traité côté
//  service pour produire les flashcards. Côté Swift, aucune dépendance externe
//  (PDFKit, SPM) n'est autorisée par le brief : seuls l'en-tête, les pages
//  factices et l'état de défilement sont portés. Brancher un vrai lecteur PDF
//  (PDFKit) reste hors périmètre.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

/// Mesures de défilement du cours, transmises par préférence.
struct SubjCoursePdfScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var contentHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0
}

/// Clé de préférence du défilement du cours (`onScroll` du source).
struct SubjCoursePdfOffsetKey: PreferenceKey {
    static var defaultValue: SubjCoursePdfScrollMetrics = SubjCoursePdfScrollMetrics()

    static func reduce(
        value: inout SubjCoursePdfScrollMetrics,
        nextValue: () -> SubjCoursePdfScrollMetrics
    ) {
        value = nextValue()
    }
}

/// Lecteur du cours de maths (`HecCoursePdfReader`), avec état de lecture lié.
struct SubjHecCoursePdfReader: View {
    /// Position de lecture, de 0 (début) à 1 (fin), écrite au défilement.
    @Binding var value: Double

    private static let spaceName = "subjCoursePdf"
    private static let pageCount = 3
    private static let readerHeight: CGFloat = 285
    private static let railInset: CGFloat = 12
    private static let cursorHeight: CGFloat = 24
    /// Bornes du curseur de glissière : `min(92, max(8, value * 100))`.
    private static let cursorPercentRange: ClosedRange<Double> = 8...92

    var body: some View {
        VStack(spacing: 10) {
            reader
            Text("Fais défiler le cours jusqu’à l’endroit où tu t’es arrêté en classe.")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Document du cours de mathématiques")
    }

    /// Cadre du cours : pages défilantes, glissière et suivi de position.
    private var reader: some View {
        GeometryReader { viewport in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(1...Self.pageCount, id: \.self) { page in
                        SubjCoursePdfPage(number: page)
                    }
                }
                .padding(12)
                .background(
                    GeometryReader { content in
                        Color.clear.preference(
                            key: SubjCoursePdfOffsetKey.self,
                            value: SubjCoursePdfScrollMetrics(
                                offset: -content.frame(in: .named(Self.spaceName)).minY,
                                contentHeight: content.size.height,
                                viewportHeight: viewport.size.height
                            )
                        )
                    }
                )
            }
            .coordinateSpace(name: Self.spaceName)
            .onPreferenceChange(SubjCoursePdfOffsetKey.self) { metrics in
                updateProgress(metrics)
            }
            .overlay(alignment: .trailing) { rail(readerHeight: viewport.size.height) }
        }
        .frame(height: Self.readerHeight)
        .background(Color(hex: 0xE9E9E7))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Glissière fixe et curseur centré sur la position de lecture.
    private func rail(readerHeight: CGFloat) -> some View {
        let railHeight = max(0, readerHeight - 2 * Self.railInset)
        let ratio = Self.clampedPercent(value) / 100
        let cursorY = min(
            max(0, railHeight * CGFloat(ratio) - Self.cursorHeight / 2),
            max(0, railHeight - Self.cursorHeight)
        )
        return ZStack(alignment: .top) {
            Capsule()
                .fill(Color(hex: 0xD4D4D0))
                .frame(width: 4, height: railHeight)
            Capsule()
                .fill(Theme.primary)
                .frame(width: 4, height: Self.cursorHeight)
                .offset(y: cursorY)
        }
        .frame(width: 12)
        .frame(maxHeight: .infinity, alignment: .center)
        .padding(.trailing, 3)
        .allowsHitTesting(false)
    }

    /// Reporte la fraction défilée dans la position de lecture.
    private func updateProgress(_ metrics: SubjCoursePdfScrollMetrics) {
        let scrollable = metrics.contentHeight - metrics.viewportHeight
        guard scrollable > 0 else { return }
        value = min(1, max(0, Double(metrics.offset / scrollable)))
    }

    /// Pourcentage du curseur, borné comme dans le source.
    static func clampedPercent(_ value: Double) -> Double {
        min(cursorPercentRange.upperBound, max(cursorPercentRange.lowerBound, value * 100))
    }
}

/// Une page factice du cours (`coursePdfPage`) : numéro, filet, titre, formule
/// encadrée et lignes de texte grises, la dernière plus courte.
struct SubjCoursePdfPage: View {
    let number: Int

    private static let lineCount = 6
    private static let lineHeight: CGFloat = 7
    private static let lineSpacing: CGFloat = 13
    private static let shortLineRatio: CGFloat = 0.66
    private static let fullLineRatio: CGFloat = 0.94

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("PAGE \(number)")
                    .font(.system(size: 8, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(Theme.inkFaint)
                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1)
            }
            Text("Cours de mathématiques — chapitre")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.ink)
                .padding(.top, 22)
            Text("f(x) = x² + 2x + 1")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(Color(hex: 0xF5F5F3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.vertical, 22)
            textLines
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 360, alignment: .top)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .duelloShadow()
    }

    private var textLines: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: Self.lineSpacing) {
                ForEach(1...Self.lineCount, id: \.self) { line in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: 0xE3E3E0))
                        .frame(
                            width: geo.size.width * (line == Self.lineCount
                                ? Self.shortLineRatio
                                : Self.fullLineRatio),
                            height: Self.lineHeight
                        )
                }
            }
        }
        .frame(
            height: CGFloat(Self.lineCount) * Self.lineHeight
                + CGFloat(Self.lineCount - 1) * Self.lineSpacing
        )
    }
}
