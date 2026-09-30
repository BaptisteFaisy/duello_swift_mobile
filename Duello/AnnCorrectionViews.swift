//
//  AnnCorrectionViews.swift
//  Duello
//
//  Atelier de correction du lecteur d'annale (P0 18#2) : la remarque d'une
//  question corrigée, l'encart du bilan terminé et le dock du prof en relecture
//  du corrigé.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/exercise-correction/QuestionRemark.tsx      (`AnnQuestionRemark`)
//    - src/components/exercise-correction/ExerciseResultCard.tsx  (`AnnResultCard`)
//    - src/components/AnnaleViewer.tsx (`CorrectionProfDock`, :1039) (`AnnCorrectionProfDock`)
//
//  Réutilise sans les redéfinir : `AnnVerdict` (couleur, libellé, icône du
//  verdict), `ExGCorrectionResultTiles` et `ExGCorrectionGeneralReportBlock`
//  (tuiles de résultats et compte rendu général du bilan), `LatexToUnicode`.
//
//  Écarts assumés : `accessibilityLiveRegion="polite"` de la mention n'a pas
//  d'équivalent SwiftUI ; `ChatSendButton` partagé de la source est rendu par un
//  bouton rond local ; les lignes de questions et les boutons de reprise du
//  bilan vivent sur la copie elle-même (voir `AnnReaderContent`).
//
//  Cible : iOS 16.
//
import SwiftUI

// MARK: - Remarque d'une question corrigée

/// `QuestionRemark` : la mention du verdict, puis ce que le correcteur en dit,
/// sous le numéro de la question et au-dessus du champ de réponse.
struct AnnQuestionRemark: View {
    let label: String
    let review: AnnQuestionReview

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                AnnQuestionNumberBadge(label: label)
                Text(review.verdict.label)
                    .font(.system(size: 10, weight: .black))
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(review.verdict.color)
                IonIcon(name: review.verdict.icon, size: 13, color: review.verdict.color)
            }
            Text(LatexToUnicode.toUnicodeMath(review.feedback))
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .padding(.bottom, 8)
    }
}

/// `QuestionNumberBadge` : numéro de question, gris sur pastille grise.
private struct AnnQuestionNumberBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.inkSoft)
            .padding(.horizontal, 6)
            .frame(minWidth: 26, minHeight: 26)
            .background(Theme.border)
            .clipShape(Capsule())
    }
}

// MARK: - Encart du bilan terminé

/// `ExerciseResultCard` : le bilan posé sur la copie, au-dessus des onglets de
/// questions — la croix le referme ; retoucher une réponse le fait disparaître
/// aussi, puisque le bilan ne décrit plus la copie.
struct AnnResultCard: View {
    let scoreOn20: Double?
    let xp: Double
    let exerciseRank: Int?
    let correction: ExGCorrection
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ExGCorrectionResultTiles(scoreOn20: scoreOn20, xp: xp, exerciseRank: exerciseRank)
            ExGCorrectionGeneralReportBlock(correction: correction)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) { closeButton }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            IonIcon(name: "close", size: 20, color: Theme.ink)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fermer le bilan")
    }
}

// MARK: - Dock du prof en relecture du corrigé

/// `CorrectionProfDock` (`AnnaleViewer.tsx:1039`) : en relecture du corrigé, la
/// partie basse n'est plus la copie mais le prof IA — l'élève y tape sa question,
/// qui ouvre le panneau d'explication.
struct AnnCorrectionProfDock: View {
    let onSubmit: (String) -> Void

    @State private var draft = ""

    private var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            profAvatar
            inputField
            sendButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }

    /// `correctionProfAvatar` : le « π » du prof IA, sur fond `primary`.
    private var profAvatar: some View {
        Text("π")
            .font(.system(size: 18, weight: .black))
            .foregroundStyle(Theme.surface)
            .frame(width: 38, height: 38)
            .background(Theme.primary)
            .clipShape(Circle())
    }

    private var inputField: some View {
        TextField("Pose ta question au prof…", text: $draft, axis: .vertical)
            .font(.system(size: 15))
            .foregroundStyle(Theme.ink)
            .lineLimit(1...4)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .accessibilityLabel("Poser une question au prof IA sur ce corrigé")
            .onSubmit(submit)
    }

    private var sendButton: some View {
        Button(action: submit) {
            IonIcon(name: "send", size: 18, color: Theme.surface)
                .frame(width: 38, height: 38)
                .background(canSubmit ? Theme.primary : Theme.surfaceMuted)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .accessibilityLabel("Envoyer au prof IA")
    }

    /// `submit` : vide le champ avant d'ouvrir la demande, comme la source.
    private func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        onSubmit(text)
    }
}
