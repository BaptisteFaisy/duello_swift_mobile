import SwiftUI

// MARK: - Pied de lecteur (épreuves écrites) et aides

extension AnnReaderView {
    // MARK: Pied de lecteur

    var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            if entry.isWrittenPaper {
                dsUnlockPanel
            }
            siblingNavigation
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(Theme.surface)
        .overlay(
            Rectangle().fill(Theme.border).frame(height: 1),
            alignment: .top
        )
    }

    /// Panneau « Annale en cours » des épreuves écrites : déverrouillage du
    /// corrigé officiel et dépôt d'une partie de copie.
    private var dsUnlockPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            dsUnlockHeader
            dsUnlockActions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duelloCard()
    }

    /// Bandeau d'état du panneau « Annale en cours » (icône, titre, aide).
    private var dsUnlockHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: dsUnlocked ? "lock.open" : "clock")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 3) {
                Text(dsUnlocked
                     ? "Corrigé officiel déverrouillé"
                     : "Annale en cours · \(entry.durationLabel) au total")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(dsUnlocked
                     ? "Tu peux consulter le corrigé et retrouver les corrections de chaque partie."
                     : "Travaille à ton rythme : tu pourras soumettre chaque partie séparément.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
    }

    /// Boutons du panneau « Annale en cours » : déverrouillage et copie.
    private var dsUnlockActions: some View {
        VStack(spacing: 8) {
            if dsUnlocked {
                if entry.hasOfficialSolution {
                    AnnOutlineButton(title: "Voir le corrigé officiel", icon: "doc.text") {
                        mode = .solution
                    }
                } else {
                    Text("Le corrigé officiel n’est pas encore disponible.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                AnnOutlineButton(
                    title: "Les \(entry.durationHours) h sont écoulées",
                    icon: "checkmark.circle"
                ) {
                    dsUnlocked = true
                    if entry.hasOfficialSolution { mode = .solution }
                }
            }

            AnnSolidButton(title: copyButtonTitle, icon: copyButtonIcon) {
                reloadCopyJob()
                copySheetOpen = true
            }
        }
    }

    private var copyButtonTitle: String {
        if copyJob?.status == .ready { return "Ouvrir mes corrections" }
        if copyJob != nil { return "Suivre mes corrections" }
        return "Soumettre une partie"
    }

    private var copyButtonIcon: String {
        copyJob?.status == .ready ? "checkmark.circle" : "camera"
    }

    /// Passage d'une annale à la précédente ou à la suivante.
    @ViewBuilder
    private var siblingNavigation: some View {
        if siblings.count > 1, let index = siblings.firstIndex(where: { $0.id == entry.id }) {
            HStack(spacing: 10) {
                AnnOutlineButton(title: "Annale précédente", icon: "chevron.left") {
                    openSibling(at: index - 1)
                }
                .disabled(index == 0)
                .opacity(index == 0 ? 0.45 : 1)

                AnnOutlineButton(title: "Annale suivante", icon: "chevron.right") {
                    openSibling(at: index + 1)
                }
                .disabled(index == siblings.count - 1)
                .opacity(index == siblings.count - 1 ? 0.45 : 1)
            }
        }
    }

    // MARK: Aides

    /// Recharge la fiche de correction la plus récente de cette annale
    /// (`AnnaleViewer` : dernier job trié par `updatedAt`).
    func reloadCopyJob() {
        let latest = monitor.jobs(for: entry.id).first
        copyJob = latest
    }

    /// Change d'annale depuis la même fenêtre de lecture. Le changement d'état
    /// déclenche la remise à zéro de l'onglet, de la question et du
    /// déverrouillage, comme à l'ouverture d'un nouveau sujet.
    private func openSibling(at index: Int) {
        guard siblings.indices.contains(index) else { return }
        entry = siblings[index]
    }
}
