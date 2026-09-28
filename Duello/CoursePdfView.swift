import PDFKit
import SwiftUI
import UIKit

/// Lecteur PDF natif d'un document de chapitre.
///
/// L'app Expo compose ses pages avec PDF.js embarqué (~3,3 Mo de JavaScript
/// livré avec le bundle, `src/utils/courseDocumentPdf.ts`) : ce moteur n'est
/// pas portable — aucune dépendance externe. iOS rend les PDF nativement,
/// page par page, ce qui remplace PDF.js sans changer le contrat du lecteur
/// (`CourseDocumentViewer.native.tsx`) : le repère rouge (`positioning`) suit le
/// défilement et publie `position` (`courseDocumentPdf.ts:93-140`).
struct CtdPdfDocumentView: UIViewRepresentable {
    let data: Data
    var positioning: Bool = false
    var initialPosition: Double? = nil
    var onPositionChange: ((Double) -> Void)? = nil
    var onReady: (() -> Void)? = nil
    var onComplete: (() -> Void)? = nil

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(data: data)
        context.coordinator.positioning = positioning
        context.coordinator.onPositionChange = onPositionChange
        context.coordinator.onReady = onReady
        context.coordinator.onComplete = onComplete
        // La vue de défilement interne n'existe qu'après la pose du document :
        // on l'observe au tour suivant de la boucle principale.
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            coordinator.attach(to: view, initialPosition: initialPosition)
            onReady?()
            onComplete?()
        }
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.positioning = positioning
        context.coordinator.onPositionChange = onPositionChange
        context.coordinator.updateMarker(in: view)
        guard view.document == nil else { return }
        view.document = PDFDocument(data: data)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIView(_ view: PDFView, coordinator: Coordinator) {
        coordinator.detach()
    }

    /// Observe le défilement du document et pose le repère rouge (`positioning`).
    final class Coordinator {
        var positioning = false
        var onPositionChange: ((Double) -> Void)?
        var onReady: (() -> Void)?
        var onComplete: (() -> Void)?
        private var observation: NSKeyValueObservation?
        private weak var scrollView: UIScrollView?
        private var marker: UIView?

        /// Retrouve la `UIScrollView` interne de `PDFView` (aucune API publique).
        private static func scrollingView(in view: UIView) -> UIScrollView? {
            if let scroll = view as? UIScrollView { return scroll }
            for subview in view.subviews {
                if let found = scrollingView(in: subview) { return found }
            }
            return nil
        }

        func attach(to pdfView: PDFView, initialPosition: Double?) {
            guard let scroll = Self.scrollingView(in: pdfView) else { return }
            scrollView = scroll
            observation = scroll.observe(\.contentOffset, options: [.new]) { [weak self] scroll, _ in
                self?.reportPosition(scroll)
            }
            if let initialPosition, initialPosition > 0, scroll.contentSize.height > 0 {
                let offset = CGFloat(initialPosition) * scroll.contentSize.height - scroll.bounds.height / 2
                scroll.setContentOffset(CGPoint(x: 0, y: max(0, offset)), animated: false)
            }
            updateMarker(in: pdfView)
        }

        func detach() {
            observation?.invalidate()
            observation = nil
            marker?.removeFromSuperview()
            marker = nil
        }

        /// Position (0…1) du centre de l'écran dans le document.
        private func reportPosition(_ scroll: UIScrollView) {
            guard positioning, scroll.contentSize.height > 0 else { return }
            let markerY = scroll.contentOffset.y + scroll.bounds.height / 2
            let position = min(1, max(0, Double(markerY / scroll.contentSize.height)))
            onPositionChange?(position)
        }

        /// Repère rouge `#D32020` posé au centre droit de la vue
        /// (`positionMarker`, `CourseDocumentViewer.native.tsx:206-220`).
        func updateMarker(in pdfView: PDFView) {
            marker?.removeFromSuperview()
            marker = nil
            guard positioning else { return }
            let bar = UIView()
            bar.backgroundColor = UIColor(red: 0xD3 / 255, green: 0x20 / 255, blue: 0x20 / 255, alpha: 1)
            bar.translatesAutoresizingMaskIntoConstraints = false
            pdfView.addSubview(bar)
            NSLayoutConstraint.activate([
                bar.trailingAnchor.constraint(equalTo: pdfView.trailingAnchor),
                bar.centerYAnchor.constraint(equalTo: pdfView.centerYAnchor),
                bar.widthAnchor.constraint(equalToConstant: 42),
                bar.heightAnchor.constraint(equalToConstant: 3),
            ])
            marker = bar
        }
    }
}

/// Ouverture plein écran d'un document du chapitre.
///
/// Reprend le lecteur plein écran de la section « Mon cours » de
/// `SubjectsScreen.tsx` : en-tête blanc avec le seul bouton de réduction
/// (`courseFullscreenHeader`, `:11024-11034`) — aucun titre, contrairement au
/// portage antérieur — puis le lecteur sur toute la hauteur restante.
struct CtdDocumentSheet: View {
    let title: String
    let uri: String
    let mimeType: CtdMimeType
    let revision: Double
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Spacer(minLength: 8)
                Button(action: onClose) {
                    IonIcon(name: "contract-outline", size: 24, color: Theme.ink)
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
