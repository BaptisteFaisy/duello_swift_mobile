//
//  CollProgressiveList.swift
//  Duello
//
//  Montée par tranches d'une longue liste d'entraînement, avec disposition en
//  grille et groupement vertical quand des en-têtes de domaine existent.
//
//  Fichiers source Expo portés :
//    - src/components/ProgressiveList.tsx
//        `ProgressiveList`, `useProgressiveCount`, `chapterColumns`.
//    - src/utils/progressiveReveal.ts
//        `RevealState`, `RevealPlan`, `revealPlan` (montée progressive).
//
//  Limite documentée : la source programme une tranche par image
//  (`requestAnimationFrame`) ; ici une tâche asynchrone avance par pas de 16 ms,
//  ce qui produit la même montée sans recréer de vue.
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

/// État de la révélation progressive (`RevealState`).
struct CollRevealState: Equatable {
    var key: String
    var count: Int
}

/// Plan de la révélation progressive (`RevealPlan`).
struct CollRevealPlan: Equatable {
    /// Nombre d'éléments à monter maintenant.
    var count: Int
    /// Vrai lorsque toute la liste est montée.
    var complete: Bool
    /// État à appliquer au pas suivant, `nil` si la liste est complète.
    var next: CollRevealState?
}

/// `revealPlan` : calcule la tranche courante et la suivante.
enum CollReveal {
    static func plan(
        state: CollRevealState,
        key: String,
        total: Int,
        firstBatch: Int
    ) -> CollRevealPlan {
        let first = max(1, firstBatch)
        let revealed = state.key == key ? max(first, state.count) : first
        let complete = revealed >= total
        return CollRevealPlan(
            count: complete ? max(0, total) : revealed,
            complete: complete,
            next: complete ? nil : CollRevealState(key: key, count: min(total, revealed + first))
        )
    }
}

/// Élément rangé dans une colonne (`chapterColumns`), avec son index d'origine.
private struct CollColumnEntry<Item: Identifiable>: Identifiable {
    let item: Item
    let index: Int

    var id: Item.ID { item.id }
}

/// Liste à montée progressive (`ProgressiveList`).
struct CollProgressiveList<Item: Identifiable, Content: View>: View {
    let revealKey: String
    var firstBatch: Int = 10
    let items: [Item]
    var paused: Bool = false
    var grid: Bool = false
    var gridColumns: Int = 3
    /// Détecte le premier élément d'un groupe : les en-têtes restent dans leur
    /// colonne (`fullWidthItem`).
    var fullWidthItem: ((Item) -> Bool)? = nil
    @ViewBuilder var content: (Item, Int) -> Content

    @State private var state = CollRevealState(key: "", count: 0)
    @State private var pausedFlag = false

    var body: some View {
        Group {
            if grid, fullWidthItem == nil {
                gridBody
            } else if grid {
                columnsBody
            } else {
                listBody
            }
        }
        .onAppear { pausedFlag = paused }
        .onChange(of: paused) { pausedFlag = $0 }
        .task(id: revealKey) { await reveal() }
    }

    // MARK: - Corps

    private var listBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visibleItems.indices), id: \.self) { index in
                content(items[index], index)
            }
        }
    }

    private var gridBody: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: max(1, gridColumns)),
            spacing: 12
        ) {
            ForEach(Array(visibleItems.indices), id: \.self) { index in
                content(items[index], index)
            }
        }
    }

    private var columnsBody: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(0..<3, id: \.self) { columnIndex in
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(columns[columnIndex]) { entry in
                        if entry.index < state.count {
                            content(entry.item, entry.index)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    // MARK: - Dérivés

    /// Éléments révélés (`items.slice(0, count)`).
    private var visibleItems: [Item] {
        let count = max(0, min(state.count, items.count))
        return Array(items.prefix(count))
    }

    /// Colonnes équilibrées, avec les en-têtes de groupe gardés entiers.
    private var columns: [[CollColumnEntry<Item>]] {
        guard let fullWidthItem else { return [[], [], []] }
        return CollProgressiveList.chapterColumns(items, startsGroup: fullWidthItem)
    }

    // MARK: - Montée progressive

    /// `useProgressiveCount` : monte la première tranche immédiatement, puis les
    /// suivantes une par pas, tant que la liste n'est pas complète ni en pause.
    @MainActor
    private func reveal() async {
        var current = CollRevealState(key: revealKey, count: 0)
        while !Task.isCancelled {
            let plan = CollReveal.plan(
                state: current,
                key: revealKey,
                total: items.count,
                firstBatch: firstBatch
            )
            state = CollRevealState(key: revealKey, count: plan.count)
            guard let next = plan.next, !pausedFlag else { return }
            current = next
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
    }

    /// `chapterColumns` : répartit des lignes contiguës sur trois colonnes, de
    /// haut en bas puis de gauche à droite, en gardant les premières colonnes
    /// égales et sans laisser un en-tête sans son chapitre.
    private static func chapterColumns(
        _ items: [Item],
        startsGroup: (Item) -> Bool
    ) -> [[CollColumnEntry<Item>]] {
        let columnCount = 3
        var rowsPerColumn = Int(ceil(Double(items.count) / Double(columnCount)))
        while rowsPerColumn < items.count / 2 && (
            (rowsPerColumn < items.count && startsGroup(items[rowsPerColumn - 1])) ||
            (2 * rowsPerColumn < items.count && startsGroup(items[2 * rowsPerColumn - 1]))
        ) {
            rowsPerColumn += 1
        }

        var columns: [[CollColumnEntry<Item>]] = []
        for columnIndex in 0..<columnCount {
            let start = columnIndex * rowsPerColumn
            guard start < items.count else {
                columns.append([])
                continue
            }
            let end = min(start + rowsPerColumn, items.count)
            columns.append((start..<end).map { CollColumnEntry(item: items[$0], index: $0) })
        }
        return columns
    }
}
