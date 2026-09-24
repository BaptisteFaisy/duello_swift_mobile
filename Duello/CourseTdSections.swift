import SwiftUI

/// Sections du panneau « Mon TD » (`src/components/CourseTdPanel.tsx`).
///
/// Chaque vue reprend une carte du panneau Expo, avec ses libellés mot pour
/// mot. Les mesures viennent de `Theme` ; la carte d'erreur porte le rose
/// pâle exact du source (`#FCE0E0`, codé en dur car absent de `Theme`).

// MARK: - En-tête

/// En-tête « Mon TD » : icône école, titre et sous-titre.
struct CtdPanelHeading: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "graduationcap")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 2) {
                Text("Mon TD")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("OCR mathématique et indexation concours")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Cours manquant

/// Cours du chapitre absent : le panneau reste verrouillé (`lockedCard`).
///
/// Le source utilise l'Ionicons `lock-closed-outline` (taille 30) ; le SF
/// Symbol `lock` en est le plus proche, sans être identique (contour du
/// cadenas différent). Le texte est en graisse par défaut (400) avec
/// `lineHeight: 19`.
struct CtdLockedCard: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "lock")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Importe d’abord ton cours")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Theme.ink)
                .padding(.top, 10)
            Text("L’IA utilise le cours du chapitre pour identifier les théorèmes et les hypothèses de ton TD.")
                .font(.system(size: 13, weight: .regular))
                .lineSpacing(6)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Invitation à importer

/// Aucune feuille importée : présentation de l'indexation et bouton
/// d'import (`introCard`).
struct CtdIntroCard: View {
    let importing: Bool
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Transforme ta feuille en exercices indexés")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Theme.ink)
            Text("Duello lit le PDF ou la photo, conserve les formules en LaTeX/KaTeX, sépare les exercices et classe chaque question.")
                // `introText` : graisse par défaut (400), `lineHeight: 19`.
                .font(.system(size: 13, weight: .regular))
                .lineSpacing(6)
                .foregroundStyle(Theme.inkSoft)
            Button(action: onImport) {
                HStack(spacing: 8) {
                    if importing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Theme.surface)
                    } else {
                        // Ionicons `cloud-upload-outline` (taille 20) côté
                        // source ; pas d'équivalent SF exact (voir rapport).
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 20, weight: .bold))
                    }
                    Text(importing ? "Import en cours…" : "Importer ma feuille de TD")
                        .font(.system(size: 14, weight: .heavy))
                }
                .foregroundStyle(Theme.surface)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                .opacity(importing ? 0.5 : 1)
            }
            .buttonStyle(.plain)
            .disabled(importing)
            .accessibilityLabel("Importer et analyser ma feuille de TD")
            .padding(.top, 4)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
    }
}

// MARK: - Feuille importée

/// Feuille importée : nom, taille et remplacement (`fileRow`).
///
/// Le source utilise l'Ionicons `document-text-outline` (taille 21) ; le SF
/// Symbol `doc.text` en est le plus proche, sans être identique. Le bouton
/// « Remplacer » porte la couleur `primary` du thème — qui vaut l'encre, comme
/// `Theme.ink`.
struct CtdFileRow: View {
    let name: String
    let sizeLabel: String
    let busy: Bool
    let onReplace: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(sizeLabel)
                    // `fileMeta` : graisse par défaut (400).
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 8)
            Button(action: onReplace) {
                Text("Remplacer")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
            .disabled(busy)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 58)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Analyse en cours

/// Analyse mathématique en cours (`analysisProgress`).
struct CtdAnalysisProgressCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Theme.ink)
            VStack(alignment: .leading, spacing: 3) {
                Text("Analyse mathématique en cours…")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("Lecture des formules, découpage des exercices et indexation des questions.")
                    // `analysisProgressText` : graisse par défaut (400),
                    // `lineHeight: 17`.
                    .font(.system(size: 12, weight: .regular))
                    .lineSpacing(5)
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }
}

// MARK: - Message

/// Carte de message du panneau : erreur d'analyse ou analyse périmée
/// (`errorCard`), avec une action facultative. Le fond est le rose pâle exact
/// du source (`#FCE0E0`) ; le texte porte la couleur `danger` (= l'encre).
struct CtdMessageCard: View {
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(message)
                // `errorText` : 12 / 700, `lineHeight: 18`.
                .font(.system(size: 12, weight: .bold))
                .lineSpacing(6)
                .foregroundStyle(Theme.ink)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
                // `retryButton` : zone tactile haute de 10 pt autour du texte.
                .padding(.vertical, 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color(hex: 0xFCE0E0))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }
}

// MARK: - Résultats

/// Résultats de l'indexation : chapitre identifié, compte des questions et
/// cartes d'exercices (`results`).
struct CtdResultsSection: View {
    let analysis: CtdAnalysis
    let questionCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CtdChapterCard(analysis: analysis)
            VStack(alignment: .leading, spacing: 2) {
                Text("Indexation concours")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text(summary)
                    // `resultsCount` : graisse par défaut (400).
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.top, 5)
            ForEach(analysis.exercises) { exercise in
                CtdExerciseCard(exercise: exercise)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// « 2 exercices · 7 questions » : pluriel seulement au-delà de un.
    private var summary: String {
        let exercises = analysis.exercises.count
        let exerciseWord = "\(exercises) exercice\(exercises > 1 ? "s" : "")"
        let questionWord = "\(questionCount) question\(questionCount > 1 ? "s" : "")"
        return "\(exerciseWord) · \(questionWord)"
    }
}

/// Chapitre identifié par l'IA et fiabilité du rapprochement (`chapterCard`).
struct CtdChapterCard: View {
    let analysis: CtdAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CHAPITRE IDENTIFIÉ")
                .font(.system(size: 10, weight: .black))
                .kerning(0.5)
                .foregroundStyle(Theme.inkSoft)
            Text(analysis.identifiedChapter)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.ink)
                .padding(.top, 4)
            Text(analysis.chapterMatch.label)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }
}
