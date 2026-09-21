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
        content.sheet(item: $center.tool) { tool in
            ScrollView {
                PremPaywallSheet(notice: tool.notice, token: token) {
                    center.close()
                }
                .padding(20)
            }
            .background(Theme.surface)
        }
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
