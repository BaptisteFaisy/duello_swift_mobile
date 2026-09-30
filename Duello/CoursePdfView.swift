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
///
/// Parité (2026-09-29) — « calque de sélection » + bouton « Expliquer » : PDF.js
/// compose chaque page en canvas puis pose par-dessus un calque de texte
/// sélectionnable (`profTextLayer.ts:1-45`), dont la sélection part au prof IA
/// via le pont `profSelectionBridge.ts` (`courseDocumentPdf.ts:50,83,188-189`).
/// PDFKit offre nativement cette sélection : le lecteur publie le passage
/// sélectionné (`onExplain(text, page)`) et pose un bouton « Expliquer ce
/// passage » au-dessus. Le passage est borné par le relais (`clampProfQuote`).
///
/// Cible : iOS 16. Aucune dépendance externe.

/// Sélection courante du lecteur PDF, publiée vers le prof IA.
struct ProfPdfSelection: Equatable {
    var text: String
    var page: Int?
    /// Cadre de la sélection, dans le repère du lecteur (pour poser le bouton).
    var rect: CGRect
}

/// Lecteur d'un document de chapitre : `PDFView` natif, repère de position et
/// bouton « Expliquer ce passage » posé sur la sélection courante.
struct CtdPdfDocumentView: View {
    let data: Data
    var positioning: Bool = false
    var initialPosition: Double? = nil
    var onPositionChange: ((Double) -> Void)? = nil
    var onReady: (() -> Void)? = nil
    var onComplete: (() -> Void)? = nil
    /// Fourni : la sélection courante ouvre le prof IA (`duello-prof-explain`).
    var onExplain: ((String, Int?) -> Void)? = nil
    /// Fourni : le document n'a pas pu être ouvert (`PDFDocument(data:)` nul,
    /// PDF corrompu) → le lecteur bascule en échec + « Réessayer »
    /// (`CourseDocumentViewer.native.tsx:152-165`).
    var onError: (() -> Void)? = nil

    /// Sélection courante, alimentée par `PDFViewSelectionChanged`.
    @State private var selection: ProfPdfSelection?

    var body: some View {
        ZStack(alignment: .topLeading) {
            CtdPdfKitView(
                data: data,
                positioning: positioning,
                initialPosition: initialPosition,
                onPositionChange: onPositionChange,
                onReady: onReady,
                onComplete: onComplete,
                onError: onError,
                selection: $selection
            )
            if onExplain != nil { explainButton }
        }
    }

    /// « Expliquer ce passage » : posé au-dessus de la sélection courante,
    /// style du pont de la source (fond `#0A0D0C`, pastille verte `#22C55E`).
    @ViewBuilder private var explainButton: some View {
        if let selection {
            Button {
                onExplain?(selection.text, selection.page)
                self.selection = nil
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color(hex: 0x22C55E))
                        .frame(width: 7, height: 7)
                    Text("Expliquer ce passage")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.white)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .background(Theme.ink)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .position(x: selection.rect.midX, y: max(22, selection.rect.minY - 22))
            .accessibilityLabel("Expliquer ce passage")
        }
    }
}

/// Pont UIKit : `PDFView` natif, repère de position (`positioning`) et
/// sélection publiée vers le prof IA.
private struct CtdPdfKitView: UIViewRepresentable {
    let data: Data
    var positioning: Bool = false
    var initialPosition: Double? = nil
    var onPositionChange: ((Double) -> Void)? = nil
    var onReady: (() -> Void)? = nil
    var onComplete: (() -> Void)? = nil
    var onError: (() -> Void)? = nil
    @Binding var selection: ProfPdfSelection?

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        // Un PDF corrompu fait rendre `PDFDocument(data:)` nul : sans ce
        // contrôle, la zone restait vide, sans erreur ni essai
        // (`courseDocumentPdf.ts:219-230`).
        let document = PDFDocument(data: data)
        view.document = document
        context.coordinator.positioning = positioning
        context.coordinator.onPositionChange = onPositionChange
        context.coordinator.onReady = onReady
        context.coordinator.onComplete = onComplete
        context.coordinator.onSelection = { self.selection = $0 }
        // La vue de défilement interne n'existe qu'après la pose du document :
        // on l'observe au tour suivant de la boucle principale.
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            guard document != nil else {
                onError?()
                return
            }
            coordinator.attach(to: view, initialPosition: initialPosition)
            onReady?()
            onComplete?()
        }
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.positioning = positioning
        context.coordinator.onPositionChange = onPositionChange
        context.coordinator.onSelection = { self.selection = $0 }
        context.coordinator.updateMarker(in: view)
        guard view.document == nil else { return }
        view.document = PDFDocument(data: data)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIView(_ view: PDFView, coordinator: Coordinator) {
        coordinator.detach()
    }

    /// Observe le défilement du document (repère rouge) et la sélection
    /// (calque de sélection du prof IA).
    final class Coordinator {
        var positioning = false
        var onPositionChange: ((Double) -> Void)?
        var onReady: (() -> Void)?
        var onComplete: (() -> Void)?
        var onSelection: ((ProfPdfSelection?) -> Void)?
        private var observation: NSKeyValueObservation?
        private var selectionObserver: NSObjectProtocol?
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
            // Calque de sélection : la sélection courante part au prof IA
            // (miroir du pont `profSelectionBridge` de la source).
            selectionObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name.PDFViewSelectionChanged,
                object: pdfView,
                queue: .main
            ) { [weak self, weak pdfView] _ in
                guard let self, let pdfView else { return }
                guard let selection = pdfView.currentSelection,
                      let page = selection.pages.first,
                      let text = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty
                else {
                    self.onSelection?(nil)
                    return
                }
                self.onSelection?(ProfPdfSelection(
                    text: text,
                    page: (pdfView.document?.index(for: page) ?? 0) + 1,
                    rect: pdfView.convert(selection.bounds(for: page), from: page)
                ))
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
            if let selectionObserver {
                NotificationCenter.default.removeObserver(selectionObserver)
            }
            selectionObserver = nil
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
