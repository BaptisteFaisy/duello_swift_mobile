import SwiftUI

// MARK: - En-tête
//
// Annales — liste, lecteur et correction de copie.
//
// Portage SwiftUI des composants Expo suivants :
//
//   * `src/components/AnnaleViewer.tsx` (5 718 lignes) — lecteur d'annale :
//     onglets Énoncé / Barème / Commentaires / Corrigé, navigation entre les
//     questions, déverrouillage du corrigé officiel d'un DS écrit, panneau de
//     correction de copie.
//   * `src/components/AnnaleCopyCorrectionModal.tsx` — fenêtre « Correction de
//     copie » : dépôt des pages par partie, suivi de l'avancement, compte rendu
//     noté sur 20.
//   * `src/components/AnnaleCorrectionMonitor.tsx` — moniteur de fond qui
//     rafraîchit les corrections actives toutes les 15 s, même quand l'élève a
//     quitté l'annale.
//
// Règles reprises telles quelles du code Expo :
//
//   * `utils/annaleCopyCorrection.ts` — statuts de job, libellés
//     (`annaleCopyStatusLabel`), `isAnnaleCopyJobActive` (statuts terminaux
//     `ready` / `failed`), conservation des 40 derniers jobs.
//   * `utils/correctionPerformance.ts` — `MAX_CONCURRENT_COPY_UPLOADS = 2`,
//     `VISIBLE_COPY_REFRESH_MS = 1 500`.
//   * `utils/annaleWorkspaceMode.ts` — `usesWrittenAnnaleWorkspace` : une annale
//     écrite se compose sur papier, les oraux ESCP/HEC rangés dans Annales
//     gardent les champs de réponse.
//   * `utils/annaleTypes.ts` — `annaleTypeOptions` par filière.
//   * `utils/annaleBadges.ts` — `displayedAnnaleBadges`, `annaleYear`.
//   * `utils/annaleThemes.ts` — thèmes de tri « Analyse / Algèbre /
//     Probabilités ».
//   * `utils/itemDifficulty.ts` — `DIFFICULTY_LABELS`.
//   * `utils/exerciseBadgeFilter.ts` — menus « Type », « Domaine »,
//     « Difficulté », « Prérequis » (`PREREQUISITE_FILTER_OPTIONS`).
//
// Hors périmètre, volontairement : l'atelier de réponse interactif (dictée,
// tableau blanc, clavier mathématique, console Python, correction IA question
// par question) relève des lots B et C ; la banque d'annales réelle est un
// catalogue généré (plusieurs centaines de sujets) qui n'est pas porté ici, la
// banque embarquée ci-dessous sert de démonstration et de forme d'échange.

// MARK: - Écran des annales

/// Écran « Annales » d'une matière : liste filtrable, lecteur d'annale et
/// correction de copie.
///
/// Contrat d'intégration : `AnnalesView()` s'affiche seul, avec la banque de
/// démonstration ; l'hôte peut fournir la banque réelle et le parcours de
/// l'élève par `init(subject:subjectId:track:specialty:entries:)`.
struct AnnalesView: View {
    /// Matière affichée (« Mathématiques »).
    var subject: String
    /// Identifiant de la matière dans le parcours.
    var subjectId: String
    /// Filière de l'élève, qui fixe la liste des types d'épreuve.
    var track: String
    /// Spécialité de l'élève (ECG : « Maths appliquées » ou « Maths
    /// approfondies »).
    var specialty: String
    /// Banque d'annales affichée.
    var entries: [AnnEntry]

    @EnvironmentObject private var session: SessionStore
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var monitor = AnnCorrectionMonitor()

    @State private var openedEntry: AnnEntry?
    @State private var selection: [AnnFilterGroup.Kind: Set<String>] = [:]
    /// `filteredEntries` / `orderedEntries` mémoïsés : recalculés seulement quand
    /// `selection` (filtres) ou `entries` (banque) change, jamais à chaque `body`.
    @State private var filteredEntries: [AnnEntry] = []
    @State private var orderedEntries: [AnnEntry] = []

