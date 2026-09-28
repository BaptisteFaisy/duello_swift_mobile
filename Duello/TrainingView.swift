import SwiftUI

/// Onglet « Entraînement » : les matières du parcours, leur programme en
/// chapitres. Reprend la structure de `src/screens/SubjectsScreen.tsx`
/// (liste des matières, puis chapitres d'une matière).
struct TrainingView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var progress: ProgressStore

    /// Année du programme choisie dans le sélecteur de l'en-tête. `nil` = celle
    /// du compte, comme `localProgramYear` de la source.
    @State private var programYearOverride: Int?

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
                    SubjDeferredFeatureFallback(label: "Ouverture du parcours…")
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
        }
        .task(id: programYear) { await loadSubjectTotals() }
    }

    /// La matière ouverte d'office par l'onglet Entraînement (`maths`), ou `nil`
    /// si le parcours n'en propose pas — la liste des matières prend alors le
    /// relais, comme `listedSubjects` côté Expo.
    private var mathsSubject: TrackSubject? {
        subjects.first { $0.id == SubjHecJourneyConstants.mathsSubjectId }
    }

    /// L'onglet Parcours ouvre le parcours HEC guidé des maths dans la variante
    /// de développement seulement (`shouldOpenJourneyOnLaunch`, entrée
    /// « training »). La surface du parcours est portée par un autre lot : on
    /// s'arrête ici sur son repli, et la garde reste inerte en production.
    private var showsHecJourney: Bool {
        SubjHecJourneyEntry.shouldOpenJourneyOnLaunch(
            subjectId: SubjHecJourneyConstants.mathsSubjectId,
            entryPoint: .training,
            isDevelopmentApp: SubjAppVariant.isDevelopmentApp
        )
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
                    NavigationLink {
                        TrainingCatalogView(subject: subject)
                    } label: {
                        SubjectRow(
                            subject: subject,
                            succeeded: succeededCount(subject),
                            total: subjectTotals[subject.id] ?? 0,
                            progressLoaded: totalsLoaded
                        )
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
