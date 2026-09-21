import SwiftUI
import Foundation

/// Tableau blanc du mode entraînement, porté de :
/// - `src/components/Whiteboard.native.tsx` (document canvas et ses bornes) ;
/// - `src/components/whiteboardModel.ts` (encodage du brouillon) ;
/// - `src/components/WhiteboardHistoryControls.tsx` (barre d’outils + historique).
///
/// Écarts assumés par rapport à la source :
/// - **Pas de WebView ni de moteur d’encre** : rendu `Canvas` SwiftUI et un
///   `DragGesture` unique aiguillé par le mode (jamais deux gestes concurrents).
/// - **Zoom hors périmètre** : le pincement à deux doigts de la source n’est
///   pas porté ; seul le mode « Déplacer » (translation) l’est.
/// - **Gomme ajoutée** : sans moteur d’encre, la gomme ne rabote pas un tracé,
///   elle **supprime tout le tracé qu’elle touche** (distance point/segment ≤
///   demi-largeur du trait + rayon de gomme), limite documentée ici et dans l’UI.
/// - **Couleurs ajoutées** : la source ne dessine qu’en `#172554` ; le portage
///   ajoute `colorHex` et `width` à `WbStroke` pour la palette et la gomme.
///   Le format sérialisé reste toutefois celui de la source (voir `WbCodec`).

// MARK: - Modèle

/// Un point du brouillon, repris de `WhiteboardPoint`.
struct WbPoint: Codable, Hashable {
    var x: Double
    var y: Double
}

/// Un tracé du brouillon. La source (`WhiteboardStroke`) ne porte que `points` :
/// `id`, `colorHex` et `width` sont des **ajouts du portage** (identité SwiftUI,
/// palette de couleurs, gomme). Ils ne sont jamais sérialisés : seuls `points`
/// partent dans le JSON, conformément au format d’origine.
struct WbStroke: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var points: [WbPoint]
    var colorHex: Int = WbPalette.defaultInkHex
    var width: Double = WbPalette.brushWidth

    private enum CodingKeys: String, CodingKey {
        case points
    }
}

extension WbStroke {
    /// Décode un tracé depuis le format source (`{"points":[…]}`) : `id` est
    /// **régénéré**, la couleur reprend l’encre par défaut et la largeur vaut 2,
    /// car la source ne transmet que les points.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        points = try container.decode([WbPoint].self, forKey: .points)
        id = UUID()
        colorHex = WbPalette.defaultInkHex
        width = WbPalette.brushWidth
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

// MARK: - Palette

/// Une couleur nommée de la palette de traits.
struct WbColor: Identifiable, Hashable {
    let id: Int
    let name: String

    var hex: Int { id }
    var color: Color { Color(hex: id) }
}

/// Palette et mesures du tableau blanc. L’encre par défaut (`0x172554`) et la
/// largeur de trait (`2`) sont les constantes de la source.
enum WbPalette {
    static let defaultInkHex = 0x172554
    static let brushWidth: Double = 2
    static let backgroundHex = 0xFFFFFF
    /// Rayon de la pointe de gomme, ajouté par le portage (la source n’en a pas).
    static let eraserRadius: Double = 10

    static let colors: [WbColor] = [
        WbColor(id: 0x172554, name: "Encre"),
        WbColor(id: 0xDC2626, name: "Rouge"),
        WbColor(id: 0x16A34A, name: "Vert"),
        WbColor(id: 0x2563EB, name: "Bleu"),
        WbColor(id: 0xEA580C, name: "Orange")
    ]
}

/// Mode d’interaction du plateau. `erase` est un ajout du portage.
enum WbTool {
    case draw, pan, erase
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

// MARK: - Plateau

/// Zone de dessin : `Canvas` + un unique `DragGesture` aiguillé par le mode.
struct WbCanvas: View {
    let strokes: [WbStroke]
    let tool: WbTool
    let colorHex: Int
    let width: Double
    let onStrokesChange: ([WbStroke]) -> Void

    @State private var draft: [WbPoint] = []
    @State private var draftColorHex: Int = WbPalette.defaultInkHex
    @State private var draftWidth: Double = WbPalette.brushWidth
    @State private var offset: CGSize = .zero
    @State private var panBase: CGSize = .zero

    /// Tracés affichés : le brouillon en cours est rendu comme un tracé de plus.
    private var renderedStrokes: [WbStroke] {
        guard !draft.isEmpty else { return strokes }
        return strokes + [WbStroke(points: draft, colorHex: draftColorHex, width: draftWidth)]
    }

    var body: some View {
        Canvas { context, _ in
            context.translateBy(x: offset.width, y: offset.height)
            for stroke in renderedStrokes {
                let points = stroke.points
                guard let first = points.first else { continue }
                let color = Color(hex: stroke.colorHex)
                if points.count == 1 {
                    let radius = stroke.width / 2
                    let frame = CGRect(x: first.x - radius, y: first.y - radius, width: stroke.width, height: stroke.width)
                    context.fill(Path(ellipseIn: frame), with: .color(color))
                    continue
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
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
            }
        }
        .background(Color(hex: WbPalette.backgroundHex))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { handle($0, isEnd: false) }.onEnded { handle($0, isEnd: true) })
    }

