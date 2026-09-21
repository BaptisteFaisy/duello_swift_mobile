//
//  PremCodeRedemptionCard.swift
//  Duello
//
//  Carte de saisie d’un code d’affiliation Premium.
//
//  Fichier source Expo porté : `src/components/PremiumCodeRedemptionCard.tsx`,
//  avec son contrôleur `src/hooks/usePremiumCodeRedemption.ts` (porté dans
//  `PremCodeController`).
//
//  Le composant est présentationnel : il reçoit l’e-mail et le jeton du compte,
//  plus l’état d’inscription. Son câblage (écran « Premium », réglages)
//  appartient à l’application, hors de ce lot.
//
//  ⚠️ Le `member-…` saisi n’est jamais conservé ailleurs que dans l’état du
//  formulaire, et il est effacé dès qu’un code est accepté.
//
//  Cible : iOS 16.
//
import SwiftUI
import UIKit

/// Carte « Tu as un code d’affiliation ? » : en-tête, formulaire, état.
struct PremCodeRedemptionCard: View {
    @StateObject private var controller: PremCodeController

    init(email: String, token: String?, registered: Bool) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let accountId = trimmed.isEmpty ? "local" : DuelloAPI.publicProfileId(email: trimmed)
        _controller = StateObject(wrappedValue: PremCodeController(
            email: email, token: token, accountId: accountId, registered: registered))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            form
            status
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: Theme.premiumSurfaceHex))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Color(hex: Theme.premiumSurfaceBorderHex), lineWidth: 1)
        )
        .padding(.top, 18)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Utilisation d’un code d’affiliation")
        // `usePremiumCodeAnnouncement` : annonce du message par le lecteur
        // d’écran. Un seul paramètre à `.onChange` (forme iOS 16).
        .onChange(of: controller.feedback?.announcementId) { _ in
            guard let message = controller.feedback?.message else { return }
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    /// `PremiumCodeHeader` : icône clé, titre et explication.
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "key")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Theme.ink)
                .frame(width: 38, height: 38)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            VStack(alignment: .leading, spacing: 3) {
                Text("Tu as un code d’affiliation ?")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("Saisis le code member-… visible dans « Mes gains ». L’affilié recevra \(PremCodeCopy.paymentRewardLabel) uniquement après validation de ton paiement hebdomadaire ou annuel.")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// `PremiumCodeForm` : champ de saisie et bouton d’enregistrement.
    private var form: some View {
        VStack(spacing: 10) {
            TextField("member-a1b2c3d4", text: codeBinding)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textContentType(nil)
                .font(.system(size: 13, weight: .heavy))
                .kerning(0.35)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMedium)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .disabled(!controller.registered || controller.submitting)
                .opacity(controller.registered ? 1 : 0.58)
                .accessibilityLabel("Code d’affiliation")
                .accessibilityHint("Le code reste uniquement dans ce formulaire.")
                .onSubmit {
                    guard controller.canSubmit else { return }
                    Task { await controller.submit() }
                }
            submitButton
        }
    }

    /// Liaison du champ : la saisie passe par la normalisation du contrôleur.
    private var codeBinding: Binding<String> {
        Binding(
            get: { controller.code },
            set: { controller.setCode($0) })
    }

    /// Bouton d’enregistrement, avec sa roue d’attente pendant la requête.
    private var submitButton: some View {
        Button {
            Task { await controller.submit() }
        } label: {
            HStack(spacing: 8) {
                if controller.submitting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.white)
                }
                Text(controller.submitting ? "Validation…" : "Enregistrer le code")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.white)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .opacity(controller.canSubmit ? 1 : 0.42)
        }
        .buttonStyle(.plain)
        .disabled(!controller.canSubmit)
        .accessibilityLabel(controller.submitting
            ? "Enregistrement du code en cours"
            : "Enregistrer le code d’affiliation")
    }

    /// `PremiumCodeStatus` : compte requis, sinon message de succès ou d’échec.
    @ViewBuilder
    private var status: some View {
        if !controller.registered {
            Text("Connecte-toi à un compte Duello pour utiliser un code d’affiliation.")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        } else if let feedback = controller.feedback {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: feedback.kind == .success
                    ? "checkmark.circle"
                    : "exclamationmark.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(feedback.kind == .success ? Theme.premium : Theme.like)
                Text(feedback.message)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(feedback.kind == .success ? Theme.premium : Theme.like)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
