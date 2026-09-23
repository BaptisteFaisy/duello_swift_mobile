//
//  SubjExerciseItemCard.swift
//  Duello
//
//  Lot 9-H « lignes de chapitre, étiquettes et barre de progression »
//  (préfixe `Subj`).
//
//  Fichier source Expo porté :
//    - src/screens/SubjectsScreen.tsx
//        · lignes 3029-3406 : `ExerciseItemCard` (difficulté, meilleure note,
//          prérequis dépliables, avancement, profil de réussite)
//        · styles `itemCard`, `itemCardPressed`, `itemHeader`, `itemTitle`,
//          `itemBadgeRow`, `itemBadgeRowLead`, `itemNumber`,
//          `itemDescriptorBadges`, `itemBestScore`, `itemProgressRow`,
//          `itemProgressValue`, `achievementIcon*`, `itemReturnHighlight`
//
//  Réutilisés, jamais redéfinis : `SubjItemCardModel` / `SubjItemProgress` /
//  `SubjPrerequisiteStatus` / `SubjPrerequisiteCopy` (SubjItemStatus.swift),
//  `SubjItemThemeTag` / `SubjProgramStatusTag` / `SubjExerciseBadgeTag` /
//  `SubjPrerequisiteBadge` (SubjItemTags.swift), `SubjProgressBar`,
//  `SubjReturnHighlightBackground`, `TrainDifficultyPill`, `DuelloAvatar`,
//  `ExGFormat.score`, `MathKbFlowLayout` (enroulement des badges, `flexWrap`).
//
//  Écart assumé avec `TrainExerciseCard` (déjà porté, version réduite au numéro,
//  à la difficulté et à la marque de corrigé) : cette carte-ci porte en plus les
//  statuts que la source affiche — étiquette de thème, signalement de programme,
//  pastille de prérequis dépliable, meilleure note, premier profil de réussite
//  et fond de retour — et le titre y est optionnel (`showTitle`). La source ne
//  duplique pas les deux : `TrainExerciseCard` sert la grille du catalogue,
//  `SubjItemCard` sert la liste de chapitre.
//
//  Limite : `item.firstAchiever` est déjà restreint aux exercices très
//  difficiles par l'appelant (`item.difficulty >= 5`), la carte ne le filtre
//  pas elle-même.
//  Cible iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Carte d'un exercice ou d'une colle (`ExerciseItemCard`).
///
/// La fiche entière ouvre l'énoncé : un bouton dédié en bas de carte ne ferait
/// que doubler ce geste. Les commandes internes — repli des prérequis, profil
/// du premier réussisseur — restent prioritaires sur l'appui.
struct SubjItemCard: View {
    let model: SubjItemCardModel
    /// Position visible dans le chapitre (`itemNumber`).
    var itemNumber: Int?
    var progress: ItemProgress?
    var isReturnHighlighted: Bool = false
    /// Téléchargement ciblé en cours : la fiche est alors inerte.
    var isDownloading: Bool = false
    /// Vrai quand l'énoncé peut s'ouvrir (`canOpen`).
    var isOpenable: Bool = true
    /// Affichage du nom du sujet en tête de fiche (`showTitle`).
    var showsTitle: Bool = true
    /// Masque la barre d'avancement (`isReadOnlyDs`, atelier d'annale écrite).
    var hidesProgress: Bool = false
    let onOpen: () -> Void
    /// Ouvre le profil d'un réussisseur (`onOpenProfile`).
    var onOpenAchieverProfile: ((String) -> Void)?

    @State private var prerequisitesOpen = false

    var body: some View {
        ZStack {
            SubjReturnHighlightBackground(
                highlighted: isReturnHighlighted,
                cornerRadius: Theme.radiusLarge
            )
            VStack(alignment: .leading, spacing: 8) {
                if showsTitle { titleRow }
                badgeRow
                if prerequisitesOpen && hasPrerequisiteDetails { prerequisitesPanel }
                if !hidesProgress && hasProgress { progressRow }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 44)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.bottom, 8)
        .contentShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .onTapGesture { if isEnabled { onOpen() } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isEnabled ? .isButton : [])
    }
}

// MARK: - Calculs d'affichage

private extension SubjItemCard {
    /// État des prérequis (`prerequisiteFilterValue`).
    var prerequisiteStatus: SubjPrerequisiteStatus {
        SubjPrerequisiteStatus.value(
            availableCount: model.availableQuestionCount,
            totalCount: model.totalQuestionCount
        )
    }

    /// Pastille statique dès que les prérequis sont prêts et la relecture faite.
    var isStaticPrerequisiteBadge: Bool {
        prerequisiteStatus == .ready && !model.isPrerequisiteReviewPending
    }

    /// `prerequisiteAccessibilityLabel` : le détail n'est annoncé qu'en partie.
    var prerequisiteAccessibilityText: String {
        switch prerequisiteStatus {
        case .ready: return prerequisiteStatus.rawValue
        case .partly:
            return "En partie \(model.availableQuestionCount)/\(model.totalQuestionCount)"
        case .later: return prerequisiteStatus.rawValue
        }
    }

    /// Le bloc de détail a son propre fond : ouvert sans rien à dire, il
    /// laisserait une bande grise vide sous la ligne de badges.
    var hasPrerequisiteDetails: Bool {
        model.isPrerequisiteReviewPending
            || model.prerequisiteNote != nil
            || !model.missingPrerequisites.isEmpty
            || !model.startedPrerequisites.isEmpty
    }

