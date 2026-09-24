//
//  AppAlertView.swift
//  Duello
//
//  KIT partagé — fenêtre d'alerte commune, port fidèle de
//  `rn-ref/src/components/AppAlert.tsx` (= `BaptisteFaisy/duello` @ origin/main).
//
//  L'app Expo n'utilise **aucune** alerte native : tout passe par cette fenêtre
//  (`AppAlertProvider` monté une seule fois à la racine, `AppAlert.alert(...)`
//  impératif appelé depuis n'importe où — écrans, hooks, utilitaires). Le port
//  Swift rendait ces alertes avec `.alert` natif (rendu iOS standard) : écart
//  visuel net. Ce fichier fournit le composant **et** son API impérative.
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

// MARK: - Modèle (miroir des types d'`AppAlert.tsx`)

/// `AppAlertButton['style']` : apparence et rôle d'un bouton d'alerte.
enum AppAlertButtonStyle {
    /// Bouton primaire plein (fond encre, texte blanc).
    case `default`
    /// Bouton secondaire (fond gris clair, texte encre).
    case cancel
    /// Bouton destructif (fond rouge pâle, texte rouge).
    case destructive
}

/// `AppAlertButton` : un bouton de la fenêtre.
struct AppAlertButton {
    /// Libellé ; `nil` retombe sur « OK » au rendu, comme `button.text ?? 'OK'`.
    var text: String?
    var style: AppAlertButtonStyle
    var onPress: (() -> Void)?

    init(
        _ text: String? = nil,
        style: AppAlertButtonStyle = .default,
        onPress: (() -> Void)? = nil
    ) {
        self.text = text
        self.style = style
        self.onPress = onPress
    }
}

/// `AppAlertOptions` : réglages de fermeture de la fenêtre.
struct AppAlertOptions {
    /// Fond cliquable et bouton retour : la fenêtre se referme (avec
    /// `onDismiss`). Faux par défaut, comme Expo.
    var cancelable: Bool
    /// Appelé **uniquement** quand la fenêtre est fermée par le fond, la croix
    /// ou le bouton retour — jamais par un bouton d'action.
    var onDismiss: (() -> Void)?
    /// Affiche la croix en haut à droite et réserve sa place (`paddingTop: 66`).
    var showCloseButton: Bool

    init(
        cancelable: Bool = false,
        onDismiss: (() -> Void)? = nil,
        showCloseButton: Bool = false
    ) {
        self.cancelable = cancelable
        self.onDismiss = onDismiss
        self.showCloseButton = showCloseButton
    }
}

/// `AppAlertRequest` : une alerte en attente d'affichage.
struct AppAlertRequest: Identifiable {
    let id: Int
    let title: String
    let message: String?
    let buttons: [AppAlertButton]
    let options: AppAlertOptions
}

// MARK: - File d'attente (l'objet impératif `AppAlert`)

/// Une seule fenêtre montée à la racine suffit pour toutes les alertes de
/// l'app (`AppAlertProvider`). Les requêtes s'empilent et s'affichent l'une
/// après l'autre, dans l'ordre d'appel.
final class AppAlertCenter: ObservableObject {
    static let shared = AppAlertCenter()

    /// Alerte affichée ; `nil` quand il n'y en a aucune.
    @Published private(set) var request: AppAlertRequest?

    private var queue: [AppAlertRequest] = []
    private var nextId = 1

    private init() {}

    /// `AppAlert.alert(title, message?, buttons?, options?)` : met la requête en
    /// file. Sans bouton, la fenêtre porte le bouton unique « Compris ».
    func alert(
        _ title: String,
        _ message: String? = nil,
        _ buttons: [AppAlertButton]? = nil,
        options: AppAlertOptions = AppAlertOptions()
    ) {
        let resolved = (buttons?.isEmpty == false) ? buttons! : [AppAlertButton("Compris")]
        let request = AppAlertRequest(
            id: nextId,
            title: title,
            message: message,
            buttons: resolved,
            options: options
        )
        nextId += 1
        enqueue(request)
    }

    /// Ferme par un bouton d'action : `onPress` est appelé, `onDismiss` **non**
    /// (`closeAlert(request, button.onPress)`).
    func resolve(_ request: AppAlertRequest, onPress: (() -> Void)?) {
        close(request, onPress: onPress, dismissed: false)
    }

    /// Ferme par le fond, la croix ou le bouton retour : seulement si la
    /// fenêtre est `cancelable`, et `onDismiss` est alors appelé.
    func dismiss(_ request: AppAlertRequest) {
        guard request.options.cancelable else { return }
        close(request, onPress: nil, dismissed: true)
    }

    // MARK: Interne

    private func enqueue(_ request: AppAlertRequest) {
        if Thread.isMainThread {
            enqueueOnMain(request)
        } else {
            DispatchQueue.main.async { [weak self] in self?.enqueueOnMain(request) }
        }
    }

    private func enqueueOnMain(_ request: AppAlertRequest) {
        queue.append(request)
        showNext()
    }

    private func close(_ request: AppAlertRequest, onPress: (() -> Void)?, dismissed: Bool) {
        guard self.request?.id == request.id else { return }
        self.request = nil
        onPress?()
        if dismissed { request.options.onDismiss?() }
        showNext()
    }

    private func showNext() {
        guard request == nil, !queue.isEmpty else { return }
        request = queue.removeFirst()
    }
}

