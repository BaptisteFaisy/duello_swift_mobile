//
//  AnnReaderFooter.swift
//  Duello
//
//  Pied du lecteur d'annale (épreuves écrites) : panneau « Annale en cours » et
//  navigation entre annales.
//
//  Port de `src/components/AnnaleViewer.tsx` (`dsUnlockPanel`, `dsUnlockCopy`,
//  `dsCorrectionActions`, `dsUnlockButton`/`dsSecondaryButton`,
//  `siblingNavigation`).
//
//  Écarts assumés (2026-09-29) :
//   - les icônes du panneau sont rendues par `IonIcon` (glyphes Ionicons du RN :
//     `lock-open-outline`/`time-outline` 19, `document-text-outline`/
//     `checkmark-circle-outline`/`camera-outline` 18). Les boutons
//     `AnnSolidButton`/`AnnOutlineButton` de `AnnReaderControls.swift` rendent
//     encore des SF Symbols et ne sont pas modifiables dans ce lot : le panneau
//     porte donc ses propres boutons, alignés sur `dsSecondaryButton`/
//     `dsUnlockButton` (`AnnaleViewer.tsx:5584-5618`). La navigation entre
//     annales (`chevron.left`/`chevron.right`) reste hors de l'écart d'icônes.
//
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
            IonIcon(name: dsUnlocked ? "lock-open-outline" : "time-outline", size: 19, color: Theme.primary)
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
                    dsSecondaryButton("Voir le corrigé officiel", ionIcon: "document-text-outline") {
                        mode = .solution
                    }
                } else {
                    Text("Le corrigé officiel n’est pas encore disponible.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                dsSecondaryButton(
                    "Les \(entry.durationHours) h sont écoulées",
                    ionIcon: "checkmark-circle-outline"
                ) {
                    dsUnlocked = true
                    if entry.hasOfficialSolution { mode = .solution }
                }
            }

            dsUnlockButton(copyButtonTitle, ionIcon: copyButtonIcon) {
                reloadCopyJob()
                copySheetOpen = true
            }
        }
    }

    /// `dsSecondaryButton` (`AnnaleViewer.tsx:5602-5618`) : bord `primary` 1 pt,
    /// icône Ionicons 18 `primary`, libellé 13/900 `primary`.
    private func dsSecondaryButton(
        _ title: String,
        ionIcon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                IonIcon(name: ionIcon, size: 18, color: Theme.primary)
                Text(title)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.horizontal, 16)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.primary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// `dsUnlockButton` (`AnnaleViewer.tsx:5584-5598`) : fond `primary`, icône
    /// Ionicons 18 blanche, libellé 13/900 blanc.
    private func dsUnlockButton(
        _ title: String,
        ionIcon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                IonIcon(name: ionIcon, size: 18, color: Theme.surface)
                Text(title)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Theme.surface)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.horizontal, 16)
            .background(Theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
    }

    private var copyButtonTitle: String {
        if copyJob?.status == .ready { return "Ouvrir mes corrections" }
        if copyJob != nil { return "Suivre mes corrections" }
        return "Soumettre une partie"
    }

    private var copyButtonIcon: String {
        copyJob?.status == .ready ? "checkmark-circle-outline" : "camera-outline"
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