    /// Recommencer vide la copie courante, jamais le meilleur résultat : une
    /// fiche déjà réussie conserve sa barre à 100 % pendant toutes ses reprises.
    var alreadySucceeded: Bool { progress?.bestOutcome == .success }

    var hasGranularProgress: Bool { model.granularProgress?.isUsable == true }

    var hasProgress: Bool {
        if alreadySucceeded { return true }
        if hasGranularProgress { return (model.granularProgress?.completed ?? 0) > 0 }
        return progress?.bestOutcome != nil
    }

    var fraction: Double {
        if alreadySucceeded { return 1 }
        if hasGranularProgress { return model.granularProgress?.fraction ?? 0 }
        return SubjItemProgress.fraction(progress)
    }

    var percentage: Int { Int((min(1, max(0, fraction)) * 100).rounded()) }

    var formattedBestScore: String? {
        guard let score = model.bestScore else { return nil }
        return ExGFormat.score(score)
    }

    /// `disabled={!canOpen || downloading}`.
    var isEnabled: Bool { isOpenable && !isDownloading }

    var accessibilityLabel: String {
        guard isOpenable else { return model.title }
        return isDownloading
            ? "\(model.title), téléchargement en cours"
            : "Ouvrir l'énoncé de \(model.title)"
    }
}

// MARK: - Lignes de la fiche

private extension SubjItemCard {
    /// Première ligne : le nom du sujet, et son thème à droite.
    var titleRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(model.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let themeLabel = model.themeLabel {
                SubjItemThemeTag(label: themeLabel)
            }
        }
    }

    /// Deuxième ligne : prérequis, puis type, programme et difficulté.
    var badgeRow: some View {
        MathKbFlowLayout(spacing: 4, lineSpacing: 4) {
            if !showsTitle, let themeLabel = model.themeLabel {
                SubjItemThemeTag(label: themeLabel)
            }
            if let itemNumber {
                Text("\(itemNumber)")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.inkSoft)
                    .accessibilityLabel("Sujet \(itemNumber)")
            }
            SubjPrerequisiteBadge(
                status: prerequisiteStatus,
                accessibilityText: prerequisiteAccessibilityText,
                isStatic: isStaticPrerequisiteBadge,
                isExpanded: prerequisitesOpen,
                onToggle: { prerequisitesOpen.toggle() }
            )
            ForEach(model.badges, id: \.self) { badge in
                SubjExerciseBadgeTag(badge: badge)
            }
            SubjProgramStatusTag(status: model.programStatus)
            if let difficulty = model.difficulty {
                TrainDifficultyPill(level: difficulty, showsLabel: false)
            }
            if isDownloading {
                ProgressView()
                    .controlSize(.small)
                    .tint(Theme.inkSoft)
                    .accessibilityLabel("Téléchargement en cours")
            }
            if let formattedBestScore {
                Text(formattedBestScore)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .accessibilityLabel("Meilleure note : \(formattedBestScore)")
            }
            if let achiever = model.firstAchiever {
                achieverButton(achiever)
            }
        }
    }

    /// Troisième ligne : la barre d'avancement et son pourcentage. Le détail
    /// question par question se lit dans le lecteur, pas dans la liste.
    var progressRow: some View {
        HStack(spacing: 8) {
            SubjProgressBar(fraction: fraction, compact: true)
            Text("\(percentage) %")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Avancement : \(percentage) %")
    }

    /// Bloc de détail des prérequis, sur toute la largeur de la fiche.
    var prerequisitesPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.isPrerequisiteReviewPending {
                panelText(SubjPrerequisiteCopy.reviewPending)
            } else {
                if let note = model.prerequisiteNote {
                    panelText(SubjPrerequisiteCopy.note(
                        note,
                        missing: model.missingPrerequisites.count,
                        started: model.startedPrerequisites.count
                    ))
                }
                if model.prerequisiteNote == nil, !model.missingPrerequisites.isEmpty {
                    panelText(SubjPrerequisiteCopy.missing(model.missingPrerequisites))
                }
                if model.prerequisiteNote == nil, !model.startedPrerequisites.isEmpty {
                    panelText(SubjPrerequisiteCopy.started(model.startedPrerequisites))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }

    func panelText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// La fiche distingue uniquement le premier profil renvoyé. Les autres
    /// réussites restent disponibles côté serveur, sans rallonger chaque carte.
    func achieverButton(_ achiever: SubjItemAchiever) -> some View {
        Button {
            onOpenAchieverProfile?(achiever.id)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                achieverAvatar(achiever)
                Text("1")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Theme.surface)
                    .padding(3)
                    .background(Theme.ink)
                    .clipShape(Circle())
                    .offset(x: 2, y: 2)
            }
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Voir le profil de \(achiever.displayName), premier profil affiché parmi les réussites"
        )
    }

    @ViewBuilder
    func achieverAvatar(_ achiever: SubjItemAchiever) -> some View {
        if let url = achiever.photoURL {
            CachedRemoteImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                DuelloAvatar(initial: achiever.initial, size: 28)
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            DuelloAvatar(initial: achiever.initial, size: 28)
        }
    }
}
