//
//  MathKeyboardViewCore.swift
//  Duello
//
//  Clavier mathématique — coquille de `MathKeyboardView` : contrat
//  d'intégration, état, corps, frappe et outils partagés. Le rendu est
//  réparti dans `MathKeyboardView+Toolbar.swift`, `+Keys.swift`,
//  `+MatrixEditor.swift`, `+OperatorEditor.swift`, `+IntervalEditor.swift` ;
//  les modèles et données dans `MathKbKeyboardModel.swift`,
//  `MathKbLayout.swift`, `MathKbScript.swift`, `MathKbOperatorCatalog.swift`,
//  `MathKbInterval.swift`, `MathKbMatrixFormatter.swift`, `MathKbDrafts.swift`,
//  `MathKbControls.swift` et `MathKbFlowLayout.swift`.
//
//  Fichiers source portés :
//  - `expo_ref/src/components/MathKeyboard.tsx` — composant `MathKeyboard`,
//    touche `MathKey`, bornes infinies `InfiniteBoundKeys`, éditeurs guidés
//    (matrice, opérateur, intervalle), bandeau d'onglets, rangée d'actions
//    espace / retour / effacer ;
//  - `expo_ref/src/utils/mathKeySections.ts` — `MATH_SECTIONS`,
//    `MATH_KEYBOARD_SECTIONS`, `PYTHON_SECTIONS`, `SUBSCRIPT_SECTIONS` ;
//  - `expo_ref/src/utils/mathKeyboardLayout.ts` — `PYTHON_KEYBOARD_KEYS` ;
//  - `expo_ref/src/utils/mathOperator.ts` — `MATH_OPERATOR_DEFINITIONS`,
//    `INFINITE_BOUNDS`, `formatMathOperator`, `isMathOperatorComplete` ;
//  - `expo_ref/src/utils/mathInterval.ts` — `intervalBrackets`,
//    `formatInterval`, `isInfiniteBound` ;
//  - `expo_ref/src/utils/mathMatrix.ts` — `formatMatrix`, `matrixSides` ;
//  - `expo_ref/src/utils/mathLayout.ts` — `SUPERSCRIPTS`, `SUBSCRIPTS`,
//    `toScript`.
//
//  Spécification de portage : `mk_spec_logic.md` (racine du workspace).
//
//  Notes de portage
//  ----------------
//  - Le clavier insère de l'**Unicode** natif (`∑`, `∫`, `ₙ`, `²`…) et ne
//    convertit aucun LaTeX : comme dans la source, il n'appelle jamais
//    `LatexToUnicode` (voir `mk_spec_logic.md` §3.1).
//  - Le clavier ne se positionne pas lui-même : pas d'`absolute`, pas d'insets,
//    pas de `KeyboardAvoidingView` interne. C'est l'écran parent qui décide du
//    placement (les trois schémas sont décrits au §1.4 de la spécification).
//  - La signature d'intégration `init(mode:onInsert:onBackspace:onClose:)` ne
//    transporte que le texte : les touches qui reculent le curseur après
//    insertion (`back`, ex. `()`, `{}`, `√()`) perdent ce recul. La variante
//    `init(mode:onInsertWithBack:onBackspace:onClose:)` le transmet.
//  - Sans `value` / `selection` dans le contrat d'intégration, l'édition d'une
//    construction **déjà écrite** dans la réponse (parsing inverse
//    `findMatrixAtSelection` / `findMathOperatorAtSelection`, raccourci
//    « Modifier … ») n'est pas portée : les outils guidés composent une
//    construction neuve.
//  - SwiftUI iOS 16 n'expose pas la sélection d'un `TextField`. Là où la source
//    suivait un curseur par champ (`CaretText` : `insertAtCaret` /
//    `deleteAtCaret`, §2.1), les touches maths **s'ajoutent en fin** du champ
//    actif et l'effacement retire son dernier caractère. Les chevrons et la
//    touche retour déplacent le champ actif, pas le curseur.
//  - La rangée de suggestions « propres à l'exercice » (`suggestions` /
//    `pinnedKeys`) n'est pas portée : elle dépend d'une donnée que le contrat
//    d'intégration ne transporte pas.
//
//  Extrait de `MathKeyboardView.swift` : découpage en modules, sans
//  renommage de type, de membre ni de signature.
//

import SwiftUI

// MARK: - Clavier

/// Barre de symboles mathématiques, posée par l'écran parent au-dessus du
/// clavier système (les deux cohabitent : lettres et chiffres en bas, symboles
/// ici). Portée depuis `components/MathKeyboard.tsx`.
///
/// ```swift
/// MathKeyboardView(
///     mode: .math,
///     onInsert: { texte in réponse.insert(texte) },
///     onBackspace: { réponse.deleteBackward() },
///     onClose: { clavierOuvert = false }
/// )
/// ```
struct MathKeyboardView: View {

    // MARK: Contrat d'intégration

    private let mode: MathKbMode
    let insertText: (String, Int) -> Void
    private let backspace: () -> Void
    let close: () -> Void

    /// Signature d'intégration : `onInsert` ne transporte que le texte. Les
    /// touches à recul de curseur (`back`) sont insérées sans ce recul ; pour le
    /// conserver, utiliser `init(mode:onInsertWithBack:onBackspace:onClose:)`.
    init(
        mode: MathKbMode,
        onInsert: @escaping (String) -> Void,
        onBackspace: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.mode = mode
        self.insertText = { text, _ in onInsert(text) }
        self.backspace = onBackspace
        self.close = onClose
        _sectionId = State(initialValue: MathKbLayout.initialSectionId(for: mode))
    }

