//
//  ConsentAiCard.swift
//  Duello
//
//  Consentement au partage avec les prestataires d'IA : la carte de réglage et
//  l'état de consentement.
//
//  Fichiers source Expo portés :
//    - `src/components/AiConsentCard.tsx` (ligne « icône + titre + état +
//      interrupteur », chevron « À quoi sert ce réglage ? ») ;
//    - `src/hooks/useAiDataSharingConsent.ts` (état `accepted` / `busy` /
//      `setEnabled`).
//
//  La persistance versionnée (`hasAiDataSharingConsent`,
//  `requestAiDataSharingConsent`, `revokeAiDataSharingConsent` de
//  `src/utils/aiDataSharingConsent.ts`) et les libellés `AI_CONSENT_POLICY`
//  (`src/legal/privacyPolicy.generated.ts`) sont déjà portés par `CtdAiConsent`
//  (`CourseTdConsent.swift`) : cette carte les réutilise tels quels plutôt que
//  de les redéfinir. Seul `acceptedLabel` (« Traitement par l’IA autorisé »),
//  absent de `CtdAiConsent`, est déclaré ici.
//
//  Cible : iOS 16.
//
import SwiftUI

// MARK: - État de consentement

/// État du consentement au traitement par l'IA (`useAiDataSharingConsent`).
///
/// La source est un hook `{ accepted, busy, setEnabled }` ; le portage expose
/// la lecture et l'écriture, et la carte porte l'état `@State` réactif. La
/// lecture est synchrone (`UserDefaults`), là où la source attend une promesse.
enum ConsentAiSharing {

    /// `AI_CONSENT_POLICY.acceptedLabel` : état affiché quand l'accord est
    /// donné. Absent de `CtdAiConsent`, il vit ici.
    static let acceptedLabel = "Traitement par l’IA autorisé"

    /// `hasAiDataSharingConsent` : accord enregistré pour la version courante.
    static var isGranted: Bool { CtdAiConsent.isGranted }

    /// `setEnabled` : accorde ou retire l'autorisation, renvoie le nouvel état.
    ///
    /// La source appelle `requestAiDataSharingConsent`, qui peut présenter une
    /// fenêtre de confirmation au tout premier envoi ; `CtdAiConsent` (déjà
    /// livré, non modifiable ici) enregistre l'accord sans fenêtre, et cette
    /// carte est un simple basculement de réglage — le consentement explicite
    /// reste donc demandé au premier usage réel d'une fonction IA.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        if enabled { CtdAiConsent.grant() } else { CtdAiConsent.revoke() }
        return enabled
    }
}

// MARK: - Carte

/// Carte de consentement au traitement par l'IA, calquée sur les réglages de
/// notifications : icône, titre, état et interrupteur. Le texte détaillé
/// (destinataires, finalités) n'apparaît que sur appui du chevron.
struct ConsentAiCard: View {

    /// Taille de l'icône, fournie par l'écran hôte (`iconSize`).
    var iconSize: CGFloat = 18

    /// `accepted` : `nil` tant que la valeur n'a pas été relue.
    @State private var accepted: Bool?
    @State private var busy = false
    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row
            detailsToggle
            if showDetails {
                Text(CtdAiConsent.message)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .padding(.leading, 44)
            }
        }
        .duelloCard()
        .task { accepted = ConsentAiSharing.isGranted }
    }

    // MARK: Ligne principale

    /// Icône « sparkles », titre, état, puis l'interrupteur.
    private var row: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text("Traitement par l’IA")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(accepted == true ? ConsentAiSharing.acceptedLabel : CtdAiConsent.declinedLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: enabledBinding)
                .labelsHidden()
                .tint(Theme.ink)
                .disabled(accepted == nil || busy)
                .accessibilityLabel(
                    "Autoriser le traitement par les prestataires d’intelligence artificielle"
                )
        }
    }

    /// Chevron « À quoi sert ce réglage ? » : pivote à 90° une fois déplié.
    private var detailsToggle: some View {
        Button {
            showDetails.toggle()
        } label: {
            HStack(spacing: 4) {
                Text("À quoi sert ce réglage ?")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
                    .rotationEffect(.degrees(showDetails ? 90 : 0))
            }
            .padding(.top, 6)
            .padding(.leading, 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Détails du traitement par l’IA")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Effets

    /// Interrupteur : reflète l'accord courant, écrit l'accord ou le retrait.
    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { accepted == true },
            set: { value in Task { await setEnabled(value) } }
        )
    }

    /// `setEnabled` : un seul basculement à la fois, comme le verrou `busy`.
    @MainActor
    private func setEnabled(_ enabled: Bool) async {
        guard !busy else { return }
        busy = true
        accepted = ConsentAiSharing.setEnabled(enabled)
        busy = false
    }
}
