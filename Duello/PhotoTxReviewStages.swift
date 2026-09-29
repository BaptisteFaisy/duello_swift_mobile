//
//  PhotoTxReviewStages.swift
//  Duello
//
//  Étapes de lecture et de relecture de la transcription photo.
//  Découpage de `PhotoTranscriptionView.swift` — aucun changement de comportement
//  (mêmes noms, mêmes corps, mêmes chaînes, mêmes visibilités EFFECTIVES).
//

import SwiftUI
import UIKit

// MARK: - Étape de lecture

/// Port de `PhotoReadingStage.tsx` : aperçu de la dernière image et avancement.
/// `readingCard` : colonne centrée, gap 12, marges 22/12, **sans fond de carte** ;
/// l'aperçu fait 100 % × 160, rayon `large` (18), fond `surfaceMuted`.
struct PhotoTxReadingStage: View {
    let imageUris: [String]
    let progress: PhotoTxProgress
    private var previewSource: CachedImageSource? {
        let index = max(0, progress.current - 1)
        guard imageUris.indices.contains(index) else { return nil }
        return .file(imageUris[index])
    }
    var body: some View {
        VStack(spacing: 12) {
            if let source = previewSource {
                CachedImage(source) { image in
                    image.resizable().scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .background(Theme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
                } placeholder: {
                    EmptyView()
                }
            }
            ProgressView().tint(Theme.primary)
            Text(progress.total > 1 ? "Analyse des images \(progress.current)/\(progress.total)…" : PhotoTxText.readingSingle)
                .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }
}

// MARK: - Étape de relecture

/// Port de `PhotoReviewStage.tsx` : vignette, badge de source, texte éditable,
/// puis reprise ou insertion.
struct PhotoTxReviewStage: View {
    @ObservedObject var controller: PhotoTxController
    private var state: PhotoTxState { controller.state }
    private var hasText: Bool { !state.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    /// `containsMultilineMatrix || containsCodeBlock` : bascule l'éditeur en police
    /// monospace (`matrixTextInput`, Menlo).
    private var isMonospace: Bool {
        StmtLatex.containsMultilineMatrix(state.text) || StmtAnswerSupport.containsCodeBlock(state.text)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if !state.notice.isEmpty {
                Text(state.notice)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            editor
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    /// `reviewHeader` : rangée alignée au centre, gap 12, marginTop 16 ; vignette
    /// 58×58 rayon `medium` ; badge `sparkles` 12 `primary` sur `primaryLight`.
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if let first = state.imageUris.first {
                CachedImage(.file(first)) { image in
                    image.resizable().scaledToFill()
                        .frame(width: 58, height: 58)
                        .background(Theme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                } placeholder: {
                    EmptyView()
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                sourceBadge
                if state.imageUris.count > 1 {
                    Text("\(state.imageUris.count) images analysées")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.inkSoft)
                }
                Text(PhotoTxText.reviewHint)
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 16)
    }
    /// `sourceBadge` : icône 12 + texte 9 (900) en `primary`, fond `primaryLight`,
    /// pastille. Le libellé n'est **pas** mis en capitales (contrairement à une puce).
    private var sourceBadge: some View {
        HStack(spacing: 5) {
            IonIcon(name: "sparkles", size: 12, color: Theme.primary)
            Text(PhotoTxText.premiumSourceLabel(engine: state.engine, model: state.model))
                .font(.system(size: 9, weight: .black)).foregroundStyle(Theme.primary)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 9)
        .background(Theme.primaryLight)
        .clipShape(Capsule())
    }
    /// `textCard` : maxHeight 210, marginTop 13, bord `border` 1.5, rayon `medium`,
    /// fond `surfaceMuted` ; `textInput` : minHeight 140, padding 13, 13/500.
    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: Binding(get: { state.text }, set: { controller.dispatch(.setText($0)) }))
                .font(isMonospace
                      ? .system(size: 13, weight: .medium, design: .monospaced)
                      : .system(size: 13, weight: .medium))
                .foregroundStyle(Theme.ink)
                .scrollContentBackground(.hidden)
                .padding(13)
                .frame(minHeight: 140)
                .accessibilityLabel(PhotoTxText.transcribedLabel)
            if state.text.isEmpty {
                Text(PhotoTxText.emptyText).font(.system(size: 13)).foregroundStyle(Theme.inkFaint)
                    .padding(.top, 21).padding(.leading, 18).allowsHitTesting(false)
            }
        }
        .frame(maxHeight: 210)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMedium).stroke(Theme.border, lineWidth: 1.5))
        .padding(.top, 13)
    }
    /// `reviewActions` : rangée, gap 10, marginTop 14 ; « Reprendre » = secondaire
    /// (`refresh` 17 primary sur fond `surface`, bord `primary` 1.5) ; « Insérer » =
    /// primaire (`arrow-down` 17 blanc, fond `primary`, désactivé à 0.4).
    private var actions: some View {
        HStack(spacing: 10) {
            Button { controller.dispatch(.restart) } label: {
                HStack(spacing: 8) {
                    IonIcon(name: "refresh", size: 17, color: Theme.primary)
                    Text(PhotoTxText.restart)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.primary, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            Button { controller.dispatch(.insert) } label: {
                HStack(spacing: 8) {
                    IonIcon(name: "arrow-down", size: 17, color: Theme.surface)
                    Text(PhotoTxText.insert)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.surface)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!hasText).opacity(hasText ? 1 : 0.4)
        }
        .padding(.top, 14)
    }
}
