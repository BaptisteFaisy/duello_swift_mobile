import SwiftUI

/// Écran « Progression » : avancement de chaque matière, défis et temps
/// d'entraînement. Reprend `src/screens/EnhancedProgressScreen.tsx` : le
/// parcours vient de `SessionStore`, les compteurs de `ProgressStore`, et les
/// items comptés sont ceux réellement servis (`DuelloExerciseCatalog`).
///
/// Le préfixe `Duello` suit `DuelloTextField` : `ProgressView` est déjà pris
/// par SwiftUI, et une déclaration locale masquerait la roue de chargement des
/// autres écrans (`ChallengePlayerView`, `ChallengesView`, `WelcomeView`).
struct DuelloProgressView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var progress: ProgressStore

    /// Matière choisie ; vide tant que l'élève n'a rien choisi, la première
    /// matière du parcours fait alors office de sélection.
    @State private var selectedSubjectId: String = ""
    @State private var selectedTab: ProgressTab = .exercises

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if subjects.isEmpty {
                        emptyState
                    } else {
                        subjectPickerCard
                        summaryCard
                        tabBar
                        tabContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Progression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: Données

    /// Matières du parcours choisi, dans l'ordre de l'app Expo.
    private var subjects: [TrackSubject] {
        DuelloProgram.subjects(
            track: session.profile.track,
            specialty: session.profile.specialty,
            year: session.profile.year
        )
    }

    /// Matière affichée : le choix de l'élève, ou la première du parcours.
    private var selectedSubject: TrackSubject? {
        subjects.first { $0.id == selectedSubjectId } ?? subjects.first
    }

    /// Sélection du menu de matières. Le getter repasse par `selectedSubject` :
    /// quand le parcours change, l'écran retombe sur une matière qui existe.
    private var subjectSelection: Binding<String> {
        Binding(
            get: { selectedSubject?.id ?? "" },
            set: { selectedSubjectId = $0 }
        )
    }

    /// Banque d'items servie pour ce profil, repliée en `matière:chapitre`. Les
    /// clés du catalogue sont `<année>:<matière>:<chapitre>` : une année 2 porte
    /// les banques des deux années, on réunit donc les chapitres homonymes.
    private var itemPool: [String: [String]] {
        var merged: [String: Set<String>] = [:]
        for (key, ids) in DuelloExerciseCatalog.forProfile(session.profile) {
            let parts = key.split(separator: ":", maxSplits: 2)
            guard parts.count == 3 else { continue }
            merged["\(parts[1]):\(parts[2])", default: []].formUnion(ids)
        }
        return merged.mapValues { $0.sorted() }
    }

    /// Items servis pour toute la matière, tous chapitres confondus.
    private func itemIds(for subject: TrackSubject, kind: ProgressItemKind) -> [String] {
        // Aucune banque de colles n'est portée : la matière reste à zéro et
        // l'écran annonce « Contenu à venir », comme Expo sans items servis.
        guard kind == .exercises else { return [] }

        let pool = itemPool
        var ids = Set<String>()
        for chapter in subject.chapters {
            if let chapterIds = pool["\(subject.id):\(chapter.id)"] {
                ids.formUnion(chapterIds)
            }
        }
        return ids.sorted()
    }

    /// Avancement de la matière affichée pour un type d'entraînement.
    private func trainingStat(kind: ProgressItemKind) -> TrainingStat {
        guard let subject = selectedSubject else { return TrainingStat() }
        return progress.trainingStat(forItemIds: itemIds(for: subject, kind: kind))
    }

    /// Avancement de chaque chapitre dont la banque n'est pas vide.
    private func chapterProgress(_ kind: ProgressItemKind) -> [ChapterProgress] {
        guard kind == .exercises, let subject = selectedSubject else { return [] }

        let pool = itemPool
        return subject.chapters.compactMap { chapter -> ChapterProgress? in
            guard let ids = pool["\(subject.id):\(chapter.id)"], !ids.isEmpty else {
                return nil
            }
            return ChapterProgress(
                id: chapter.id,
                name: chapter.name,
                stat: progress.trainingStat(forItemIds: ids)
            )
        }
    }

    /// Défis de la matière affichée.
    private var duelStat: DuelStat {
        guard let subject = selectedSubject else { return DuelStat() }
        return progress.duelStat(for: subject.name)
    }

    /// Cote Elo de la matière affichée.
    private var selectedElo: Int {
        guard let subject = selectedSubject else { return ProgressStore.initialElo }
        return progress.subjectElo(for: subject.name)
    }

    // MARK: Sélecteur de matière

    private var subjectPickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Matière")

            Picker("Matière", selection: subjectSelection) {
                ForEach(subjects) { subject in
                    Text(subject.name).tag(subject.id)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let fullName = selectedSubject?.fullName {
                Text(fullName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .duelloCard()
    }

    // MARK: Résumé compact

    /// Résumé de la matière choisie : les trois lignes compactes de l'écran
    /// Expo, une par type de travail.
    private var summaryCard: some View {
        let exercises = trainingStat(kind: .exercises)
        let colles = trainingStat(kind: .colles)
        let challenges = duelStat

        return VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Résumé")

            EmbeddedMetric(
                label: "Exercices",
                value: exercises.total > 0
                    ? "\(exercises.mastered)/\(exercises.total) maîtrisés"
                    : "Contenu à venir",
                progress: exercises.fraction
            )
            EmbeddedMetric(
                label: "Colles",
                value: colles.total > 0
                    ? "\(colles.mastered)/\(colles.total) maîtrisées"
                    : "Contenu à venir",
                progress: colles.fraction
            )
            EmbeddedMetric(
                label: "Défis",
                value: "\(challenges.won)/\(challenges.played) gagnés · \(selectedElo) Elo",
                progress: challenges.fraction
            )
        }
        .duelloCard()
    }

    // MARK: Onglets

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProgressTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.label)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(selectedTab == tab ? Theme.surface : Theme.inkSoft)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(selectedTab == tab ? Theme.ink : Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                                    .stroke(
                                        selectedTab == tab ? Theme.ink : Theme.border,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .exercises: trainingSection(.exercises)
        case .colles: trainingSection(.colles)
        case .duels: duelSection
        case .hours: hoursSection
        }
    }

    // MARK: Exercices et colles

    /// Carte de la matière pour un type d'entraînement, puis détail par chapitre.
    @ViewBuilder
    private func trainingSection(_ kind: ProgressItemKind) -> some View {
        let stat = trainingStat(kind: kind)
        trainingCard(stat)
        chapterList(kind)
    }

    private func trainingCard(_ stat: TrainingStat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(selectedSubject?.name ?? "Matière")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 10)
                Text(stat.total > 0 ? "\(stat.mastered)/\(stat.total)" : "À venir")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.ink)
            }

            ProgressBar(fraction: stat.fraction)

            Text(trainingSummary(stat))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
        .duelloCard()
    }

    /// Métriques de la carte d'entraînement : maîtrisés, tentés, tentatives.
    private func trainingSummary(_ stat: TrainingStat) -> String {
        guard stat.total > 0 else { return "Aucun sujet disponible pour le moment" }

        let mastered = "\(stat.mastered) réussi\(agreement(stat.mastered)) sur \(stat.total)"
        let attempted = "\(stat.attempted) tenté\(agreement(stat.attempted))"
        let attempts = "\(stat.attempts) tentative\(agreement(stat.attempts))"
        return [mastered, attempted, attempts].joined(separator: " · ")
    }

    /// Avancement chapitre par chapitre, limité aux chapitres servis.
    @ViewBuilder
    private func chapterList(_ kind: ProgressItemKind) -> some View {
        let chapters = chapterProgress(kind)
        if !chapters.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Par chapitre")
                ForEach(chapters) { chapter in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(chapter.name)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                            Spacer(minLength: 10)
                            Text("\(chapter.stat.mastered)/\(chapter.stat.total)")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        ProgressBar(fraction: chapter.stat.fraction, height: 4)
                    }
                }
            }
            .duelloCard()
        }
    }

    // MARK: Défis

    /// Défis de la matière : cote, défis joués et gagnés, encart d'invitation
    /// tant qu'aucun défi n'a été joué.
    @ViewBuilder
    private var duelSection: some View {
        let stat = duelStat

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(selectedSubject?.name ?? "Matière")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 10)
                Text("\(selectedElo) Elo")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.ink)
            }

            ProgressBar(fraction: stat.fraction)

            HStack(spacing: 10) {
                Text("\(stat.played) défi\(agreement(stat.played)) joué\(agreement(stat.played))")
                Spacer(minLength: 10)
                Text(duelSummary(stat))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.inkSoft)
        }
        .duelloCard()

        if stat.played == 0 {
            infoCard(duelInvitation)
        }
    }

    /// Invitation à ouvrir un premier défi dans la matière affichée.
    private var duelInvitation: String {
        "Lance un défi depuis l'onglet Défis : tes duels s'ajouteront ici, matière par matière."
    }

    /// « N gagnés · X % », ou un tiret cadratin sans défi joué.
    private func duelSummary(_ stat: DuelStat) -> String {
        let rate = stat.played > 0 ? "\(stat.winRatePercent) %" : "—"
        return "\(stat.won) gagné\(agreement(stat.won)) · \(rate)"
    }

    // MARK: Heures

    /// Temps d'entraînement cumulé, journées travaillées, puis temps de chaque
    /// matière du parcours (la section reste globale, comme côté Expo).
    @ViewBuilder
    private var hoursSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                summaryBlock("Temps d'entraînement", progress.formattedTrainingTime())
                summaryBlock("Jours travaillés", "\(progress.activeDayCount())")
            }
        }
        .duelloCard()

        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Temps par matière")
            ForEach(subjects) { subject in
                subjectTimeRow(subject)
            }
        }
        .duelloCard()
    }

    /// Grand chiffre légendé du résumé « Heures ».
    private func summaryBlock(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkSoft)
            Text(value)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Temps d'entraînement cumulé d'une matière.
    private func subjectTimeRow(_ subject: TrackSubject) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.primaryLight)
                    .frame(width: 38, height: 38)
                Image(systemName: "clock")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(subject.name)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("Temps d'entraînement cumulé")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }

            Spacer(minLength: 10)

            Text(ProgressStore.formatTrainingTime(minutes: progress.subjectMinutes[subject.name] ?? 0))
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.ink)
        }
    }

    // MARK: Composants partagés

    /// Encart d'information sur fond clair.
    private func infoCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            Text("Choisis ton parcours dans « Mon compte »")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy))
            .textCase(.uppercase)
            .foregroundStyle(Theme.inkSoft)
    }

    /// Marque du pluriel reprise d'Expo : « s » dès que le compte dépasse 1.
    private func agreement(_ count: Int) -> String {
        count > 1 ? "s" : ""
    }
}

