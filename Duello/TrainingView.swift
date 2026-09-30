import SwiftUI

/// Onglet « Entraînement » : les matières du parcours, leur programme en
/// chapitres. Reprend la structure de `src/screens/SubjectsScreen.tsx`
/// (liste des matières, puis chapitres d'une matière).
///
/// S01 (2026-09-30, producteurs de chrome) : l'onglet déclare son verrou de
/// geste au `RootChromeModel` à partir du classement XP / lecteur d'annale
/// ouverts (publiés par le catalogue, `TrainSwipeLockKey`) et du parcours de
/// développement des maths ouvert (`SubjectsScreen.tsx:4164-4185`) ; la carte
/// des maths ouvre le parcours HEC (`setDevelopmentMathsPageOpen(true)`,
/// `:10078`).
struct TrainingView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var progress: ProgressStore
    /// Chrome racine des onglets (verrou de geste, barre basse).
    @EnvironmentObject private var root: RootChromeModel

    /// Reprise d'un exercice de défi (`continuationRequest` d'Expo,
    /// `SubjectsScreen.tsx:3653,6348`) : remise par la racine (`MainTabView`),
    /// qui bascule sur l'onglet Entraînement. L'ouverture du lecteur appartient
    /// à l'en-tête du catalogue (hors lot R01) : ici, seul le positionnement sur
    /// l'année de l'énoncé est posé (cf. `applyContinuation`).
    var continuation: ChalRunTrainingTarget? = nil

    /// Point d'entrée de l'écran (`entryPoint` de `SubjectsScreen.tsx:3709`) :
    /// `training` pour l'onglet Entraînement, `journey` pour l'onglet Parcours.
    /// Porté depuis S01 : il décide de la carte « Ouvrir le parcours HEC »
    /// (`opensHecJourney`) et de la garde de la surface HEC
    /// (`shouldShowSurface`).
    var entryPoint: SubjHecJourneyEntryPoint = .training

    /// Producteur de masquage de la barre basse (`useScrollChromeVisibility`) :
    /// l'offset du catalogue le fait basculer (`SubjectsScreen.tsx:4196-4212`).
    @StateObject private var bottomBarChrome = DuelloBottomBarChrome()

    /// Année du programme choisie dans le sélecteur de l'en-tête. `nil` = celle
    /// du compte, comme `localProgramYear` de la source.
    @State private var programYearOverride: Int?

    /// `developmentMathsPageOpen` (`SubjectsScreen.tsx:3826`) : vrai quand le
    /// parcours de développement des maths a été ouvert depuis l'en-tête de la
    /// matière. Le déclencheur (`setDevelopmentMathsPageOpen(true)`,
    /// `SubjectsScreen.tsx:10078`, bouton « Ouvrir le parcours HEC ») est posé
    /// ici, sur la carte de la matière maths (`subjectCard`, S01). La
    /// **fermeture** du parcours, elle, est câblée plus bas (`onBack` de la
    /// surface → `false`, `SubjectsScreen.tsx:7653`).
    @State private var developmentMathsPageOpen = false

    /// Verrou de geste du catalogue, publié par ce dernier (`TrainSwipeLockKey`) :
    /// vrai quand le classement XP (`rankingOpen`) ou le lecteur d'annale
    /// (`openAnnale` → `readerEntry`) est ouvert (`SubjectsScreen.tsx:4169-4185`).
    @State private var catalogueSwipeLock = false

    /// Sujets servis par matière (`successSummaries[subject.id].total` de la
    /// source), lus dans le manifeste de contenu.
    @State private var subjectTotals: [String: Int] = [:]
    /// Vrai dès que les totaux sont connus (`progressLoaded`) : la carte annonce
    /// alors « X/Y sujets réussis » au lieu de « Y sujets disponibles ».
    @State private var totalsLoaded = false

    var body: some View {
        NavigationStack {
            Group {
                if showsHecJourney {
                    journeySurface
                        .navigationTitle("Entraînement")
                        .navigationBarTitleDisplayMode(.inline)
                } else if let maths = mathsSubject {
                    // `SubjectsScreen.tsx:3793` : « Entraînement est désormais
                    // directement la page Mathématiques. La liste des matières
                    // … n'est plus une étape avant le programme de maths. »
                    // La liste ne reste que comme repli (maths absente du
                    // parcours) — exactement le `openedSubject ? [openedSubject]
                    // : listedSubjects` de la source.
                    TrainingCatalogView(
                        subject: maths,
                        programYear: programYear,
                        profileYear: profileYear,
                        onSelectYear: { programYearOverride = $0 }
                    )
                } else {
                    // Repli historique : la source ne peint ni pied de liste ni
                    // état vide, la liste des matières se suffit à elle-même.
                    subjectList
                        .navigationTitle("Entraînement")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .background(Theme.background)
            .onPreferenceChange(TrainChromeOffsetKey.self) { offset in
                bottomBarChrome.scroll(offset: Double(offset))
            }
            // Le catalogue publie son propre verrou (`rankingOpen` / lecteur
            // d'annale ouvert) : l'onglet l'ajoute à celui du parcours de
            // développement (`SubjectsScreen.tsx:4169-4185`). La préférence est
            // relevée **dans** la pile de navigation, comme l'offset du chrome.
            .onPreferenceChange(TrainSwipeLockKey.self) { locked in
                catalogueSwipeLock = locked
                declareTabSwipeLock()
            }
        }
        .duelloBottomBarChrome(bottomBarChrome, forTab: MainTabView.trainingTabIndex)
        .task(id: programYear) { await loadSubjectTotals() }
        .onChange(of: continuation) { applyContinuation($0) }
        .onChange(of: developmentMathsPageOpen) { _ in declareTabSwipeLock() }
        .onAppear { declareTabSwipeLock() }
        .onDisappear { unlockTabSwipe() }
    }

    /// La matière ouverte d'office par l'onglet Entraînement (`maths`), ou `nil`
    /// si le parcours n'en propose pas — la liste des matières prend alors le
    /// relais, comme `listedSubjects` côté Expo.
    private var mathsSubject: TrackSubject? {
        subjects.first { $0.id == SubjHecJourneyConstants.mathsSubjectId }
    }

    /// Surface du parcours HEC, montée en différé (`Suspense` + `lazy()` d'Expo,
    /// portés par `SubjHecJourneySurfaceLoader`). Le montage passe au parcours
    /// l'identité du compte — `registeredAt` = `account.createdAt` du registre
    /// local et `accountEmail` = adresse du profil, comme
    /// `SubjectsScreen registeredAt={account.createdAt}` (`App.tsx:2828`).
    private var journeySurface: some View {
        SubjHecJourneySurfaceLoader(load: {}) {
            HecJourneyView(
                profile: session.profile,
                registeredAt: SubjHecJourneyEntry.accountRegistrationDate(
                    forEmail: session.profile.email
                ),
                accountEmail: session.profile.email,
                // `onBack` de la source quand l'onglet n'est pas « Parcours »
                // (`SubjectsScreen.tsx:7653`) : referme le parcours de maths.
                onBack: { developmentMathsPageOpen = false }
            )
        }
    }

    /// `HecJourneySurface` remplace l'écran Entraînement quand l'app est la
    /// variante de développement, qu'aucun chapitre du parcours n'est ouvert et
    /// que la page de développement des maths est ouverte
    /// (`SubjectsScreen.tsx:7628-7632`, `shouldShowSurface`). La surface montée
    /// est la vue du parcours (`HecJourneyView`), et non plus son repli ; la
    /// garde reste inerte en production (variante de développement seulement).
    ///
    /// `journeyChapterOpen` reste faux ici : un chapitre du parcours n'est
    /// ouvert que depuis le parcours lui-même, qui n'est affiché que lorsque
    /// cette garde est vraie.
    private var showsHecJourney: Bool {
        SubjHecJourneyEntry.shouldShowSurface(
            isDevelopmentApp: SubjAppVariant.isDevelopmentApp,
            journeyChapterOpen: false,
            developmentMathsPageOpen: developmentMathsPageOpen,
            entryPoint: entryPoint
        )
    }

    /// Reprend l'exercice d'un défi dans l'Entraînement : positionne le
    /// catalogue sur l'année de l'énoncé (`selectProgramYear`,
    /// `SubjectsScreen.tsx:6350`). L'ouverture du lecteur et du brouillon
    /// (`setOpenAnnale` / `setOpenChapter`) appartient à l'en-tête du catalogue
    /// (`TrainingCatalogView+Entry.swift`, hors lot R01) — à raccorder (vague 6).
    private func applyContinuation(_ target: ChalRunTrainingTarget?) {
        guard let target else { return }
        programYearOverride = target.year.lowercased().contains("2") ? 2 : 1
    }

    /// Déclare le verrou de geste d'onglet au chrome racine
    /// (`onTabSwipeLockChange`, `SubjectsScreen.tsx:4164-4185`) : le classement
    /// XP ouvert ou le lecteur d'annale ouvert (publiés par le catalogue,
    /// `TrainSwipeLockKey`) **ou** le parcours de développement des maths ouvert
    /// figent le balayage.
    private func declareTabSwipeLock() {
        let locked = developmentMathsPageOpen || catalogueSwipeLock
        Task { @MainActor in
            root.setTabSwipeLock(locked, forTab: MainTabView.trainingTabIndex)
        }
    }

    /// Relâche le verrou de geste à la disparition de l'onglet (`cleanup`).
    private func unlockTabSwipe() {
        Task { @MainActor in
            root.setTabSwipeLock(false, forTab: MainTabView.trainingTabIndex)
        }
    }

    /// Année du compte (`toProgramYear` de la source) : « 2 » dans le libellé
    /// signifie 2e année, tout le reste est 1re.
    private var profileYear: Int {
        session.profile.year.lowercased().contains("2") ? 2 : 1
    }

    /// Année du programme affichée : celle choisie dans le sélecteur, à défaut
    /// celle du compte.
    private var programYear: Int {
        programYearOverride ?? profileYear
    }

    private var subjects: [TrackSubject] {
        DuelloProgram.subjects(
            track: session.profile.track,
            specialty: session.profile.specialty,
            year: programYear == 2 ? "2e année" : "1re"
        )
    }

    /// Décompte du catalogue par matière (`successSummaries`), lu dans le
    /// manifeste de contenu — même source que l'en-tête d'une matière.
    private func loadSubjectTotals() async {
        guard let manifest = try? await DuelloAPI.contentManifest() else { return }
        let counts = TrainContent.catalogCounts(
            manifest: manifest,
            track: session.profile.track,
            specialty: session.profile.specialty,
            year: session.profile.year
        )
        var totals: [String: Int] = [:]
        for subject in subjects {
            totals[subject.id] = subject.chapters.reduce(0) { $0 + (counts[$1.id] ?? 0) }
        }
        subjectTotals = totals
        totalsLoaded = true
    }

    /// Sujets réussis d'une matière (`successSummaries[subject.id].succeeded`) :
    /// un sujet réussi ne compte qu'une fois, lu dans l'avancement local.
    private func succeededCount(_ subject: TrackSubject) -> Int {
        let chapterIds = Set(subject.chapters.map { $0.id })
        return progress.items.keys.filter { itemId in
            guard let chapterId = TrainItemID.chapterId(of: itemId) else { return false }
            guard chapterIds.contains(chapterId) else { return false }
            return progress.items[itemId]?.bestOutcome == .success
        }.count
    }

    private var subjectList: some View {
        List {
            Section {
                ForEach(subjects) { subject in
                    subjectCard(subject)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// Carte d'une matière. La carte des maths mène au **parcours HEC** quand
    /// l'écran est monté à l'entrée « parcours » dans la variante de
    /// développement (`opensHecJourney`, `SubjectsScreen.tsx:10072-10079` :
    /// « Ouvrir le parcours HEC ») ; partout ailleurs, elle pousse le programme
    /// de la matière.
    @ViewBuilder
    private func subjectCard(_ subject: TrackSubject) -> some View {
        let row = SubjectRow(
            subject: subject,
            succeeded: succeededCount(subject),
            total: subjectTotals[subject.id] ?? 0,
            progressLoaded: totalsLoaded
        )
        if SubjHecJourneyEntry.shouldOpenJourneyOnLaunch(
            subjectId: subject.id,
            entryPoint: entryPoint
        ) {
            Button {
                // `setDevelopmentMathsPageOpen(true)` (`SubjectsScreen.tsx:10078`).
                developmentMathsPageOpen = true
            } label: {
                row
            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
        } else {
            NavigationLink {
                TrainingCatalogView(subject: subject)
            } label: {
                row
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
        }
    }
}

/// Carte d'une matière (`subjectCard` de la source) : icône de matière, nom,
/// compteur de sujets réussis et barre d'avancement.
private struct SubjectRow: View {
    let subject: TrackSubject
    let succeeded: Int
    let total: Int
    let progressLoaded: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Theme.primaryLight)
                    .frame(width: 44, height: 44)
                IonIcon(name: SubjectIcon.ionName(for: subject.id), size: 20, color: Theme.primary)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(subject.name)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(summaryText)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.primary)
                    .padding(.top, 2)
                subjectProgressTrack
            }
            Spacer(minLength: 0)
            IonIcon(name: "chevron-forward", size: 20, color: Theme.inkSoft)
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// `successSummary.total > 0 ? (progressLoaded ? « X/Y sujets réussis » :
    /// « Y sujets disponibles ») : « Aucun sujet disponible »`.
    private var summaryText: String {
        guard total > 0 else { return "Aucun sujet disponible" }
        return progressLoaded
            ? TrainCopy.subjectSuccess(succeeded: succeeded, total: total)
            : "\(total) sujets disponibles"
    }

    /// Piste d'avancement de la matière (`subjectProgressTrack`) : fond blanc
    /// bordé, remplissage neutre `#D8D8D8`, hauteur 7.
    private var subjectProgressTrack: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5).fill(Theme.surface)
                RoundedRectangle(cornerRadius: 3.5)
                    .fill(Color(hex: 0xD8D8D8))
                    .frame(width: fillWidth(in: geometry.size.width))
            }
        }
        .frame(height: 7)
        .overlay(
            RoundedRectangle(cornerRadius: 3.5).stroke(Theme.border, lineWidth: 1)
        )
        .padding(.top, 7)
    }

    /// Part réussie, avec un départ visible de 8 points dès la première
    /// réussite (`subjectProgressFill`).
    private func fillWidth(in available: CGFloat) -> CGFloat {
        guard progressLoaded, total > 0, succeeded > 0 else { return 0 }
        let fraction = min(1, max(0, Double(succeeded) / Double(total)))
        return max(8, available * CGFloat(fraction))
    }
}

