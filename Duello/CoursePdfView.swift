import PDFKit
import SwiftUI

/// Lecteur PDF natif d'un document de chapitre.
///
/// L'app Expo compose ses pages avec PDF.js embarqué (~3,3 Mo de JavaScript
/// livré avec le bundle, `src/utils/courseDocumentPdf.ts`) : ce moteur n'est
/// pas portable — aucune dépendance externe. iOS rend les PDF nativement,
/// page par page, ce qui remplace PDF.js sans changer le contrat du lecteur
/// (`CourseDocumentViewer.native.tsx`). Le repère de progression de classe,
/// lui, reste hors de ce lecteur.
struct CtdPdfDocumentView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        guard view.document == nil else { return }
        view.document = PDFDocument(data: data)
    }
}

/// Ouverture plein écran d'un document du chapitre.
///
/// Reprend le lecteur plein écran de la section « Mon cours » de
/// `SubjectsScreen.tsx` : en-tête blanc, bouton de réduction, et le lecteur
/// sur toute la hauteur restante.
struct CtdDocumentSheet: View {
    let title: String
    let uri: String
    let mimeType: CtdMimeType
    let revision: Double
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Réduire le cours")
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(minHeight: 54)
            .background(Theme.surface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1)
            }

            CtdDocumentViewer(
                uri: uri,
                mimeType: mimeType,
                revision: revision,
                height: .infinity
            )
        }
        .background(Theme.surfaceMuted)
    }
}
