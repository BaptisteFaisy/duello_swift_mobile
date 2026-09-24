import SwiftUI

// MARK: - Bulle de message

/// Une bulle de message : initiale à droite pour moi, à gauche pour l'autre.
struct MessageBubbleRow: View {
    let message: ChatMessage
    let myInitial: String
    /// Largeur maximale de la bulle, en points : `maxWidth: '77%'` d'Expo, calculé
    /// par l'appelant (77 % de la largeur de ligne, hors marges horizontales).
    let maxBubbleWidth: CGFloat

    private var isMine: Bool { message.author == .me }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if !isMine {
                // L'initiale affichée est « L » en dur dans `MessageBubble` d'Expo.
                avatar("L", background: Theme.surfaceMuted, foreground: Theme.inkSoft)
                    .padding(.trailing, 7)
            } else {
                Spacer(minLength: 0)
            }

            bubble

            if isMine {
                avatar(myInitial, background: Theme.primaryLight, foreground: Theme.ink)
                    .padding(.leading, 7)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }

    private var bubble: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 5) {
            Text(message.text)
                .font(.system(size: 11, weight: .medium))
                .lineSpacing(5)
                .foregroundStyle(isMine ? Theme.surface : Theme.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(message.time)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(isMine ? Theme.primaryLight : Theme.inkFaint)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 13)
        .frame(maxWidth: maxBubbleWidth)
        .background(isMine ? Theme.ink : Theme.surface)
        .clipShape(bubbleShape)
    }

    /// Trois coins à 17, un à 5 du côté de l'émetteur.
    ///
    /// La source Expo utilise `borderBottomLeftRadius`/`borderBottomRightRadius`
    /// inégaux, que SwiftUI ne sait exprimer avant iOS 17 qu'avec une forme
    /// dessinée à la main : voir `MsgBubbleShape`.
    private var bubbleShape: MsgBubbleShape {
        MsgBubbleShape(radius: 17, tightRadius: 5, isMine: isMine)
    }

    private func avatar(_ initial: String, background: Color, foreground: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11)
                .fill(background)
                .frame(width: 29, height: 29)
            Text(initial)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(foreground)
        }
    }
}
