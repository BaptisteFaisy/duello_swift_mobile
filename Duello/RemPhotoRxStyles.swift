import SwiftUI

// Porté depuis l'application Expo (lot 7-I, photo à distance — côté récepteur) :
//   src/components/remote-photo-connection/remotePhotoConnectionStyles.ts
//   src/components/remotePhotoCapturePromptStyles.ts
// Jetons de style (mesures, couleurs, rayons) des surfaces de la connexion
// photo à distance et de l'invite de capture. Les `StyleSheet` de React Native
// n'existent pas en SwiftUI : chaque feuille devient un jeu de constantes
// appliquées en ligne par les vues. Les couleurs viennent de `Theme`, qui
// reprend déjà la palette de `src/theme.ts`.

/// `remotePhotoConnectionStyles` + `remotePhotoCapturePromptStyles`.
enum RemPhotoRxStyles {
    // MARK: - Conteneur et intro (`container`, `intro`, `introIcon`)

    static let containerPaddingTop: CGFloat = 20
    static let containerPaddingHorizontal: CGFloat = 4
    static let containerGap: CGFloat = 16
    static let introGap: CGFloat = 12
    static let introIconSize: CGFloat = 48
    static let introIconRadius: CGFloat = 16
    static let introIconBackground = Theme.primaryLight
    static let titleSize: CGFloat = 17
    static let titleLineHeight: CGFloat = 22
    static let descriptionSize: CGFloat = 12
    static let descriptionLineHeight: CGFloat = 18

    // MARK: - Carte de connexion (`connectionCard`, `centeredState`, `stateText`)

    static let connectionCardGap: CGFloat = 14
    static let connectionCardPadding: CGFloat = 18
    static let connectionCardRadius: CGFloat = Theme.radiusLarge
    static let centeredStateMinHeight: CGFloat = 180
    static let stateTextSize: CGFloat = 12

    // MARK: - État de connexion (`connectionStateRow`, `connectionDot`)

    static let connectionStateGap: CGFloat = 8
    static let connectionDotSize: CGFloat = 9
    static let connectionDotColor = Theme.inkFaint
    static let connectionDotConnectedColor = Theme.progress
    static let connectionStateTextSize: CGFloat = 11

    // MARK: - Boutons (`primaryButton`, `secondaryButton`, `secondaryWideButton`)

    static let actionRowGap: CGFloat = 10
    static let primaryButtonMinHeight: CGFloat = 50
    static let primaryButtonRadius: CGFloat = 15
    static let primaryButtonTextSize: CGFloat = 13
    static let secondaryButtonMinHeight: CGFloat = 40
    static let secondaryButtonRadius: CGFloat = 12
    static let secondaryWideButtonMinHeight: CGFloat = 48
    static let secondaryWideButtonRadius: CGFloat = 14
    static let secondaryButtonTextSize: CGFloat = 12
    static let textButtonMinHeight: CGFloat = 34
    static let textButtonTextSize: CGFloat = 11

    // MARK: - Panneau du téléphone (`phoneWaiting`, `phoneConnectedRow`)

    static let phoneWaitingMinHeight: CGFloat = 150
    static let phoneWaitingTextSize: CGFloat = 12
    static let phoneWaitingLineHeight: CGFloat = 18
    static let phoneConnectedGap: CGFloat = 11
    static let connectedIconSize: CGFloat = 42
    static let phoneConnectedTitleSize: CGFloat = 14
    static let phoneConnectedTextSize: CGFloat = 11
    static let phoneConnectedLineHeight: CGFloat = 16

    // MARK: - Bandeaux notice / erreur (`noticeBox`, `errorBox`)

    static let noticeBoxPadding: CGFloat = 12
    static let noticeBoxRadius: CGFloat = 12
    static let noticeBoxBackground = Theme.progressLight
    static let noticeTextSize: CGFloat = 11
    static let errorBoxPadding: CGFloat = 12
    static let errorBoxRadius: CGFloat = 12
    /// `colors.likeLight` (#FDECEC) — absent de `Theme`, défini ici.
    static let errorBoxBackground = Color(hex: 0xFDECEC)
    /// `colors.danger` = `colors.ink` : le texte d'erreur reste en encre.
    static let errorTextColor = Theme.ink
    static let errorTextSize: CGFloat = 11

    // MARK: - Photos reçues (`photosSection`, `photoCard`, `photoActions`)

    static let photosSectionGap: CGFloat = 7
    static let photosTitleSize: CGFloat = 15
    static let photosDescriptionSize: CGFloat = 11
    static let photosDescriptionLineHeight: CGFloat = 16
    static let photoGridGap: CGFloat = 12
    static let photoGridMarginTop: CGFloat = 4
    static let photoCardRadius: CGFloat = 16
    static let photoPreviewHeight: CGFloat = 190
    static let photoPreviewBackground = Theme.surfaceMuted
    static let photoDetailsPaddingHorizontal: CGFloat = 12
    static let photoDetailsPaddingTop: CGFloat = 10
    static let photoNameSize: CGFloat = 12
    static let photoSizeFontSize: CGFloat = 10
    static let photoActionsPadding: CGFloat = 12
    static let photoActionButtonMinHeight: CGFloat = 38
    static let photoActionButtonRadius: CGFloat = 11
    static let photoActionTextSize: CGFloat = 11
    static let photoDeleteButtonSize: CGFloat = 40

    // MARK: - Note de confidentialité (`securityNote`)

    static let securityNoteSize: CGFloat = 10
    static let securityNoteLineHeight: CGFloat = 15

    // MARK: - Invite de capture (`backdrop`, `card`, `actions`, `dismissButton`)

    /// `rgba(8, 16, 31, 0.54)`.
    static let promptBackdrop = Color(hex: 0x08101F, alpha: 0.54)
    static let promptBackdropPaddingHorizontal: CGFloat = 24
    static let promptCardMaxWidth: CGFloat = 420
    static let promptCardPadding: CGFloat = 22
    static let promptCardRadius: CGFloat = Theme.radiusLarge
    static let promptIconSize: CGFloat = 48
    static let promptIconRadius: CGFloat = 16
    static let promptIconBackground = Theme.primaryLight
    static let promptTitleSize: CGFloat = 20
    static let promptTitleMarginTop: CGFloat = 16
    static let promptBodySize: CGFloat = 14
    static let promptBodyMarginTop: CGFloat = 8
    static let promptErrorSize: CGFloat = 12
    static let promptErrorMarginTop: CGFloat = 12
    static let promptActionsGap: CGFloat = 10
    static let promptActionsMarginTop: CGFloat = 20
    static let promptButtonMinHeight: CGFloat = 48
    static let promptButtonRadius: CGFloat = Theme.radiusMedium
    static let promptDismissMinHeight: CGFloat = 38
    static let promptDismissMarginTop: CGFloat = 8
    static let promptDismissTextSize: CGFloat = 12
    static let promptDisabledOpacity: Double = 0.55
}
