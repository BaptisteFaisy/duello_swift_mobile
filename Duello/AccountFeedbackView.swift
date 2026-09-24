import SwiftUI

// MARK: - Retour utilisateur

/// Écran « Un bug ? » : retour d'un élève vers l'équipe Duello.
/// Reprend `FeedbackScreen.tsx` : aucun titre de navigation, chevron de retour
/// en tête de contenu, champs SUJET et MESSAGE, carte d'erreur d'envoi et bouton
/// « Envoyer mon message ». L'envoi reste local — aucune requête réseau n'est
/// émise par cette vue.
///
/// Mise en page reprise valeur par valeur de la source : le chevron a une zone
/// 40×40 (pictogramme décalé de −4), la zone de formulaire fait 82 % de la
/// largeur utile plafonnée à 420 et est centrée verticalement, le bouton
/// d'envoi reste plaqué en bas (`marginTop: 'auto'`).
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var subject = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var errorMessage = ""

    private var canSend: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    backButton
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 12)

                    // `formArea` (`flexGrow: 1`, `justifyContent: 'center'`) :
                    // le bloc formulaire occupe la hauteur libre et s'y centre.
                    Spacer(minLength: 0)
                    formArea(width: formWidth(in: proxy))
                    Spacer(minLength: 0)

                    // `submitButton` : `marginTop: 'auto'` → plaqué en bas.
                    sendButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .background(Theme.background)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.background)
    }

    /// Largeur de `formArea` : `width: '82%'`, `maxWidth: 420`, `alignSelf:
    /// 'center'`. La source mesure le pourcentage sur la boîte déjà déduite du
    /// `paddingHorizontal: 20` du contenu.
    private func formWidth(in proxy: GeometryProxy) -> CGFloat {
        min((proxy.size.width - 40) * 0.82, 420)
    }

    /// Chevron de retour : la source n'a ni titre de navigation ni « Fermer ».
    /// Repris du composant partagé `DuelloBackButton` (`BackButton.tsx`) :
    /// zone minimale 40×40, `gap` 4, pictogramme centré puis décalé de −4,
    /// `chevron-back` **20** (`iconSize={20}`), encre. La marge basse 12 et
    /// l'alignement `flex-start` (`styles.backButton`) restent posés par
    /// l'appelant, comme le `style` du RN.
    private var backButton: some View {
        DuelloBackButton(
            iconSize: 20,
            iconWeight: .bold,
            accessibilityLabel: "Retour aux paramètres"
        ) {
            dismiss()
        }
    }

    /// `formArea` : `formCard` puis la carte d'erreur (`marginTop: 12`).
    @ViewBuilder
    private func formArea(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            formCard
            if !errorMessage.isEmpty {
                errorCard.padding(.top, 12)
            }
        }
        .frame(width: width)
    }

    /// `formCard` : `gap: 16`. Le `divider` de la source est un `View` de
    /// hauteur 0, mais le `gap` s'applique de part et d'autre : l'écart réel
    /// entre SUJET et MESSAGE vaut donc 32 pt.
    private var formCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            field(title: "SUJET") {
                TextField("", text: $subject, prompt: subjectPrompt)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall)
                            .stroke(Theme.ink, lineWidth: 1.5)
                    )
            }
            Color.clear.frame(height: 0)
            field(title: "MESSAGE") {
                TextField("", text: $message, prompt: messagePrompt, axis: .vertical)
                    .lineLimit(6...)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                    .padding(.horizontal, 14)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall)
                            .stroke(Theme.ink, lineWidth: 1.5)
                    )
            }
        }
    }

    /// `placeholderTextColor` de la source (`colors.inkFaint`).
    private var subjectPrompt: Text {
        Text("Ex: Problème de synchronisation").foregroundColor(Theme.inkFaint)
    }

    private var messagePrompt: Text {
        Text("Décris ton retour en détail...").foregroundColor(Theme.inkFaint)
    }

    /// `errorCard` : `alignItems: 'flex-start'`, `gap: 9`, `padding: 13`,
    /// rayon 14, bord `colors.border` (1). L'icône `alert-circle-outline` est
    /// **blanche** (`colors.white`) dans la source.
    private var errorCard: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.white)
            Text(errorMessage)
                .font(.system(size: 11, weight: .bold))
                .lineSpacing(5)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// `submitButton` : `minHeight: 52`, `gap: 10`, rayon 14 (`radii.medium`),
    /// fond encre, libellé blanc 15 `'800'`. Repris du composant partagé
    /// `DuelloPrimaryButton(radius: 14, weight: .heavy)` — la peinture (fond
    /// encre, rayon, libellé blanc) est portée par le style, plus aucun doublon
    /// local. Aucun retour d'appui dans la source (`AppPressable` neutre) : le
    /// style partagé n'en pose pas non plus.
    private var sendButton: some View {
        Button(action: submit) {
            HStack(spacing: 10) {
                if isSending {
                    ProgressView().tint(Theme.white)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Envoyer mon message")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(DuelloPrimaryButton(radius: 14, weight: .heavy))
        .disabled(!canSend)
    }

    /// `field` : `paddingVertical: 4`, légende 12 `'700'`, `marginBottom: 10`.
    private func field<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.ink)
            content()
        }
        .padding(.vertical, 4)
    }

    /// Envoi local : confirmation puis remise à zéro de SUJET et MESSAGE au OK.
    private func submit() {
        guard canSend else { return }
        isSending = true
        errorMessage = ""
        Task { @MainActor in
            isSending = false
            // `Alert.alert('Message envoyé', …, [{ text: 'OK', onPress }])` :
            // fenêtre commune (jamais `.alert` natif), bouton « OK » primaire.
            AppAlert.alert(
                "Message envoyé",
                "Ton retour a bien été transmis à l’équipe Duello. Merci pour ta contribution !",
                [AppAlertButton("OK") { resetForm() }]
            )
        }
    }

    private func resetForm() {
        subject = ""
        message = ""
    }
}
