import SwiftUI
import UIKit

// MARK: - Dépôt d'une partie

/// Dépôt d'une partie : parties déjà soumises, libellé de la partie, envoi des
/// pages. Extension de `AnnCopyCorrectionSheet`.
extension AnnCopyCorrectionSheet {
    var depositContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Parties déjà soumises")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    ForEach(history) { entry in
                        Button {
                            job = entry
                            onJobChange(entry)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.partLabel)
                                        .font(.system(size: 14, weight: .heavy))
                                        .foregroundStyle(Theme.ink)
                                    Text(entry.statusLabel)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.inkSoft)
                                }
                                Spacer(minLength: 8)
                                if entry.status == .ready, let result = entry.result {
                                    Text("\(result.scoreLabel)/20")
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundStyle(Theme.ink)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Theme.inkSoft)
                                }
                            }
                            .padding(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Ouvrir la correction \(entry.partLabel)")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Partie à faire corriger")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                TextField("Ex. Exercice 1, partie II", text: $partLabel)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMedium)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .accessibilityLabel("Partie à faire corriger")
                Text("Tu pourras revenir un autre jour et soumettre une autre partie séparément.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }

            Text("Ajoute uniquement les pages de cette partie, dans l’ordre. Vérifie qu’elles sont nettes, cadrées et sans reflet.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)

            VStack(spacing: 10) {
                AnnOutlineButton(title: "Photographier une page", icon: "camera") {
                    requestCamera()
                }
                AnnOutlineButton(title: "Importer plusieurs photos", icon: "photo.on.rectangle") {
                    errorMessage = ""
                    activePicker = .library
                }
            }

            pageGrid

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bell")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Tu seras prévenu dans Duello, ou sur ton téléphone si l’application est fermée.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )

            submitButton
        }
    }

    private var submitButton: some View {
        let disabled = pages.isEmpty || partLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || submitting
        return Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 9) {
                if submitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Theme.surface)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                }
                Text(submitLabel)
                    .font(.system(size: 14, weight: .heavy))
            }
            .foregroundStyle(Theme.surface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var submitLabel: String {
        if submitting { return "Envoi \(uploadProgress)%…" }
        let count = pages.count
        return "Lancer la correction (\(count) page\(count > 1 ? "s" : ""))"
    }

    // MARK: Aides de données

    /// Parties déjà soumises pour cette annale, la plus récente d'abord.
    private var history: [AnnCopyJob] {
        monitor.jobs(for: itemId).filter { $0.jobId != job?.jobId }
    }

    // MARK: Actions

    private func submit() async {
        let trimmed = partLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if submitting || job != nil || pages.isEmpty { return }
        guard !trimmed.isEmpty else {
            errorMessage = "Indique la partie de l’annale couverte par ces pages."
            return
        }
        submitting = true
        errorMessage = ""
        uploadProgress = 0
        let snapshot = pages
        do {
            let created = try await AnnCopyService.submit(
                attemptKey: attemptKey,
                itemId: itemId,
                title: title,
                partLabel: trimmed,
                subject: subject,
                statement: statement,
                solution: solution,
                durationMinutes: durationMinutes,
                pages: snapshot,
                token: session.token,
                onProgress: { value in
                    Task { @MainActor in uploadProgress = value }
                }
            )
            job = created
            monitor.upsert(created)
            onJobChange(created)
        } catch let error as DirectoryError {
            let message = error.message.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = message.isEmpty ? "La copie n’a pas pu être envoyée." : message
        } catch {
            errorMessage = "La copie n’a pas pu être envoyée."
        }
        submitting = false
    }
}
