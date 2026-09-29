//
//  AcctIntDirectorySheet.swift
//  Duello
//
//  LOT 17 — annuaire de l'onglet « Mon compte » (préfixe `AcctInt`).
//
//  Hôte de `AcctSearchView` (lot 10-D) et de son modèle `AcctSearchModel`.
//  Correspond à la section annuaire de `src/screens/AccountScreen.tsx`
//  (`searchQuery`, `directoryProfiles`, `selectedMemberId`), présentée ici en
//  feuille depuis « Mon compte » plutôt qu'en ligne.
//
//  `@MainActor` sur la vue : `AcctSearchModel` est isolé au fil principal, or
//  son initialisation a lieu dans un initialiseur de propriété (non isolé par
//  défaut). C'est le motif déjà employé par `ChalHome2QueuePanel`.
//
//  V2 (2026-09-29, écart 07#16) : la proposition de défi n'est plus figée à
//  faux. `canProposeChallenge` est calculé pour le membre ouvert
//  (`canProposeChallengeToMember`, `challengeInvites.ts:290`), à partir de la
//  filière et de l'option académique du compte (`AccountScreen.tsx:1781-1784`).
//
//  Le blocage (`ReportSafetyAPI.block`) et le signalement (`ReportUserSheet`)
//  sont portés par `AcctSearchView`, comme `requestBlockMember` / `reportMember`
//  de la source. La vue reste pleinement fonctionnelle pour la recherche, la
//  fiche publique et l'abonnement local (`toggleFollow`).
//
//  Écart assumé (2026-09-29) : le geste de proposition (`onProposeChallenge`)
//  reste inerte — la passerelle vers la préparation de défi n'est pas câblée
//  dans ce fichier (même limite que `AcctIntSearchRow`).
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Feuille « Annuaire » : recherche d'élèves et fiche publique.
@MainActor
struct AcctIntDirectorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    @StateObject private var model = AcctSearchModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                AcctSearchView(
                    model: model,
                    canProposeChallenge: canProposeChallenge,
                    onProposeChallenge: { _ in }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Theme.background)
            .navigationTitle("Annuaire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    /// `canProposeChallenge` (`AccountScreen.tsx:1781-1784`) : le membre ouvert
    /// partage le programme du compte (`!isMemberLocked` reste toujours vrai côté
    /// natif, cf. `AcctSearchModel.isMemberLocked`). Recalculé à chaque
    /// changement de membre ouvert, comme la source.
    private var canProposeChallenge: Bool {
        guard let member = model.selectedMember else { return false }
        return SocChallengeInvites.canProposeChallenge(
            to: member.profile,
            challengerTrack: session.profile.track,
            challengerSpecialty: ownSpecialty
        )
    }

    /// `ownSpecialty` (`AccountScreen.tsx:1773-1780`) :
    /// `accountAcademicOptionLabel(track, academicProgramSelection(...).specialty,
    /// specialty)`. L'option de l'année affichée vient de `academicPath`
    /// (`firstYearOption` en 1re année, `currentOption` sinon), avec repli sur la
    /// spécialité du profil pour les comptes anciens sans parcours détaillé.
    private var ownSpecialty: String {
        let profile = session.profile
        let option = profile.academicPath.map {
            profile.year == "1re année" ? $0.firstYearOption : $0.currentOption
        } ?? profile.specialty
        return LoginScrProviderReuse.accountAcademicOptionLabel(
            track: profile.track,
            currentOption: option,
            legacySpecialty: profile.specialty
        )
    }
}