// MARK: - Types de l'écran

/// Onglets de la progression, dans l'ordre de `TAB_LABELS` d'Expo.
private enum ProgressTab: String, CaseIterable, Identifiable {
    case exercises
    case colles
    case duels
    case hours

    var id: String { rawValue }

    /// Libellé affiché dans la barre d'onglets.
    var label: String {
        switch self {
        case .exercises: return "Exercices"
        case .colles: return "Colles"
        case .duels: return "Défis"
        case .hours: return "Heures"
        }
    }
}

/// Nature d'item suivie par une carte d'entraînement : `chapterItems` (Expo)
/// distingue les exercices des colles, mais seule la banque d'exercices est
/// portée par cette version.
private enum ProgressItemKind {
    case exercises
    case colles
}

/// Avancement d'un chapitre de la matière affichée.
private struct ChapterProgress: Identifiable {
    let id: String
    let name: String
    let stat: TrainingStat
}

/// Ligne de progression compacte du résumé (voir `EmbeddedMetric` de
/// `EnhancedProgressScreen.tsx`) : libellé, valeur et barre discrète.
struct EmbeddedMetric: View {
    let label: String
    let value: String
    /// Fraction attendue dans [0, 1] ; les valeurs hors bornes sont ramenées.
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Spacer(minLength: 12)
                Text(value)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            ProgressBar(fraction: progress, height: 3, track: Theme.surfaceMuted)
        }
    }
}

/// Barre d'avancement fine : piste claire, remplissage vert de maîtrise
/// (voir `progressTrack`/`progressFill` de `theme.ts`).
private struct ProgressBar: View {
    /// Fraction de remplissage attendue dans [0, 1].
    let fraction: Double
    /// Épaisseur de la barre.
    var height: CGFloat = 6
    /// Couleur de la piste.
    var track: Color = Theme.primaryLight

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(Theme.progress)
                    .frame(width: proxy.size.width * bounded)
            }
        }
        .frame(height: height)
    }

    /// Fraction bornée à [0, 1], comme `Math.min(1, Math.max(0, progress))`.
    private var bounded: CGFloat {
        CGFloat(min(1, max(0, fraction)))
    }
}
