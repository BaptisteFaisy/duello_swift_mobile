//
//  PlanSessionDetail.swift
//  Duello
//
//  Écran « Plan » — détail d'une séance : fondu sur fond assombri, carte ancrée
//  en bas, pastilles d'information.
//
import Foundation
import SwiftUI

// MARK: - Détail d'une séance

/// `SessionDetailModal` (lignes 294-358) : `animationType="fade"` sur un fond
/// `rgba(15,23,42,0.45)`, carte `justifyContent: 'flex-end'`. Le fondu est porté
/// par la transition d'opacité posée dans `PlanScreen` ; toucher le fond ferme,
/// toucher la carte ne fait rien.
///
/// Les décalages de la source (`paddingTop: insets.top + 16`,
/// `paddingBottom: Math.max(insets.bottom, 16) + 12`, `:309`) sont lus dans les
/// insets de la vue.
///
/// Écart assumé (29/09/2026, écart 11#3) : l'overlay est encore posé sur le
/// `ScrollView` de `PlanView`, pas à la racine (`MainTabView`) : le fond
/// s'arrête au-dessus de la barre d'onglets, là où la `Modal` transparente
/// d'Expo couvre tout l'écran. Le montage racine est décrit en « À raccorder »
/// (rapport IMPL-05) ; les insets lus ici sont ceux du conteneur, nuls tant que
/// l'overlay n'est pas monté à la racine.
struct PlanSessionDetailOverlay: View {
    let session: PlanSession
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color(hex: 0x0F172A, alpha: 0.45)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)

                PlanSessionDetailCard(session: session, onClose: onClose)
                    .padding(.horizontal, 16)
                    .padding(.top, proxy.safeAreaInsets.top + 16)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 16) + 12)
            }
        }
    }
}

/// Carte du détail (`modalCard`, lignes 313-354).
struct PlanSessionDetailCard: View {
    let session: PlanSession
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(session.color)
                        .frame(width: 44, height: 44)
                    IonIcon(name: session.icon, size: 22, color: Theme.ink)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.ink)
                    Text("\(session.startTime) – \(session.endTime) · \(PlanDateEngine.formatDuration(session.durationMinutes))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 8)
                Button {
                    onClose()
                } label: {
                    IonIcon(name: "close", size: 20, color: Theme.inkSoft)
                        .frame(width: 34, height: 34)
                        .background(Theme.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fermer")
            }
            .padding(.bottom, 18)

            Text("À faire pendant la séance")
                .font(.system(size: 9, weight: .black))
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(Theme.inkFaint)

            Text(session.subtitle)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 6)

            PlanFlowLayout(spacing: 8, lineSpacing: 8) {
                if let priority = session.priority {
                    PlanMetaChip(icon: "flag-outline", text: "Priorité \(priority.label)")
                }
                if let deadline = session.deadline, !deadline.isEmpty {
                    PlanMetaChip(icon: "alarm-outline", text: "Pour \(deadline)")
                }
                PlanMetaChip(
                    icon: "hourglass-outline",
                    text: "\(PlanDateEngine.formatDuration(session.durationMinutes)) de travail"
                )
            }
            .padding(.top, 16)
        }
        .padding(20)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .shadow(color: Theme.ink.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

/// Pastille d'information du détail (`modalMetaChip`, lignes 334-351) : icône
/// `flag-outline`/`alarm-outline`/`hourglass-outline` 13, texte 10.
struct PlanMetaChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            IonIcon(name: icon, size: 13, color: Theme.inkSoft)
            Text(text)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(Theme.inkSoft)
        .padding(.vertical, 7)
        .padding(.horizontal, 11)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Disposition en lignes successives, comme le `flexWrap` des pastilles de la
/// source (`Layout` est disponible depuis iOS 16, cible de ce portage).
struct PlanFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        let width = maxWidth.isFinite ? maxWidth : max(0, x - spacing)
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
