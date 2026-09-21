import SwiftUI

// MARK: - Suivi de la correction

/// Suivi de la correction en cours : état, progression, relance et sondage.
/// Extension de `AnnCopyCorrectionSheet`.
extension AnnCopyCorrectionSheet {
    func progressContent(job: AnnCopyJob) -> some View {
        VStack(spacing: 13) {
            if job.status == .failed {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Theme.like)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Theme.ink)
            }
            Text(job.statusLabel)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(job.partLabel)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            if !job.estimateLabel.isEmpty {
                Text("Temps restant estimé : \(job.estimateLabel)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            DuelloProgressTrack(fraction: job.progressFraction, tint: Theme.ink, height: 8)
            Text(job.error ?? "Tu peux quitter cette page : la correction continue sur le serveur.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)

            if job.status == .failed {
                AnnSolidButton(title: "Relancer la correction", icon: "arrow.clockwise") {
                    Task { await retry(job: job) }
                }
            }
            AnnOutlineButton(title: "Voir ou soumettre une autre partie", icon: "square.stack") {
                onNewAttempt()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func retry(job: AnnCopyJob) async {
        do {
            let refreshed = try await AnnCopyService.retry(job: job, token: session.token)
            self.job = refreshed
            monitor.upsert(refreshed)
            onJobChange(refreshed)
        } catch {
            errorMessage = "La correction n’a pas pu être relancée."
        }
    }

    // MARK: Suivi de la correction affichée

    /// Identifiant de suivi : la boucle de rafraîchissement repart dès que la
    /// fiche change (`useVisibleAnnaleCopyJob`).
    var pollingKey: String {
        guard let job else { return "aucune" }
        return "\(job.jobId)-\(job.status.rawValue)-\(Int(job.updatedAt))"
    }

    /// Une seule lecture à la fois, uniquement tant que la copie est active ;
    /// une coupure réseau n'annule pas le travail du serveur, la boucle repart
    /// donc au tour suivant. Le retour au premier plan relance la boucle via
    /// l'identifiant de tâche, et la fermeture de la fenêtre l'interrompt.
    func pollActiveJob() async {
        guard let current = job, current.isActive else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(AnnCopyService.visibleRefreshInterval * 1_000_000_000))
            if Task.isCancelled { return }
            guard let refreshed = try? await AnnCopyService.refresh(job: current, token: session.token) else {
                continue
            }
            job = refreshed
            monitor.upsert(refreshed)
            onJobChange(refreshed)
            if !refreshed.isActive { return }
        }
    }
}
