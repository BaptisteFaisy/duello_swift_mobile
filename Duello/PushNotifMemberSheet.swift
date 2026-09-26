//
//  PushNotifMemberSheet.swift
//  Duello
//
//  Fiche de membre ouverte par un tap sur une bannière (`new-follower`).
//
//  Fichier source Expo porté : `openMemberProfile(actorId)`, appelé par
//  `PushNotificationTapHandler` sur un tap `new-follower`. La fiche est lue
//  dans l’annuaire (`profilesByIds`), puis rendue par la vitrine existante.
//
//  V1 (26/09/2026, écart 20#1) : destination du routage du tap à la racine,
//  présentée en feuille par `DuelloApp` quand `pendingMember` est posé.
//
//  Cible : iOS 16.
//
import SwiftUI

/// Fiche du membre qui vient de s’abonner, ouverte depuis un tap.
struct PushNotifMemberSheet: View {
    /// `actorId` (`member-…`).
    let memberId: String

    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var member: AcctSearchMember?
    @State private var failed = false
    @State private var followed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let member {
                        AcctSearchMemberShowcase(
                            member: member,
                            followed: followed,
                            followsMe: false,
                            canProposeChallenge: false,
                            premiumMessageVisible: false,
                            onToggleFollow: { followed.toggle() },
                            onProposeChallenge: {},
                            onTogglePremiumMessage: {},
                            onBlock: {},
                            onReport: {}
                        )
                    } else if failed {
                        Text("Ce profil est introuvable pour le moment.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 36)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 36)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    /// Lit la fiche dans l’annuaire (`profilesByIds`).
    private func load() async {
        followed = false
        failed = false
        do {
            let members = try await AcctSearchDirectory.profilesByIds(
                [memberId], token: session.token)
            if let first = members.first {
                member = first
            } else {
                failed = true
            }
        } catch {
            failed = true
        }
    }
}
