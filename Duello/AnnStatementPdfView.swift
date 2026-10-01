//
//  AnnStatementPdfView.swift
//  Duello
//
//  Énoncé PDF d'une annale (vague 8, parité Swift↔RN) : la page du sujet
//  découpée à `sourceRegion`, extraite de `AnnReaderContent.swift` pour tenir
//  les limites de complexité du dépôt (500 lignes/fichier, 50 lignes/fonction).
//
//  Cible : iOS 16.
//
import SwiftUI
#if os(iOS)
import PDFKit
import UIKit
#endif

// MARK: - Énoncé PDF d'une annale

/// `pdfPageHtml` (`AnnaleViewer.tsx:444-455`) : la page `sourcePage` du PDF
/// d'énoncé, découpée à la bande `sourceRegion` (fractions de hauteur depuis le
/// haut de la page). Une bande absente ou dégénérée (`bas - haut <= 0,02`) rend
/// la page entière — « Une bande dégénérée vaudrait une page blanche : mieux
/// vaut tout montrer. »
///
/// PDFKit remplace PDF.js. Le PDF embarqué (`sourceAsset`, identifiant de
/// module Expo) n'a pas de registre d'assets côté iOS : le lecteur part de
/// `sourceUrl`.
struct AnnStatementPdfView: View {
    let url: URL
    let pageNumber: Int
    let region: AnnSourceRegion?

    var body: some View {
        #if os(iOS)
        AnnStatementPdfPage(url: url, pageNumber: pageNumber, region: region)
        #else
        AnnStatementPdfUnavailable()
        #endif
    }
}

/// État d'indisponibilité du document (`styles.loading` en échec de la source) :
/// icône hors-ligne, « Document indisponible » et invite à réessayer.
struct AnnStatementPdfUnavailable: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            IonIcon(name: "cloud-offline-outline", size: 36, color: Theme.inkFaint)
            Text("Document indisponible")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
            Text("Vérifie ta connexion, puis réessaie.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }
}

#if os(iOS)
/// Rendu PDFKit d'une page d'énoncé : la page est composée **en entier** puis
/// rognée à la bande demandée (`translate(0, -debut)`, hauteur de la bande de
/// `pdfPageHtml`). Le PDF est lu directement depuis `sourceUrl`.
private struct AnnStatementPdfPage: View {
    let url: URL
    let pageNumber: Int
    let region: AnnSourceRegion?

    @State private var image: UIImage?
    @State private var failed = false

    /// Bornes de largeur de capture de `pdfPageHtml` : « 1 200 px suffisent à
    /// lire les formules d'une page » ; borner à 1 600 évite qu'une tablette
    /// Retina envoie une image inutilement lourde.
    private static let captureMin: CGFloat = 1200
    private static let captureMax: CGFloat = 1600

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    // `canvas { background: white; box-shadow: 0 2px 12px rgba(10,13,12,.12) }`.
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    .shadow(color: Color(hex: 0x0A0D0C).opacity(0.12),
                            radius: 6, x: 0, y: 2)
            } else if failed {
                AnnStatementPdfUnavailable()
            } else {
                Text("Préparation du document…")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: url) { await render() }
    }

    /// Lit le PDF (fichier local ou lien téléchargé, comme la source), puis
    /// publie la bande composée de la page demandée.
    private func render() async {
        failed = false
        image = nil
        guard let document = await loadDocument() else {
            failed = true
            return
        }
        let index = min(max(pageNumber, 1), document.pageCount) - 1
        guard let page = document.page(at: index) else {
            failed = true
            return
        }
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else {
            failed = true
            return
        }
        guard let composed = Self.composeBand(page: page, bounds: bounds, region: region) else {
            failed = true
            return
        }
        image = composed
    }

    /// Lit le PDF depuis `sourceUrl` (fichier local ou lien téléchargé, comme la
    /// source) et retourne le document, ou `nil` en cas d'échec.
    private func loadDocument() async -> PDFDocument? {
        let data: Data
        if url.isFileURL {
            guard let loaded = try? Data(contentsOf: url) else { return nil }
            data = loaded
        } else {
            guard let (fetched, _) = try? await URLSession.shared.data(from: url) else { return nil }
            data = fetched
        }
        guard let document = PDFDocument(data: data), document.pageCount > 0 else { return nil }
        return document
    }

    /// Compose la page **en entier** au canevas puis la rogne à la bande
    /// demandée (`pdfPageHtml`), ou `nil` si l'image ne peut pas être produite.
    private static func composeBand(page: PDFPage, bounds: CGRect,
                                    region: AnnSourceRegion?) -> UIImage? {
        // `captureWidth = min(max(cssWidth * pixelRatio, 1200), 1600)`.
        let pixelRatio = min(UIScreen.main.scale, 2)
        let cssWidth = max(280, UIScreen.main.bounds.width - 24)
        let captureWidth = min(max(cssWidth * pixelRatio, captureMin), captureMax)
        let scale = captureWidth / bounds.width
        let size = CGSize(width: (bounds.width * scale).rounded(),
                          height: (bounds.height * scale).rounded())
        let full = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.saveGState()
            // La page est rendue en entier, remontée de la hauteur découpée : le
            // canevas ne garde alors que la bande de l'exercice.
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }
        let band = bandRect(region: region, size: size)
        guard let cropped = full.cgImage?.cropping(to: band) else { return nil }
        return UIImage(cgImage: cropped)
    }

    /// Rectangle de découpe dans l'image composée : la bande `region` seulement
    /// si `bas - haut > 0,02`, la page entière sinon.
    private static func bandRect(region: AnnSourceRegion?, size: CGSize) -> CGRect {
        let haut = min(max(region?.haut ?? 0, 0), 1)
        let bas = min(max(region?.bas ?? 1, haut), 1)
        guard region != nil, bas - haut > 0.02 else {
            return CGRect(origin: .zero, size: size)
        }
        return CGRect(x: 0,
                      y: (size.height * CGFloat(haut)).rounded(),
                      width: size.width,
                      height: (size.height * CGFloat(bas - haut)).rounded())
    }
}
#endif
