import SwiftUI
import Foundation

/// Tableau blanc du mode entraînement, porté de :
/// - `src/components/Whiteboard.native.tsx` (document canvas, encre unique,
///   pincement à deux doigts) ;
/// - `src/components/whiteboardModel.ts` (encodage du brouillon) ;
/// - `src/components/WhiteboardHistoryControls.tsx` (barre d’outils + historique).
///
/// Écarts assumés par rapport à la source :
/// - **Pas de WebView ni de moteur d’encre** : rendu `Canvas` SwiftUI et un
///   `DragGesture` unique aiguillé par le mode (jamais deux gestes concurrents).
/// - **Pincement** : `MagnificationGesture` (iOS 16 ne fournit pas le point
///   d’appui du geste), donc le zoom est centré sur le plateau, bornes 0,5–4
///   comme la source (`MIN_SCALE`/`MAX_SCALE`).
///
/// La source ne dessine qu’en `#172554`, trait 2 : ni palette ni gomme.

// MARK: - Modèle

/// Un point du brouillon, repris de `WhiteboardPoint`.
struct WbPoint: Codable, Hashable {
    var x: Double
    var y: Double
}

/// Un tracé du brouillon. La source (`WhiteboardStroke`) ne porte que `points` :
/// `id` est un **ajout du portage** (identité SwiftUI) et n’est jamais
/// sérialisé — seuls `points` partent dans le JSON, conformément au format
/// d’origine.
struct WbStroke: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var points: [WbPoint]

    private enum CodingKeys: String, CodingKey {
        case points
    }
}

extension WbStroke {
    /// Décode un tracé depuis le format source (`{"points":[…]}`) : `id` est
    /// **régénéré**, la source ne transmettant que les points.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        points = try container.decode([WbPoint].self, forKey: .points)
        id = UUID()
    }
}

/// Encodage du brouillon, porté de `whiteboardModel.ts`.
enum WbCodec {
    static let prefix = "__PREPAPP_WHITEBOARD__:"

    /// Chaîne vide si aucune trace, sinon préfixe + tableau JSON des tracés.
    static func encode(_ strokes: [WbStroke]) -> String {
        guard !strokes.isEmpty,
              let data = try? JSONEncoder().encode(strokes),
              let json = String(data: data, encoding: .utf8) else { return "" }
        return prefix + json
    }

    static func isWhiteboardAnswer(_ answer: String) -> Bool {
        answer.hasPrefix(prefix)
    }

    /// `[]` si le préfixe manque ou si le JSON est invalide.
    static func decode(_ answer: String) -> [WbStroke] {
        guard isWhiteboardAnswer(answer) else { return [] }
        let json = String(answer.dropFirst(prefix.count))
        guard let data = json.data(using: .utf8),
              let strokes = try? JSONDecoder().decode([WbStroke].self, from: data) else { return [] }
        return normalize(strokes)
    }

    /// Écarte les tracés dont un point n’est pas fini (NaN / infini).
    static func normalize(_ strokes: [WbStroke]) -> [WbStroke] {
        strokes.filter { $0.points.allSatisfy { $0.x.isFinite && $0.y.isFinite } }
    }
}

// MARK: - Mesures

/// Mesures et constantes du tableau blanc, reprises de la source : encre
/// `#172554`, trait `2`, fond blanc, échelle bornée 0,5–4.
enum WbPalette {
    static let inkHex = 0x172554
    static let brushWidth: Double = 2
    static let backgroundHex = 0xFFFFFF
    /// `MIN_SCALE` (`Whiteboard.native.tsx:58`).
    static let minScale: CGFloat = 0.5
    /// `MAX_SCALE` (`Whiteboard.native.tsx:59`).
    static let maxScale: CGFloat = 4
}

/// Mode d’interaction du plateau (`WhiteboardInteractionMode`) : `draw` / `pan`.
enum WbTool {
    case draw, pan
}

// MARK: - Historique

/// Historique annuler / rétablir, reproduisant `useWhiteboardHistory`.
///
/// Annuler retire le dernier tracé et l’empile pour rétablir ; rétablir le
/// ré-ajoute ; **un nouveau tracé vide la pile de rétablissement** ; **une
/// nouvelle valeur reçue de l’extérieur** (changement de brouillon) vide aussi
/// la pile, pour ne jamais rétablir un trait du dessin précédent.
final class WbHistoryModel: ObservableObject {
    @Published private(set) var canRedo = false

    private var strokes: [WbStroke] = []
    private var redoStack: [WbStroke] = []
    private var previous = ""
    private var expected: String?

    /// Appelé quand l’historique modifie le dessin (tracé, annuler, rétablir).
    var onChange: (([WbStroke]) -> Void)?

