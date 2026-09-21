import SwiftUI

// MARK: - Bulle de message

/// Une bulle de message : initiale à droite pour moi, à gauche pour l'autre.
struct MessageBubbleRow: View {
    let message: ChatMessage
    let myInitial: String
    let peerInitial: String

    private var isMine: Bool { message.author == .me }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if !isMine {
                avatar(peerInitial, background: Theme.surfaceMuted, foreground: Theme.inkSoft)
                    .padding(.trailing, 7)
            } else {
                Spacer(minLength: 48)
            }

            bubble

            if isMine {
                avatar(myInitial, background: Theme.primaryLight, foreground: Theme.ink)
                    .padding(.leading, 7)
            } else {
                Spacer(minLength: 48)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }

    private var bubble: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 5) {
            Text(message.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isMine ? Theme.surface : Theme.ink)
                .multilineTextAlignment(isMine ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(message.time)
                .font(.system(size: 7, weight: .medium))
                .foregroundStyle(isMine ? Theme.primaryLight : Theme.inkFaint)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 13)
        .background(isMine ? Theme.ink : Theme.surface)
        .clipShape(bubbleShape)
        .overlay(bubbleBorder)
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 17,
            bottomLeadingRadius: isMine ? 17 : 5,
            bottomTrailingRadius: isMine ? 5 : 17,
            topTrailingRadius: 17
        )
    }

    @ViewBuilder
    private var bubbleBorder: some View {
        if !isMine {
            bubbleShape.stroke(Theme.border, lineWidth: 1)
        }
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
