//
//  ReportUserSheet.swift
//  Duello
//
//  Lot « Report » — fenêtre de signalement d'un membre : choix de la raison,
//  complément facultatif et envoi confidentiel.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/UserReportModal.tsx (REPORT_REASONS, UserReportModal)
//    - src/utils/socialApi.ts             (submitUserReport, UserReportReason)
//
//  Contenu seul du volet : l'enveloppe (fond assombri, présentation en feuille,
//  glisser-pour-fermer) reste à la charge de l'appelant, comme
//  `SocialChallengeInviteModal`. L'envoi (`submitUserReport`,
//  `POST /user-safety/reports`) est délégué à `onSubmit`, appelé par l'appelant.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Glyphe Ionicons exact de chaque raison (`REPORT_REASONS` de
/// `UserReportModal.tsx`). `ReportReason.icon` porte un substitut SF Symbol
/// (fichier partagé) : on ne l'emploie donc pas ici.
private extension ReportReason {
    var ioniconName: String {
        switch self {
        case .harassment: return "warning-outline"
        case .spam: return "megaphone-outline"
        case .impersonation: return "people-outline"
        case .inappropriateContent: return "eye-off-outline"
        case .other: return "ellipsis-horizontal"
        }
    }
}

/// Fenêtre de signalement d'un membre (`UserReportModal.tsx`).
struct ReportUserSheet: View {
    /// Nom du membre signalé, inséré dans le titre (« Signaler <nom> »).
    let memberName: String
    /// Dépose le signalement (`submitUserReport`). Une erreur remonte le
    /// message d'Expo tel quel.
    let onSubmit: (ReportReason, String) async throws -> Void
    let onClose: () -> Void

    @State private var reason: ReportReason? = nil
    @State private var details = ""
    @State private var submitting = false
    @State private var errorMessage = ""

    /// Longueur maximale du complément (`maxLength={500}`).
    private static let detailsLimit = 500

    /// Initialiseur explicite : un `@State` privé rend l'initialiseur membre
    /// synthétisé inaccessible à l'appelant.
    init(
        memberName: String,
        onSubmit: @escaping (ReportReason, String) async throws -> Void,
        onClose: @escaping () -> Void
    ) {
        self.memberName = memberName
        self.onSubmit = onSubmit
        self.onClose = onClose
    }

    /// Vrai quand une raison est choisie et, pour « Autre », un texte saisi.
    private var canSubmit: Bool {
        guard let reason else { return false }
        return reason != .other || !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            descriptionText
            reasonList
            detailsField
            counter
            if !errorMessage.isEmpty { errorText }
            submitButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .background(Theme.surface)
        .onAppear(perform: reset)
    }

    // MARK: En-tête

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("SÉCURITÉ")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(Theme.like)
                Text("Signaler \(memberName)")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onClose) {
                IonIcon(name: "close", size: 21, color: Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Theme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(submitting)
            .accessibilityLabel("Fermer")
        }
    }

    private var descriptionText: some View {
        Text("Choisis la raison principale. Le signalement reste confidentiel et la personne concernée n’est pas avertie.")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)
    }

    // MARK: Raisons

    private var reasonList: some View {
        VStack(spacing: 7) {
            ForEach(ReportReason.allCases) { option in
                reasonRow(option)
            }
        }
        .padding(.top, 15)
    }

    private func reasonRow(_ option: ReportReason) -> some View {
        let selected = reason == option
        return Button {
            reason = option
            errorMessage = ""
        } label: {
            HStack(spacing: 10) {
                IonIcon(name: option.ioniconName, size: 19, color: Theme.ink)
                Text(option.label)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                IonIcon(
                    name: selected ? "radio-button-on" : "radio-button-off",
                    size: 19,
                    color: selected ? Theme.ink : Theme.inkFaint
                )
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 44)
            .background(selected ? Theme.primaryLight : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(selected ? Theme.ink : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: Complément

    private var detailsField: some View {
        TextEditor(text: $details)
            .font(.system(size: 13))
            .foregroundStyle(Theme.ink)
            .frame(minHeight: 82)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                if details.isEmpty {
                    Text(reason == .other
                         ? "Explique brièvement ce qui s’est passé…"
                         : "Précisions facultatives…")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkFaint)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 15)
                        .allowsHitTesting(false)
                }
            }
            .padding(.top, 13)
            .onChange(of: details) { value in
                if value.count > Self.detailsLimit {
                    details = String(value.prefix(Self.detailsLimit))
                }
                errorMessage = ""
            }
    }

    private var counter: some View {
        Text("\(details.count)/500")
            .font(.system(size: 10))
            .foregroundStyle(Theme.inkFaint)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 4)
    }

    private var errorText: some View {
        Text(errorMessage)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.like)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
    }

    // MARK: Envoi

    private var submitButton: some View {
        Button(action: submit) {
            HStack(spacing: 8) {
                if submitting {
                    ProgressView().progressViewStyle(.circular).tint(Theme.white)
                } else {
                    IonIcon(name: "flag", size: 18, color: Theme.white)
                }
                Text(submitting ? "Envoi…" : "Envoyer le signalement")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.white)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit || submitting)
        .opacity(!canSubmit || submitting ? 0.38 : 1)
        .padding(.top, 13)
        .accessibilityLabel(submitting ? "Envoi…" : "Envoyer le signalement")
    }

    private func reset() {
        reason = nil
        details = ""
        submitting = false
        errorMessage = ""
    }

    private func submit() {
        guard let reason, canSubmit, !submitting else { return }
        submitting = true
        errorMessage = ""
        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                try await onSubmit(reason, trimmed)
            } catch let failure {
                errorMessage = (failure as? LocalizedError)?.errorDescription
                    ?? "Impossible d’envoyer le signalement."
                submitting = false
            }
        }
    }
}
