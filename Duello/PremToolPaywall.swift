import SwiftUI

// MARK: - Outils Premium

/// Outils réservés à l'abonnement (`PremiumTool` de
/// `src/utils/premiumToolAccess.ts`). Les valeurs brutes sont celles de la
/// source, pour que le vocabulaire reste le même de part et d'autre.
enum PremPremiumTool: String, CaseIterable, Identifiable {
    case voiceTranscription = "voice-transcription"
    case photoTranscription = "photo-transcription"
    case whiteboard
    case aiCorrection = "ai-correction"

    var id: String { rawValue }

    /// `PREMIUM_TOOL_LABELS`.
    var label: String {
        switch self {
        case .voiceTranscription: return "La transcription à l’oral"
        case .photoTranscription: return "La transcription par photo"
        case .whiteboard: return "Le tableau blanc"
        case .aiCorrection: return "La correction IA"
        }
    }

    /// `premiumToolNotice` : la ligne affichée dans la fenêtre de paiement
    /// ouverte depuis un outil Premium.
    var notice: String {
        "\(label) fait partie de l’abonnement Premium."
    }
}

/// Centre de la fenêtre contextuelle (`openPremiumToolPaywall`).
///
/// La source monte un hôte unique à la racine (`PremiumToolPaywallHost`) et
/// l'ouvre par un appel statique ; le portage garde le même dessin : un
/// singleton et un modificateur à poser une seule fois, à la racine de l'app.
final class PremToolPaywallCenter: ObservableObject {
    static let shared = PremToolPaywallCenter()

    /// Outil demandé, `nil` quand aucune fenêtre n'est ouverte.
    @Published var tool: PremPremiumTool?

    /// Couture d'achat de la fenêtre (`PremCodePurchases`) : un seul point
    /// interroge la disponibilité de la facturation native, jamais une seconde
    /// couture. V1 (écart 19#1) : la couture simulée a laissé la place à la
    /// couture StoreKit (`PremStoreKitPurchases`), qui reste actionnable et
    /// refuse clairement tant qu'aucun produit n'est configuré.
    let purchases: PremCodePurchases = PremStoreKitPurchases()

    /// `isPurchaseAvailable()` : la facturation native est-elle opérationnelle ?
    /// Voir `PremPurchaseService.isAvailable`.
    var isPurchaseAvailable: Bool { purchases.isAvailable }

    private init() {}

    /// `openPremiumToolPaywall(tool:)`.
    func open(_ tool: PremPremiumTool) {
        self.tool = tool
    }

    /// Fermeture silencieuse : la fenêtre n'accorde jamais l'accès elle-même.
    func close() {
        tool = nil
    }
}

/// Ouvre la fenêtre de paiement Premium au moment exact où un compte gratuit
/// touche un outil Premium, comme `AppAlert.alert` pour les alertes.
func openPremPremiumToolPaywall(_ tool: PremPremiumTool) {
    PremToolPaywallCenter.shared.open(tool)
}

/// Hôte de la fenêtre contextuelle : une seule fenêtre suffit pour tous les
/// outils Premium. À poser une seule fois, à la racine de l'app.
struct PremToolPaywallHost: ViewModifier {
    /// Centre partagé, observé pour que la fenêtre suive la demande.
    @ObservedObject var center: PremToolPaywallCenter = PremToolPaywallCenter.shared
    /// Jeton de session, transmis à la carte « code promo » de la fenêtre.
    var token: String?

    func body(content: Content) -> some View {
        content
            .overlay {
                if let tool = center.tool {
                    PremToolPaywallDialog(notice: tool.notice, token: token) {
                        center.close()
                    }
                    // La fenêtre reçoit la disponibilité d'achat de l'hôte
                    // (couture `PremCodePurchases`), pour qu'elle ne la
                    // recalcule pas : `PremOffersSection` lit cette valeur
                    // (`\.premPurchaseAvailable`).
                    .environment(\.premPurchaseAvailable, center.isPurchaseAvailable)
                    .transition(.opacity)
                }
            }
            // `PaywallModal.tsx:58` : `animationType="fade"` — la fenêtre
            // apparaît et disparaît en fondu, jamais par glissement.
            .animation(.easeInOut(duration: 0.25), value: center.tool)
    }
}

/// Enveloppe de `PaywallModal.tsx` : fond assombri tapable, dialogue centré.
///
/// `Modal transparent animationType="fade"` : le fond `rgba(10, 13, 12, 0.48)`
/// couvre l'écran et ferme au toucher ; le dialogue (480 points au plus, coins
/// 24, ombre de carte) est centré, sous les barres système.
private struct PremToolPaywallDialog: View {
    /// Explication affichée lorsque l'ouverture vient d'un outil Premium.
    var notice: String?
    /// Jeton de session, transmis à la carte « code promo » de la fenêtre.
    var token: String?
    /// Fermeture demandée par le fond ou par la croix.
    var onClose: () -> Void

    /// `DIALOG_MARGIN` de la source : l'air laissé entre le dialogue et les
    /// bords de l'écran.
    private let dialogMargin: CGFloat = 28

    var body: some View {
        ZStack {
            // `styles.backdrop` : `rgba(10, 13, 12, 0.48)`.
            Color(hex: 0x0A0D0C).opacity(0.48)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
                .accessibilityLabel("Fermer")
                .accessibilityAddTraits(.isButton)

            ScrollView {
                PremPaywallSheet(notice: notice, token: token, onClose: onClose)
            }
            .padding(20)
            .frame(maxWidth: 480, maxHeight: .infinity)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            // `cardShadow` : encre 0.04, rayon 8, décalage y 2.
            .shadow(color: Theme.ink.opacity(0.04), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 18)
            .padding(.vertical, dialogMargin)
        }
    }
}

/// Disponibilité de la facturation native, publiée par l'hôte du paywall
/// (`PremToolPaywallHost`) au contenu qu'il présente : un seul point interroge
/// la couture `PremCodePurchases`. La valeur par défaut est celle de cette
/// couture (`PremStoreKitPurchases`), actionnable et refusant clairement tant
/// qu'aucun produit n'est configuré.
struct PremPurchaseAvailableKey: EnvironmentKey {
    static let defaultValue = PremStoreKitPurchases().isAvailable
}

extension EnvironmentValues {
    /// Vrai si la facturation native est opérationnelle (`isPurchaseAvailable()`).
    var premPurchaseAvailable: Bool {
        get { self[PremPurchaseAvailableKey.self] }
        set { self[PremPurchaseAvailableKey.self] = newValue }
    }
}

extension View {
    /// Monte la fenêtre de paiement contextuelle des outils Premium, une seule
    /// fois pour toute l'app (comme `PremiumToolPaywallHost` à la racine).
    /// `token` alimente la carte « code promo » de la fenêtre.
    func premToolPaywallHost(token: String? = nil) -> some View {
        modifier(PremToolPaywallHost(token: token))
    }
}
