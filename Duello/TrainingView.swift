import SwiftUI

/// Onglet « Entraînement » : les matières du parcours, leur programme en
/// chapitres. Reprend la structure de `src/screens/SubjectsScreen.tsx`
/// (liste des matières, puis chapitres d'une matière).
struct TrainingView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        NavigationStack {
            Group {
                if subjects.isEmpty {
                    emptyState
                } else {
                    subjectList
                }
            }
            .background(Theme.background)
            .navigationTitle("Entraînement")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var subjects: [TrackSubject] {
        DuelloProgram.subjects(
            track: session.profile.track,
            specialty: session.profile.specialty,
            year: session.profile.year
        )
    }

    private var subjectList: some View {
        List {
            Section {
                ForEach(subjects) { subject in
                    NavigationLink {
                        ChapterListView(subject: subject)
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