    /// Aiguillage du geste par le mode. Le zoom est hors périmètre : seul le
    /// mode « Déplacer » translate le plateau.
    private func handle(_ value: DragGesture.Value, isEnd: Bool) {
        switch tool {
        case .pan:
            if isEnd {
                panBase = offset
            } else {
                offset = CGSize(width: panBase.width + value.translation.width, height: panBase.height + value.translation.height)
            }
        case .erase:
            guard !isEnd else { return }
            let probe = CGPoint(x: value.location.x - offset.width, y: value.location.y - offset.height)
            let kept = strokes.filter { stroke in
                let threshold = stroke.width / 2 + WbPalette.eraserRadius
                let points = stroke.points
                if points.count < 2 {
                    guard let only = points.first else { return true }
                    return hypot(only.x - probe.x, only.y - probe.y) > threshold
                }
                for index in 1..<points.count {
                    let a = points[index - 1]
                    let b = points[index]
                    let dx = b.x - a.x, dy = b.y - a.y
                    let lengthSquared = dx * dx + dy * dy
                    let raw = lengthSquared == 0 ? 0 : ((probe.x - a.x) * dx + (probe.y - a.y) * dy) / lengthSquared
                    let t = min(1, max(0, raw))
                    if hypot(probe.x - (a.x + t * dx), probe.y - (a.y + t * dy)) <= threshold { return false }
                }
                return true
            }
            if kept.count != strokes.count { onStrokesChange(kept) }
        case .draw:
            if isEnd {
                guard !draft.isEmpty else { return }
                let stroke = WbStroke(points: draft, colorHex: draftColorHex, width: draftWidth)
                draft = []
                onStrokesChange(strokes + [stroke])
            } else {
                let point = WbPoint(x: value.location.x - offset.width, y: value.location.y - offset.height)
                if draft.isEmpty {
                    draftColorHex = colorHex
                    draftWidth = width
                    draft = [point]
                } else if let last = draft.last, hypot(point.x - last.x, point.y - last.y) >= 0.5 {
                    draft.append(point)
                }
            }
        }
    }
}

// MARK: - Barre d’outils

/// Barre d’outils du tableau blanc, portée de `WhiteboardHistoryControls.tsx`,
/// augmentée de la gomme, des couleurs et de l’effacement complet.
struct WbToolbar: View {
    @Binding var tool: WbTool
    @Binding var colorHex: Int
    let canUndo: Bool
    let canRedo: Bool
    let expanded: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onToggleExpanded: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                WbModeButton(title: "Dessiner", icon: "pencil", selected: tool == .draw) { tool = .draw }
                    .accessibilityLabel("Dessiner sur le tableau blanc")
                WbModeButton(title: "Déplacer", icon: "hand.point.up.left", selected: tool == .pan) { tool = .pan }
                    .accessibilityLabel("Se déplacer dans le tableau blanc")
                    .accessibilityHint("Fais glisser le tableau sans écrire")
                Spacer(minLength: 0)
                WbIconButton(icon: "arrow.uturn.backward", label: "Annuler le dernier trait", enabled: canUndo, action: onUndo)
                WbIconButton(icon: "arrow.uturn.forward", label: "Rétablir le dernier trait", enabled: canRedo, action: onRedo)
                WbIconButton(
                    icon: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                    label: expanded ? "Réduire le tableau blanc" : "Agrandir le tableau blanc",
                    prominent: true,
                    action: onToggleExpanded
                )
            }
            HStack(spacing: 8) {
                WbModeButton(title: "Gomme", icon: "eraser", selected: tool == .erase) { tool = .erase }
                    .accessibilityLabel("Gomme")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(WbPalette.colors) { entry in
                            WbColorDot(entry: entry, selected: entry.hex == colorHex) {
                                colorHex = entry.hex
                                if tool == .erase { tool = .draw }
                            }
                        }
                    }
                }
                WbIconButton(icon: "trash", label: "Effacer le tableau", action: onClear)
            }
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

/// Bouton de mode (Dessiner / Déplacer / Gomme).
struct WbModeButton: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 12, weight: .bold))
                Text(title).font(.system(size: 11, weight: .heavy)).lineLimit(1)
            }
            .foregroundStyle(selected ? Theme.surface : Theme.ink)
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(selected ? Theme.primary : Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

/// Bouton d’action carré (annuler, rétablir, agrandir, effacer).
struct WbIconButton: View {
    let icon: String
    let label: String
    var enabled: Bool = true
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(prominent ? Theme.surface : Theme.ink)
                .frame(width: 32, height: 32)
                .background(prominent ? Theme.primary : Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }
}

/// Pastille de couleur de la palette.
struct WbColorDot: View {
    let entry: WbColor
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(entry.color).frame(width: 20, height: 20)
                Circle().stroke(Theme.border, lineWidth: 1).frame(width: 20, height: 20)
                if selected {
                    Circle().stroke(Theme.ink, lineWidth: 2).frame(width: 26, height: 26)
                }
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.name)
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
    @State private var colorHex: Int = WbPalette.defaultInkHex

    /// Aide d’accessibilité du plateau. Le pincement de la source est retiré :
    /// le zoom est hors périmètre.
    private var hint: String {
        switch tool {
        case .draw: return "Fais glisser ton doigt ou ton stylet pour dessiner."
        case .pan: return "Fais glisser le tableau pour te déplacer sans écrire."
        case .erase: return "Fais glisser la gomme sur un tracé pour l’effacer."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            WbToolbar(
                tool: $tool,
                colorHex: $colorHex,
                canUndo: history.canUndo,
                canRedo: history.canRedo,
                expanded: expanded,
                onUndo: { history.undo() },
                onRedo: { history.redo() },
                onToggleExpanded: onToggleExpanded,
                onClear: { history.recordDrawing([]) }
            )
            WbCanvas(
                strokes: strokes,
                tool: tool,
                colorHex: colorHex,
                width: WbPalette.brushWidth,
                onStrokesChange: { history.recordDrawing($0) }
            )
            .frame(minHeight: 116)
            if tool == .erase { eraserHelp }
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

    /// Aide discrète rappelant la limite de la gomme (pas de moteur d’encre).
    private var eraserHelp: some View {
        Text("La gomme efface tout le tracé qu’elle touche.")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.inkFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }
}