/// `AppAlert` d'Expo : point d'entrée impératif, appelable depuis un écran,
/// un hook ou un utilitaire, sans état de modale local.
enum AppAlert {
    static func alert(
        _ title: String,
        _ message: String? = nil,
        _ buttons: [AppAlertButton]? = nil,
        options: AppAlertOptions = AppAlertOptions()
    ) {
        AppAlertCenter.shared.alert(title, message, buttons, options: options)
    }
}

// MARK: - Fenêtre

/// Carte d'alerte centrée sur fond assombri (`AppAlertProvider`).
///
/// Le fond couvre tout l'écran ; la carte reste dans la zone sûre, écartée de
/// 24 pt (`insets.top + 24` / `insets.bottom + 24` / `paddingHorizontal: 24`).
struct AppAlertView: View {
    let request: AppAlertRequest
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            backdrop.ignoresSafeArea()
            dialog
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
        }
    }

    // MARK: Fond

    /// `backdrop` : voile `rgba(10,13,12,0.44)` pleine page. Cliquable
    /// uniquement quand la fenêtre est `cancelable` (sinon il bloque seulement
    /// les touches du contenu sous-jacent).
    @ViewBuilder private var backdrop: some View {
        if request.options.cancelable {
            veil
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Fermer la fenêtre")
        } else {
            veil
        }
    }

    /// Voile `rgba(10,13,12,0.44)` : `#0A0D0C` à 44 %.
    private var veil: some View {
        Color(hex: 0x0A0D0C).opacity(0.44)
    }

    // MARK: Carte

    /// `dialog` : blanc, rayon 24, bord `#E1E4E2`, padding 22, écart 24, ombre
    /// de carte ; largeur 100 % plafonnée à 410 pt et centrée.
    private var dialog: some View {
        VStack(alignment: .leading, spacing: 24) {
            copy
            actions.frame(maxWidth: .infinity)
        }
        // `dialogWithCloseButton` : le haut passe de 22 à 66 pour laisser la
        // croix absolue (top 16, 36 pt).
        .padding(.top, request.options.showCloseButton ? 66 : 22)
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24).stroke(Theme.border, lineWidth: 1)
        )
        .duelloShadow()
        .overlay(alignment: .topTrailing) { closeButton }
        .frame(maxWidth: 410)
        .accessibilityAddTraits(.isModal)
    }

    /// `copy` : titre et message, affichés seulement si l'un des deux existe.
    @ViewBuilder private var copy: some View {
        if showsCopy {
            VStack(alignment: .leading, spacing: 9) {
                if !request.title.isEmpty {
                    Text(request.title)
                        .font(.system(size: 21, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        // `lineHeight: 27` − 21.
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                }
                if let message = request.message, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Theme.inkSoft)
                        // `lineHeight: 22` − 15.
                        .lineSpacing(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var showsCopy: Bool {
        !request.title.isEmpty || !(request.message ?? "").isEmpty
    }

    /// `closeButton` : croix absolue en haut à droite (36 × 36, rayon 11, fond
    /// `surfaceMuted`). Glyphe Ionicons `close` 21 → SF `xmark` (divergence
    /// connue des tracés, cf. rapport).
    @ViewBuilder private var closeButton: some View {
        if request.options.showCloseButton {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 21))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Theme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityLabel("Fermer")
        }
    }

    // MARK: Actions

    /// `actions` : en ligne (écart 10) pour un ou deux boutons, empilés en
    /// colonne au-delà de deux.
    @ViewBuilder private var actions: some View {
        if request.buttons.count > 2 {
            VStack(spacing: 10) {
                ForEach(Array(request.buttons.enumerated()), id: \.offset) { _, button in
                    actionButton(button)
                }
            }
        } else {
            HStack(spacing: 10) {
                ForEach(Array(request.buttons.enumerated()), id: \.offset) { _, button in
                    actionButton(button)
                }
            }
        }
    }

    private func actionButton(_ button: AppAlertButton) -> some View {
        AppAlertActionButton(button: button) {
            AppAlertCenter.shared.resolve(request, onPress: button.onPress)
        }
    }
}

// MARK: - Bouton d'action

/// Bouton de la fenêtre : `minHeight 48`, padding 12/18, rayon 14, fond et
/// texte selon le style, opacité 0.72 à l'appui.
struct AppAlertActionButton: View {
    let button: AppAlertButton
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(button.text ?? "OK")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(foreground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(AppAlertPressStyle())
    }

    private var background: Color {
        switch button.style {
        case .default: return Theme.primary
        case .cancel: return Theme.surfaceMuted
        case .destructive: return Theme.likeLight
        }
    }

    private var foreground: Color {
        switch button.style {
        case .default: return Theme.white
        case .cancel: return Theme.ink
        case .destructive: return Theme.like
        }
    }
}

/// `buttonPressed` : opacité 0.72 pendant l'appui.
struct AppAlertPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.72 : 1)
    }
}

// MARK: - Racine

/// Monte la fenêtre unique par-dessus l'app (équivalent d'`AppAlertProvider`
/// dans `App.tsx`). À poser une seule fois, à la racine (`RootView`).
struct AppAlertHost: ViewModifier {
    @ObservedObject private var center = AppAlertCenter.shared

    func body(content: Content) -> some View {
        content
            .overlay {
                if let request = center.request {
                    AppAlertView(request: request) { center.dismiss(request) }
                        // `animationType="fade"`.
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: center.request?.id)
    }
}

extension View {
    /// Pose la fenêtre d'alerte commune (`AppAlertProvider`).
    func appAlertHost() -> some View {
        modifier(AppAlertHost())
    }
}