    var canUndo: Bool { !strokes.isEmpty }

    /// Enregistre un dessin. `external: true` signale une valeur reçue du
    /// parent (changement de brouillon) : on vide alors la pile de rétablissement
    /// sans rappeler `onChange`, pour ne pas boucler.
    func recordDrawing(_ next: [WbStroke], external: Bool = false) {
        let value = WbCodec.encode(next)
        if external {
            if value == previous { return }
            previous = value
            if value == expected { expected = nil; return }
            expected = nil
            redoStack = []
            canRedo = false
            strokes = next
            return
        }
        redoStack = []
        canRedo = false
        strokes = next
        previous = value
        expected = value
        onChange?(next)
    }

    func undo() {
        guard let removed = strokes.last else { return }
        redoStack.append(removed)
        canRedo = true
        let next = Array(strokes.dropLast())
        strokes = next
        previous = WbCodec.encode(next)
        expected = previous
        onChange?(next)
    }

    func redo() {
        guard let restored = redoStack.popLast() else { return }
        canRedo = !redoStack.isEmpty
        let next = strokes + [restored]
        strokes = next
        previous = WbCodec.encode(next)
        expected = previous
        onChange?(next)
    }
}

/// Calque des tracés validés. `Equatable` : via `.equatable()`, il n'est pas
/// redessiné pendant la saisie du brouillon — seul le décalage ou le zoom (mode
/// « Déplacer », pincement) ou la liste des tracés validés le relance.
/// `.drawingGroup()` rasterise l'ensemble des tracés validés en une seule passe.
private struct WbCommittedLayer: View, Equatable {
    let strokes: [WbStroke]
    let offset: CGSize
    let scale: CGFloat

    var body: some View {
        Canvas { context, _ in
            context.translateBy(x: offset.width, y: offset.height)
            context.scaleBy(x: scale, y: scale)
            for stroke in strokes {
                WbCanvas.draw(stroke, into: &context)
            }
        }
        .drawingGroup()
    }
}

// MARK: - Plateau

/// Zone de dessin : `Canvas` + un `DragGesture` aiguillé par le mode, et un
/// pincement à deux doigts pour le zoom (`Whiteboard.native.tsx:149-239`).
struct WbCanvas: View {
    let strokes: [WbStroke]
    let tool: WbTool
    let onStrokesChange: ([WbStroke]) -> Void

    @State private var draft: [WbPoint] = []
    @State private var offset: CGSize = .zero
    @State private var panBase: CGSize = .zero
    @State private var scale: CGFloat = 1
    @State private var scaleBase: CGFloat = 1

    var body: some View {
        // Rendu incrémental : les tracés validés vivent dans un calque
        // `Equatable` qui n'est pas redessiné pendant que le brouillon évolue ;
        // seule la couche du brouillon est reconstruite à chaque point.
        ZStack {
            WbCommittedLayer(strokes: strokes, offset: offset, scale: scale)
                .equatable()
            Canvas { context, _ in
                guard !draft.isEmpty else { return }
                context.translateBy(x: offset.width, y: offset.height)
                context.scaleBy(x: scale, y: scale)
                WbCanvas.draw(WbStroke(points: draft), into: &context)
            }
        }
        .background(Color(hex: WbPalette.backgroundHex))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { handle($0, isEnd: false) }
                .onEnded { handle($0, isEnd: true) }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = min(WbPalette.maxScale, max(WbPalette.minScale, scaleBase * value))
                }
                .onEnded { _ in scaleBase = scale }
        )
    }

    /// Dessine un tracé dans un contexte (chemin lissé, ou pastille si le tracé
    /// n'a qu'un point). Extrait pour être partagé par les deux calques.
    static func draw(_ stroke: WbStroke, into context: inout GraphicsContext) {
        let points = stroke.points
        guard let first = points.first else { return }
        let color = Color(hex: WbPalette.inkHex)
        if points.count == 1 {
            let radius = WbPalette.brushWidth / 2
            let frame = CGRect(x: first.x - radius, y: first.y - radius, width: WbPalette.brushWidth, height: WbPalette.brushWidth)
            context.fill(Path(ellipseIn: frame), with: .color(color))
            return
        }
        var path = Path()
        path.move(to: CGPoint(x: first.x, y: first.y))
        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let middle = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
            path.addQuadCurve(to: middle, control: CGPoint(x: previous.x, y: previous.y))
        }
        if let last = points.last { path.addLine(to: CGPoint(x: last.x, y: last.y)) }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: WbPalette.brushWidth, lineCap: .round, lineJoin: .round))
    }

    /// Aiguillage du geste par le mode. Le pincement (zoom) est traité à part.
    private func handle(_ value: DragGesture.Value, isEnd: Bool) {
        switch tool {
        case .pan:
            if isEnd {
                panBase = offset
            } else {
                offset = CGSize(width: panBase.width + value.translation.width, height: panBase.height + value.translation.height)
            }
        case .draw:
            if isEnd {
                guard !draft.isEmpty else { return }
                let stroke = WbStroke(points: draft)
                draft = []
                onStrokesChange(strokes + [stroke])
            } else {
                let point = WbPoint(
                    x: (value.location.x - offset.width) / scale,
                    y: (value.location.y - offset.height) / scale
                )
                if draft.isEmpty {
                    draft = [point]
                } else if let last = draft.last, hypot(point.x - last.x, point.y - last.y) >= 0.5 {
                    draft.append(point)
                }
            }
        }
    }
}