    /// Variante qui transmet aussi le recul du curseur demandé par la touche
    /// (`back`), pour se placer entre les délimiteurs après un `()` ou un `{}`.
    init(
        mode: MathKbMode,
        onInsertWithBack: @escaping (String, Int) -> Void,
        onBackspace: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.mode = mode
        self.insertText = onInsertWithBack
        self.backspace = onBackspace
        self.close = onClose
        _sectionId = State(initialValue: MathKbLayout.initialSectionId(for: mode))
    }

    // MARK: État

    @State var sectionId: String
    @State var subscriptMode = false
    @State var matrixDraft: MathKbMatrixDraft?
    @State var operatorDraft: MathKbOperatorDraft?
    @State var intervalDraft: MathKbIntervalDraft?

    @FocusState var matrixFocus: Int?
    @FocusState var operatorFocus: Int?
    @FocusState var intervalFocus: Int?

    // MARK: Dérivés

    var sections: [MathKbSection] { MathKbLayout.sections(for: mode) }

    var currentSection: MathKbSection {
        sections.first { $0.id == sectionId } ?? sections[0]
    }

    /// Un outil guidé est ouvert : il absorbe la frappe et la rangée de touches
    /// s'affiche un peu plus basse.
    var draftOpen: Bool {
        matrixDraft != nil || operatorDraft != nil || intervalDraft != nil
    }

    /// Le mode indice n'existe que là où les caractères ont une forme basse.
    var lowering: Bool {
        subscriptMode && currentSection.id == MathKbLayout.subscriptSectionId
    }

    // MARK: Corps

    var body: some View {
        VStack(spacing: 0) {
            tabsRow

            if let draft = matrixDraft {
                matrixEditor(draft)
            }
            if let draft = operatorDraft {
                operatorEditor(draft)
            }
            if let draft = intervalDraft {
                intervalEditor(draft)
            }

            keysScroll
            actionsRow
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(Theme.surfaceMuted)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
    }

    // MARK: Frappe

    /// Ouvre un outil guidé — un seul à la fois, sinon deux panneaux se
    /// disputeraient les touches (`startTool`).
    func startTool(_ action: MathKbAction) {
        matrixDraft = nil
        operatorDraft = nil
        intervalDraft = nil

        switch action {
        case .matrix:
            matrixDraft = MathKbMatrixDraft.initial()
            matrixFocus = 0
        case .interval:
            intervalDraft = MathKbIntervalDraft.initial()
            intervalFocus = 0
        case .exponent, .limit, .integral, .sum, .product:
            guard let kind = operatorKind(for: action) else { return }
            operatorDraft = MathKbOperatorDraft(kind: kind)
            operatorFocus = 0
        }
    }

    /// Une touche pressée alors qu'un outil est ouvert écrit dans son champ
    /// actif ; sinon l'insertion part vers la réponse, avec le recul demandé.
    func insertDraftText(_ text: String, back: Int = 0) {
        if var draft = matrixDraft, draft.active < draft.cells.count {
            draft.cells[draft.active] += text
            matrixDraft = draft
            return
        }
        if var draft = operatorDraft, draft.active < draft.values.count {
            draft.values[draft.active] += text
            operatorDraft = draft
            return
        }
        if var draft = intervalDraft {
            if draft.active == 0 { draft.lower += text } else { draft.upper += text }
            intervalDraft = draft
            return
        }
        insertText(text, back)
    }

    /// Efface le dernier caractère du champ actif, ou délègue à la réponse.
    func handleBackspace() {
        if var draft = matrixDraft, draft.active < draft.cells.count {
            if !draft.cells[draft.active].isEmpty { draft.cells[draft.active].removeLast() }
            matrixDraft = draft
            return
        }
        if var draft = operatorDraft, draft.active < draft.values.count {
            if !draft.values[draft.active].isEmpty { draft.values[draft.active].removeLast() }
            operatorDraft = draft
            return
        }
        if var draft = intervalDraft {
            if draft.active == 0 {
                if !draft.lower.isEmpty { draft.lower.removeLast() }
            } else if !draft.upper.isEmpty {
                draft.upper.removeLast()
            }
            intervalDraft = draft
            return
        }
        backspace()
    }

    /// Touche retour contextuelle (`handleReturn`) : champ suivant, borne
    /// suivante, case suivante, sinon une nouvelle ligne.
    func handleReturn() {
        if let draft = operatorDraft {
            focusOperatorField(draft.active + 1)
            return
        }
        if intervalDraft != nil {
            moveIntervalBound(1)
            return
        }
        if matrixDraft != nil {
            moveMatrixCell(1)
            return
        }
        insertText("\n", 0)
    }

    // MARK: Outils

    func operatorKind(for action: MathKbAction?) -> MathKbOperatorKind? {
        guard let action = action else { return nil }
        switch action {
        case .exponent: return .exponent
        case .limit: return .limit
        case .integral: return .integral
        case .sum: return .sum
        case .product: return .product
        case .matrix, .interval: return nil
        }
    }

    // MARK: Bornes infinies

    /// Bornes infinies posées à côté du champ ouvert (`InfiniteBoundKeys`) :
    /// elles ne sont pas une touche de plus dans une section.
    func infiniteBoundKeys(target: String) -> some View {
        HStack(spacing: 5) {
            Text("Borne infinie")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            ForEach(MathKbLayout.infiniteBounds, id: \.self) { bound in
                Button {
                    insertDraftText(bound)
                } label: {
                    Text(bound)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 9)
                        .frame(minWidth: 46)
                        .background(Theme.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "Écrire \(bound == "+∞" ? "plus l’infini" : "moins l’infini") dans le champ \(target)"
                )
            }
        }
    }
}
