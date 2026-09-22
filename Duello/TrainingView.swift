import SwiftUI

/// Onglet « Entraînement » : les matières du parcours, leur programme en
/// chapitres. Reprend la structure de `src/screens/SubjectsScreen.tsx`
/// (liste des matières, puis chapitres d'une matière).
struct TrainingView: View {
    @EnvironmentObject private var session: SessionStore

    /// Année du programme choisie dans le sélecteur de l'en-tête. `nil` = celle
    /// du compte, comme `localProgramYear` de la source.
    @State private var programYearOverride: Int?

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
                } else if subjects.isEmpty {
                    emptyState
                        .navigationTitle("Entraînement")
                        .navigationBarTitleDisplayMode(.inline)
                } else {
                    subjectList
                        .navigationTitle("Entraînement")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .background(Theme.background)
        }
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

    private var subjectList: some View {
        List {
            Section {
                ForEach(subjects) { subject in
                    NavigationLink {
                        TrainingCatalogView(subject: subject)
                    } label: {
                        SubjectRow(subject: subject)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                }
            } footer: {
                Text("Choisis une matière pour voir son programme et lancer un entraînement.")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "barbell")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            Text("Choisis ton parcours dans « Mon compte »")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SubjectRow: View {
    let subject: TrackSubject

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .fill(Theme.primaryLight)
                    .frame(width: 42, height: 42)
                Image(systemName: subject.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(subject.name)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if let fullName = subject.fullName {
                    Text(fullName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("\(subject.chapters.count) ch.")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
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