    init(
        subject: String = "Mathématiques",
        subjectId: String = "maths",
        track: String = "ECG",
        specialty: String = "Maths approfondies",
        entries: [AnnEntry] = AnnEntry.builtInBank
    ) {
        self.subject = subject
        self.subjectId = subjectId
        self.track = track
        self.specialty = specialty
        self.entries = entries
        // Sans filtre actif, la liste affichée est la banque entière.
        _filteredEntries = State(initialValue: entries)
        _orderedEntries = State(initialValue: Self.orderedByTheme(entries))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                notices
                if !monitor.jobs.isEmpty {
                    correctionsSection
                }
                filterBar
                list
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Theme.background)
        .onAppear {
            monitor.configure(token: session.token)
            monitor.load()
            monitor.start()
        }
        .onDisappear {
            monitor.stop()
        }
        .onChange(of: scenePhase) { phase in
            // Un retour au premier plan relit tout de suite les corrections en
            // cours ; en arrière-plan, la boucle de fond s'arrête.
            if phase == .active {
                monitor.configure(token: session.token)
                monitor.start()
            } else {
                monitor.stop()
            }
        }
        .onChange(of: session.token) { token in
            monitor.configure(token: token)
        }
        .onChange(of: selection) { _ in refreshEntries() }
        .onChange(of: entries) { _ in refreshEntries() }
        .fullScreenCover(item: $openedEntry) { entry in
            AnnReaderView(
                entry: entry,
                subject: subject,
                track: track,
                specialty: specialty,
                monitor: monitor,
                siblings: orderedEntries,
                onClose: { openedEntry = nil }
            )
            .environmentObject(session)
        }
    }

    // MARK: En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ANNALES")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.inkSoft)
            Text(subject)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(Theme.ink)
            Text("Sujets de concours et devoirs surveillés, corrigés par l’IA.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Bandeaux de correction prête

    @ViewBuilder
    private var notices: some View {
        ForEach(monitor.readyNotices) { job in
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.progress)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(job.title) — \(job.partLabel)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Correction prête")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 8)
                Button {
                    monitor.dismissNotice(job)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkFaint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Masquer cette correction")
            }
            .duelloCard()
        }
    }

    // MARK: Corrections en cours

    private var correctionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DuelloSectionHeader(title: "Mes corrections", subtitle: "Suivi des copies déposées")
            ForEach(monitor.jobs) { job in
                AnnCorrectionRow(job: job) {
                    openEntry(withId: job.itemId)
                }
            }
        }
    }

    // MARK: Filtres

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            DuelloSectionHeader(title: "Filtrer")
            ForEach(filterGroups) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.label)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.inkFaint)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            DuelloChip(title: "Tout", selected: chosen(group.kind).isEmpty) {
                                selection[group.kind] = []
                            }
                            ForEach(group.options) { option in
                                DuelloChip(
                                    title: option.label,
                                    selected: chosen(group.kind).contains(option.id)
                                ) {
                                    toggle(group.kind, option.id)
                                }
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
    }

    /// Menus utiles : une famille sans aucun badge est omise, comme
    /// `exerciseBadgeGroups`. Le rôle « Annale » ne distingue rien dans une
    /// liste qui ne contient que des annales.
    private var filterGroups: [AnnFilterGroup] {
        let presentTypes = Set(entries.flatMap { $0.filterTypeValues })
        let orderedTypes = AnnAnnaleTypes.options(track: track, specialty: specialty)
        var typeOptions: [String] = []
        for value in orderedTypes where presentTypes.contains(value) {
            typeOptions.append(value)
        }
        for value in AnnEntry.typeBadges where presentTypes.contains(value) && !typeOptions.contains(value) {
            typeOptions.append(value)
        }
        for value in presentTypes.sorted() where !typeOptions.contains(value) {
            typeOptions.append(value)
        }

        let presentThemes = AnnTheme.allCases.filter { theme in
            entries.contains { $0.theme == theme }
        }
        let presentDifficulties = Set(entries.map { $0.difficulty })

        var groups: [AnnFilterGroup] = []
        if !typeOptions.isEmpty {
            groups.append(AnnFilterGroup(
                kind: .type,
                label: "Type",
                options: typeOptions.map { AnnFilterOption(id: $0, label: $0) }
            ))
        }
        if !presentThemes.isEmpty {
            groups.append(AnnFilterGroup(
                kind: .domain,
                label: "Domaine",
                options: presentThemes.map { AnnFilterOption(id: $0.label, label: $0.label) }
            ))
        }
        if !presentDifficulties.isEmpty {
            groups.append(AnnFilterGroup(
                kind: .difficulty,
                label: "Difficulté",
                options: AnnDifficulty.order
                    .filter { presentDifficulties.contains($0) }
                    .map { AnnFilterOption(id: "d\($0)", label: AnnDifficulty.label(for: $0), difficulty: $0) }
            ))
        }
        groups.append(AnnFilterGroup(
            kind: .prerequisite,
            label: "Prérequis",
            options: AnnFilterGroup.prerequisiteOptions.map { AnnFilterOption(id: $0, label: $0) }
        ))
        return groups
    }

    // MARK: Liste

    private var list: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            DuelloSectionHeader(
                title: "Annales",
                subtitle: "\(filteredEntries.count) sujet\(filteredEntries.count > 1 ? "s" : "")"
            )
            if filteredEntries.isEmpty {
                DuelloEmptyState(
                    icon: "books.vertical",
                    title: "Aucune annale ne correspond à ces filtres",
                    message: "Change de type, de domaine ou de difficulté."
                )
            } else {
                ForEach(filteredEntries) { entry in
                    AnnEntryCard(entry: entry, job: monitor.jobs(for: entry.id).first) {
                        openedEntry = entry
                    }
                }
            }
        }
    }

    /// Recalcule les listes mémoïsées (filtres ou banque modifiés).
    private func refreshEntries() {
        filteredEntries = computeFilteredEntries(from: entries)
        orderedEntries = Self.orderedByTheme(filteredEntries)
    }

    /// Sujets filtrés par les groupes de filtres actifs.
    private func computeFilteredEntries(from source: [AnnEntry]) -> [AnnEntry] {
        source.filter { entry in
            for group in filterGroups {
                let chosen = chosen(group.kind)
                guard !chosen.isEmpty else { continue }
                switch group.kind {
                case .type:
                    if !entry.filterTypeValues.contains(where: { chosen.contains($0) }) { return false }
                case .domain:
                    guard let theme = entry.theme, chosen.contains(theme.label) else { return false }
                case .difficulty:
                    if !chosen.contains("d\(entry.difficulty)") { return false }
                case .prerequisite:
                    if !chosen.contains(entry.prerequisite) { return false }
                }
            }
            return true
        }
    }

    /// Sujets rangés par thème dans l'ordre fixe Analyse → Algèbre →
    /// Probabilités (`groupItemsByTheme`).
    private static func orderedByTheme(_ source: [AnnEntry]) -> [AnnEntry] {
        var ordered: [AnnEntry] = []
        for theme in AnnTheme.allCases {
            ordered.append(contentsOf: source.filter { $0.theme == theme })
        }
        ordered.append(contentsOf: source.filter { $0.theme == nil })
        return ordered
    }

    // MARK: Aides de sélection

    private func chosen(_ kind: AnnFilterGroup.Kind) -> Set<String> {
        selection[kind] ?? []
    }

    private func toggle(_ kind: AnnFilterGroup.Kind, _ id: String) {
        var current = chosen(kind)
        if current.contains(id) {
            current.remove(id)
        } else {
            current.insert(id)
        }
        selection[kind] = current
    }

    private func openEntry(withId itemId: String) {
        guard let entry = entries.first(where: { $0.id == itemId }) else { return }
        openedEntry = entry
    }
}
