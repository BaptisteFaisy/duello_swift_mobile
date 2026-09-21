//
//  ReportStatementPager.swift
//  Duello
//
//  Lot « Report » — pages balayables d'un énoncé dans un même bloc.
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/question-report/StatementPager.tsx (StatementPager,
//                                                         StatementPage, PageDots)
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Une page d'énoncé (`StatementPage`) : le texte affiché par le paginateur.
struct ReportStatementPage: Identifiable, Equatable {
    let id: String
    let text: String
}

/// Pages balayables dans un même bloc (`StatementPager.tsx`) : la première
/// s'affiche par défaut, un glissement horizontal révèle la suivante. Les points
/// de repère ne s'affichent qu'à partir de deux pages, en haut du bloc.
///
/// Limite assumée : Expo ajuste la hauteur du bloc à la page visible ; ici le
/// bloc garde une hauteur fixe et chaque page défile verticalement si besoin.
struct ReportStatementPager: View {
    let pages: [ReportStatementPage]

    @State private var index = 0

    /// Hauteur du bloc (Expo suit la page visible, non reproduit ici).
    private static let pageHeight: CGFloat = 240

    /// Initialiseur explicite : un `@State` privé rend l'initialiseur membre
    /// synthétisé inaccessible à l'appelant.
    init(pages: [ReportStatementPage]) {
        self.pages = pages
    }

    var body: some View {
        VStack(spacing: 8) {
            if pages.count > 1 { dots }
            TabView(selection: $index) {
                ForEach(pages.indices, id: \.self) { offset in
                    pageView(pages[offset]).tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: Self.pageHeight)
        }
    }

    private func pageView(_ page: ReportStatementPage) -> some View {
        ScrollView(showsIndicators: false) {
            Text(LatexToUnicode.toUnicodeMath(page.text))
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { offset in
                Circle()
                    .fill(offset == index ? Theme.inkSoft : Theme.border)
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}
