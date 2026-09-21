import SwiftUI

/// États de chargement du catalogue et regroupement des chapitres par
/// domaine. Extension de `TrainingCatalogView`.
extension TrainingCatalogView {

    // MARK: Corps

    @ViewBuilder
    var content: some View {
        switch state {
        case .idle, .loading:
            loadingBlock
        case .error:
            errorBlock
        case .ready:
            if subject.chapters.isEmpty {
                DuelloEmptyState(
                    icon: "books.vertical",
                    title: "Aucun chapitre",
                    message: "Le programme de cette matière n’est pas encore disponible."
                )
                .padding(.top, 24)
            } else {
                catalogueSection
            }
        }
    }

    /// Chargement du manifeste, porté comme repli plein écran
    /// (`DeferredFeatureFallback` de l'écran Expo).
    private var loadingBlock: some View {
        SubjDeferredFeatureFallback(label: "Ouverture du catalogue…")
            .frame(minHeight: 220)
    }

    private var errorBlock: some View {
        VStack(spacing: 14) {
            DuelloEmptyState(
                icon: "exclamationmark.triangle",
                title: "Contenu indisponible",
                message: manifestError
            )
            Button {
                retry()
            } label: {
                Text("Réessayer")
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(DuelloPrimaryButton())
        }
        .padding(.top, 24)
    }

    /// Programme de la matière, groupé par domaine puis chapitre par chapitre.
    /// Le titre de domaine est celui de l'écran Matières (`DomainHeading`), pas
    /// l'en-tête de section du kit partagé.
    @ViewBuilder
    var chapterCatalogue: some View {
        VStack(alignment: .leading, spacing: 0) {
            if subject.id != "maths" && subjectTotals.available > 0 {
                availabilityBanner
            }
            ForEach(TrainChapterGroup.grouped(subject.chapters)) { group in
                SubjDomainHeading(label: group.title ?? "Autres chapitres")
                ForEach(group.chapters) { chapter in
                    chapterBlock(chapter)
                }
            }
        }
    }

    /// Bandeau d'annonce de la matière, affiché hors mathématiques comme dans
    /// `SubjectsScreen` : « 12 exercices disponibles dans 4 chapitres · 3 avec
    /// corrigé ».
    private var availabilityBanner: some View {
        let totals = subjectTotals
        var text = "\(TrainCopy.availability(.exercise, count: totals.available)) dans \(totals.chapters) chapitre\(totals.chapters > 1 ? "s" : "")"
        if totals.withSolution > 0 {
            text += " · \(totals.withSolution) avec corrigé"
        }
        return HStack(spacing: 10) {
            Image(systemName: "books.vertical")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.progress)
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .padding(.top, 14)
    }

    /// Sujets servis, chapitres pourvus et corrigés disponibles de la matière
    /// (`ModeAvailability` de l'écran Expo). Les corrigés ne sont connus
    /// qu'après chargement d'un chapitre : le compte augmente au fil des
    /// dépliages, jamais à rebours.
    private var subjectTotals: SubjModeAvailability {
        var totals = SubjModeAvailability.empty
        for chapter in subject.chapters {
            guard let descriptor = descriptors[chapter.id] else { continue }
            totals.available += descriptor.count
            totals.chapters += 1
            totals.withSolution += (loadedExercises[chapter.id] ?? []).filter { $0.hasSolution }.count
        }
        return totals
    }
}
