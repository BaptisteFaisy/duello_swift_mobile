//
//  Ui2PrepaSearchSheet.swift
//  Duello
//
//  Lot 7-F « UI générique » (préfixe `Ui2`).
//
//  Fichier source Expo porté (libellés repris mot pour mot) :
//    - src/components/PrepaSearchModal.tsx (`PrepaSearchModal`)
//
//  Réutilise sans le modifier : le modèle `OnbDataPrepas.Prepa` et le filtre
//  `OnbDataPrepas.search` (port de `src/data/prepas.ts`), ainsi que le
//  référentiel/cache de `Ui2PrepaDirectory.swift`.
//
//  Présenté en feuille (`.sheet`, équivalent de `presentationStyle="pageSheet"`).
//  Cible iOS 16.
//
import SwiftUI

/// Recherche de prépa dans le référentiel national (`PrepaSearchModal.tsx`).
struct Ui2PrepaSearchSheet: View {
    /// Prépa choisie dans la liste.
    let onSelect: (OnbDataPrepas.Prepa) -> Void
    /// Nom saisi à la main quand la prépa n'apparaît pas.
    let onUseCustom: (String) -> Void
    /// Fermeture de la feuille.
    let onClose: () -> Void

    @State private var query = ""
    @State private var officialResults: [OnbDataPrepas.Prepa] = []
    @State private var isLoading = false
    @State private var referenceYear = ""
    @State private var loadError = false

    /// `searchPrepas` appliqué à la saisie courante (`OnbDataPrepas.search`).
    private var results: [OnbDataPrepas.Prepa] {
        OnbDataPrepas.search(officialResults, query: query)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchSection
            resultsHeader
            resultsList
        }
        .background(Theme.background)
        .task { await loadDirectory() }
    }

    // MARK: En-tête

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer")
            Spacer()
            Text("Rechercher ma prépa")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                TextField("Nom ou ville...", text: $query)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Effacer la recherche")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.primaryLight, lineWidth: 2)
            )
            Text(sourceText)
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(20)
    }

    /// Ligne de source (`sourceText` de la source).
    private var sourceText: String {
        if !referenceYear.isEmpty {
            return "Référentiel national des CPGE \(referenceYear) · MESR"
        }
        if isLoading {
            return "Chargement du référentiel national des CPGE…"
        }
        return "Référentiel national des CPGE · MESR"
    }

    private var resultsHeader: some View {
        HStack {
            Text("\(results.count) \(results.count == 1 ? "prépa trouvée" : "prépas trouvées")")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            if isLoading {
                ProgressView().tint(Theme.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: Résultats

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !trimmedQuery.isEmpty { customButton }
                if results.isEmpty && !isLoading {
                    emptyState
                } else {
                    ForEach(results) { prepa in
                        resultRow(prepa)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    /// « Utiliser « … » » en tête de liste (`ListHeaderComponent`).
    private var customButton: some View {
        Button(action: handleCustom) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 21))
                    .foregroundStyle(Theme.primary)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Utiliser « \(trimmedQuery) »")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Theme.primary)
                    Text("Si ta prépa n’apparaît pas, ajoute-la puis renseigne sa ville.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(15)
            .background(Theme.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .stroke(Theme.primary, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func resultRow(_ prepa: OnbDataPrepas.Prepa) -> some View {
        let isPrivate = prepa.type == .privatePrep
        return Button { handleSelect(prepa) } label: {
            HStack(spacing: 14) {
                Image(systemName: "graduationcap")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 44, height: 44)
                    .background(Theme.primaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 6) {
                    Text(prepa.name)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 12) {
                        metaItem(icon: "mappin", text: "\(prepa.city), \(prepa.country)")
                        metaItem(
                            icon: isPrivate ? "briefcase" : "building.2",
                            text: isPrivate ? "Privé" : "Public"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(16)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func metaItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    /// `ListEmptyComponent` : indisponible ou aucune correspondance.
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: loadError ? "wifi.slash" : "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Theme.inkFaint)
            Text(loadError ? "Référentiel indisponible" : "Aucune prépa trouvée")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)
            Text(
                loadError
                    ? "Connecte-toi à Internet pour charger la liste complète une première fois."
                    : "Essaie un autre terme ou utilise directement le nom que tu as saisi."
            )
            .font(.system(size: 13))
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity)
    }

    // MARK: Chargement et sélection

    /// Cache facultatif d'abord, puis référentiel en ligne (source de vérité).
    private func loadDirectory() async {
        isLoading = true
        loadError = false
        var hasCachedDirectory = false

        if let cached = Ui2PrepaDirectory.loadCached() {
            hasCachedDirectory = true
            officialResults = cached.prepas
            referenceYear = cached.referenceYear
        }

        do {
            let directory = try await Ui2PrepaDirectory.fetchOfficial()
            officialResults = directory.prepas
            referenceYear = directory.referenceYear
            Ui2PrepaDirectory.saveCache(directory)
        } catch {
            if !hasCachedDirectory { loadError = true }
        }
        isLoading = false
    }

    private func handleSelect(_ prepa: OnbDataPrepas.Prepa) {
        onSelect(prepa)
        query = ""
        onClose()
    }

    private func handleCustom() {
        onUseCustom(trimmedQuery)
        query = ""
        onClose()
    }
}
