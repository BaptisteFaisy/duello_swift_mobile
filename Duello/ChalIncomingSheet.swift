//
//  ChalIncomingSheet.swift
//  Duello
//
//  Lot « Extras de défi » — popup d'invitation de défi reçue.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/IncomingChallengeModal.tsx
//      (`IncomingChallengeModal`, `chapterSummary`, `DIALOG_MARGIN`)
//
//  Popup global : il reste visible quel que soit l'onglet actuellement ouvert.
//  La vue se dessine sous les barres système et réserve donc leur hauteur : sans
//  cela, « Refuser » et « Accepter » passaient sous les trois touches du
//  téléphone dès que les chapitres du défi tenaient sur trois lignes.
//
//  L'enveloppe (fond assombri, présentation) est incluse ici : la vue s'affiche
//  en superposition plein écran par l'appelant (`.overlay`/`.fullScreenCover`).
//  La présence vient de `SocPresenceStore`, à monter à la racine de l'app.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Textes de l'invitation reçue (`chapterSummary`).
enum ChalCopy {
    /// Résumé des chapitres du défi, mot pour mot de la source.
    static func chapterSummary(_ names: [String]) -> String {
        if names.isEmpty { return "Toute la matière" }
        if names.count <= 2 { return names.joined(separator: " · ") }
        return names.prefix(2).joined(separator: " · ") + " · +\(names.count - 2)"
    }
}

/// Popup d'invitation de défi (`IncomingChallengeModal`).
struct ChalIncomingSheet: View {
    var invitation: ChalIncomingInvitation?
    var responding: Bool
    var error: String?
    var onAccept: () -> Void
    var onDecline: () -> Void
    /// Source de vérité de la présence ; à défaut, l'instance partagée (personne
    /// n'est alors signalé en ligne, comme le repli d'Expo).
    @ObservedObject var presence: SocPresenceStore = SocPresenceStore.shared

    /// Air laissé entre la carte et les bords de l'écran (`DIALOG_MARGIN`).
    private static let dialogMargin: CGFloat = 24

    var body: some View {
        ZStack {
            Color.black.opacity(0.52).ignoresSafeArea()
            if let invitation {
                card(invitation)
                    .padding(.horizontal, Self.dialogMargin)
                    .padding(.vertical, Self.dialogMargin)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Carte

    private func card(_ invitation: ChalIncomingInvitation) -> some View {
        VStack(spacing: 0) {
            iconBadge
            Text("NOUVEAU DÉFI")
                .font(.system(size: 9, weight: .black))
                .tracking(1.2)
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 14)
            titleRow(invitation)
            identityLine(invitation)
            challengeCard(invitation)
            if let error {
                Text(error)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: 0xB42318))
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
            actions
        }
        .padding(24)
        .frame(maxWidth: 430)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var iconBadge: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(width: 52, height: 52)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityHidden(true)
    }

    private func titleRow(_ invitation: ChalIncomingInvitation) -> some View {
        HStack(spacing: 6) {
            Text("\(invitation.challenger.displayName) te défie")
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            SocOnlineDot(online: presence.isOnline(invitation.challenger.id))
        }
        .padding(.top, 6)
    }

    /// Programme, année et prépa de l'émetteur, segments vides omis.
    private func identityLine(_ invitation: ChalIncomingInvitation) -> some View {
        let parts = [invitation.challenger.track, invitation.challenger.year, invitation.challenger.prepName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Text(parts.joined(separator: " · "))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)
            .padding(.top, 5)
    }

    private func challengeCard(_ invitation: ChalIncomingInvitation) -> some View {
        VStack(spacing: 0) {
            detailRow(icon: "book", label: "MATIÈRE", value: invitation.challenge.subject)
            divider
            detailRow(
                icon: "square.stack",
                label: "CHAPITRES",
                value: ChalCopy.chapterSummary(invitation.challenge.names)
            )
            divider
            detailRow(
                icon: "timer",
                label: "FORMAT",
                value: "\(invitation.challenge.minutes) min · même sujet, même chrono"
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.top, 20)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 8, weight: .black))
                    .tracking(0.7)
                    .foregroundStyle(Theme.inkFaint)
                Text(value)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
            .padding(.vertical, 13)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: onDecline) {
                Text("Refuser")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(ChalIncomingPressStyle())
            .disabled(responding)
            Button(action: onAccept) {
                Group {
                    if responding {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                            Text("Accepter")
                                .font(.system(size: 12, weight: .black))
                        }
                        .foregroundStyle(Color.white)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
            }
            .buttonStyle(ChalIncomingPressStyle())
            .disabled(responding)
        }
        .padding(.top, 20)
    }
}

/// Effet d'appui des boutons Refuser / Accepter (`pressed` de la source) :
/// opacité 0,72 et échelle 0,98 tant que le doigt reste posé.
private struct ChalIncomingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