/// Icône Ionicons d'une matière (`TRAINING_MODES` de `src/data/tracks.ts`), par
/// identifiant de matière.
enum SubjectIcon {
    /// Nom logique Ionicons d'une matière, tel qu'écrit dans la source.
    static func ionName(for subjectId: String) -> String {
        switch subjectId {
        case "maths": return "calculator"
        case "physique", "physique-chimie": return "flask"
        case "chimie": return "beaker"
        case "sciences-ingenieur": return "construct"
        case "informatique": return "laptop"
        case "francais-philo": return "book"
        case "anglais": return "language"
        case "lv2": return "chatbubbles"
        default: return "book"
        }
    }
}

/// Chapitres d'une matière, groupés par domaine quand il existe.
struct ChapterListView: View {
    let subject: TrackSubject

    var body: some View {
        List {
            ForEach(grouped, id: \.key) { group in
                Section(group.key) {
                    ForEach(group.chapters) { chapter in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.inkFaint)
                            Text(chapter.name)
                                .font(Theme.readingFont)
                                .foregroundStyle(Theme.ink)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var grouped: [(key: String, chapters: [TrackChapter])] {
        let hasDomains = subject.chapters.contains { $0.domain != nil }
        if !hasDomains {
            return [("", subject.chapters)]
        }
        var order: [String] = []
        var buckets: [String: [TrackChapter]] = [:]
        for chapter in subject.chapters {
            let domain = chapter.domain ?? "Autres"
            if buckets[domain] == nil { order.append(domain) }
            buckets[domain, default: []].append(chapter)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }
}

/// Clé de préférence qui publie le verrou de geste du catalogue
/// (`rankingOpen` / lecteur d'annale ouvert). Le catalogue l'émet
/// (`TrainingCatalogView+Entry`), l'onglet le consomme et l'ajoute au sien
/// (`TrainingView.declareTabSwipeLock`, `SubjectsScreen.tsx:4169-4185`).
struct TrainSwipeLockKey: PreferenceKey {
    static var defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}
