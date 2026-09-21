import SwiftUI

// MARK: - Écran « Premium »

/// Écran « Premium » : les offres, le code promo et les garanties.
///
/// Portage de la section Premium des réglages (`src/screens/AccountScreen.tsx`,
/// qui rend `<PremiumOffers />`) et de la fenêtre de paiement
/// (`PaywallContent.tsx`, `PaywallModal.tsx`) : les deux surfaces partagent la
/// même présentation, portée ici par `PremPaywallSheet`.
///
/// La fenêtre contextuelle des outils Premium vit à part : elle s'ouvre depuis
/// n'importe quel écran via `openPremPremiumToolPaywall(_:)`, et son hôte
/// (`.premToolPaywallHost()`) se pose une seule fois à la racine de l'app —
/// câblage qui appartient à `DuelloApp.swift`, hors de ce lot.
///
/// `AccountView` présente cet écran en feuille : la barre de navigation porte
/// donc une fermeture explicite, là où la source revient par la barre du compte.
struct PremiumView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    /// Quota durable du compte, relu au montage : `nil` tant que le serveur n'a
    /// pas répondu, ou quand sa réponse n'est pas exploitable.
    @State private var quota: PremQuotaSnapshot?

    var body: some View {
        NavigationStack {
            ScrollView {
                PremPaywallSheet(quota: quota, token: session.token)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .task { await loadQuota() }
    }

    /// `fetchRemoteCorrectionQuota` : relit le quota sans retenir de correction.
    /// Un échec laisse la ligne d'état masquée — jamais de quota inventé.
    @MainActor
    private func loadQuota() async {
        let email = session.profile.email
        guard !email.isEmpty else { return }
        quota = try? await PremQuotaService.load(
            token: session.token,
            userId: DuelloAPI.publicProfileId(email: email)
        )
    }
}