// MARK: - Barre d’outils

/// Barre d’outils du tableau blanc, portée de `WhiteboardHistoryControls.tsx` :
/// deux modes (Dessiner / Déplacer), annuler, rétablir, agrandir.
struct WbToolbar: View {
    @Binding var tool: WbTool
    let canUndo: Bool
    let canRedo: Bool
    let expanded: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onToggleExpanded: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            WbModeButton(title: "Dessiner", icon: "pencil-outline", selected: tool == .draw) { tool = .draw }
                .accessibilityLabel("Dessiner sur le tableau blanc")
            WbModeButton(title: "Déplacer", icon: "hand-left-outline", selected: tool == .pan) { tool = .pan }
                .accessibilityLabel("Se déplacer dans le tableau blanc")
                .accessibilityHint("Fais glisser le tableau sans écrire")
            Spacer(minLength: 0)
            WbIconButton(icon: "arrow-undo-outline", label: "Annuler le dernier trait", enabled: canUndo, action: onUndo)
            WbIconButton(icon: "arrow-redo-outline", label: "Rétablir le dernier trait", enabled: canRedo, action: onRedo)
            WbIconButton(
                icon: expanded ? "contract-outline" : "expand-outline",
                label: expanded ? "Réduire le tableau blanc" : "Agrandir le tableau blanc",
                prominent: true,
                action: onToggleExpanded
            )
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(Theme.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Outils du tableau blanc")
    }
}

/// Bouton de mode (Dessiner / Déplacer) : icône Ionicons 16, libellé 9
/// (`modeButton`, `WhiteboardHistoryControls.tsx:126-168`).
struct WbModeButton: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                IonIcon(name: icon, size: 16, color: selected ? Theme.surface : Theme.primary)
                Text(title).font(.system(size: 9, weight: .heavy)).lineLimit(1)
            }
            .foregroundStyle(selected ? Theme.surface : Theme.primary)
            .padding(.horizontal, 7)
            .frame(minHeight: 32)
            .background(selected ? Theme.primary : Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Écran

/// Le tableau blanc complet : barre d’outils, plateau et historique.
/// Mesures reprises de la source : plateau `minHeight 158`, marge 8, rayon 8,
/// canvas `minHeight 116`.
struct WhiteboardView: View {
    @Binding var strokes: [WbStroke]
    var expanded: Bool = false
    var onToggleExpanded: () -> Void = {}
    var onChange: (([WbStroke]) -> Void)? = nil

    @StateObject private var history = WbHistoryModel()
    @State private var tool: WbTool = .draw

    /// Aide d’accessibilité du plateau (`Whiteboard.native.tsx:367-371`), qui
    /// mentionne le pincement à deux doigts.
    private var hint: String {
        switch tool {
        case .draw: return "Fais glisser ton doigt ou ton stylet pour dessiner. Pince avec deux doigts pour zoomer ou dézoomer."
        case .pan: return "Fais glisser le tableau pour te déplacer sans écrire. Pince avec deux doigts pour zoomer ou dézoomer."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            WbToolbar(
                tool: $tool,
                canUndo: history.canUndo,
                canRedo: history.canRedo,
                expanded: expanded,
                onUndo: { history.undo() },
                onRedo: { history.redo() },
                onToggleExpanded: onToggleExpanded
            )
            WbCanvas(
                strokes: strokes,
                tool: tool,
                onStrokesChange: { history.recordDrawing($0) }
            )
            .frame(minHeight: 116)
        }
        .frame(maxWidth: .infinity, minHeight: 158, alignment: .top)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        .padding(8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tableau blanc")
        .accessibilityHint(hint)
        .onAppear {
            history.onChange = onChange
            history.recordDrawing(strokes, external: true)
        }
        .onChange(of: strokes) { newValue in
            history.recordDrawing(newValue, external: true)
        }
    }
}
