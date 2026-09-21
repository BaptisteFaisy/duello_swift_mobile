//
//  SettingsExtraViews.swift
//  Duello
//
//  Réglages annexes — écrans secondaires rattachés aux paramètres :
//  retour utilisateur et accès à l'éditeur d'horaires de cours.
//
//  Sources Expo portées (lecture seule) :
//   • expo_ref/src/screens/FeedbackScreen.tsx      — écran « retour utilisateur »
//   • expo_ref/src/components/ScheduleEditor.tsx   — contrat d'édition des créneaux
//   • expo_ref/src/utils/socialApi.ts              — `submitFeedback` (POST /feedback)
//
//  Le type `FeedbackView` est déjà porté par le lot « Compte » : l'écran de
//  retour, ici plus complet (champ « SUJET », envoi réseau réel vers
//  `/feedback`), est donc nommé `ExtraFeedbackView` et ne le remplace pas.
//
//  Écarts assumés :
//   • `recordUsageAction('feedback_sent')` (analytics locales, `usageAnalytics`)
//     n'est pas porté : la version Swift n'a pas de journal d'usage local ;
//   • l'auto-agrandissement du champ MESSAGE (`onContentSizeChange`) et le
//     défilement au clavier sont rendus par `TextField(axis: .vertical)` et
//     `scrollDismissesKeyboard`, comportement natif iOS ;
//   • `ExtraScheduleSettingsView` (récapitulatif des horaires) est propre à
//     iOS : la source Expo n'a pas d'écran de réglages dédié, l'éditeur y est
//     ouvert depuis l'écran de compte. Il lit et écrit la même clé persistée
//     que `PlanView`, si bien que le programme s'adapte sans autre câblage.
//

import SwiftUI

// MARK: - Retour utilisateur

/// Écran « retour utilisateur » : sujet et message libres vers l'équipe Duello.
///
/// Reprend `FeedbackScreen.tsx`. Le bouton de retour n'apparaît que si l'hôte
/// fournit `onBack`, comme la source où il est facultatif.
struct ExtraFeedbackView: View {
    @EnvironmentObject private var session: SessionStore

    /// Retour arrière facultatif (`onBack` de la source).
    var onBack: (() -> Void)? = nil

    @State private var subject = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var errorMessage = ""
    @State private var showConfirmation = false

    private var canSubmit: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let onBack { backButton(onBack) }
                formCard
                if !errorMessage.isEmpty { errorCard }
                submitButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .alert("Message envoyé", isPresented: $showConfirmation) {
            Button("OK") { resetForm() }
        } message: {
            Text("Ton retour a bien été transmis à l’équipe Duello. Merci pour ta contribution !")
        }
    }

    // MARK: Formulaires

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            field(title: "SUJET") {
                TextField("Ex: Problème de synchronisation", text: $subject)
                    .font(.system(size: 14, weight: .semibold))
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
            field(title: "MESSAGE") {
                TextField("Décris ton retour en détail...", text: $message, axis: .vertical)
                    .lineLimit(6...12)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 12)
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

    private var errorCard: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(errorMessage)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
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

    private var submitButton: some View {
        Button(action: submit) {
            HStack(spacing: 10) {
                if isSending {
                    ProgressView().tint(Theme.surface)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Envoyer mon message")
                }
            }
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(Theme.surface)
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(DuelloPrimaryButton())
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.5)
    }

    private func backButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Retour aux paramètres")
    }

    private func field<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Theme.ink)
            content()
        }
        .padding(.vertical, 4)
    }

    // MARK: Envoi

    /// `handleSubmit` : envoi réseau, puis confirmation et remise à zéro au OK.
    ///
    /// Même schéma que `LoginView.submit()` : la mutation des `@State` est faite
    /// depuis la tâche, le retour utilisateur passant par l'alerte native.
    private func submit() {
        guard canSubmit else { return }
        isSending = true
        errorMessage = ""
        let profile = session.profile
        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = session.token

        Task {
            defer { isSending = false }
            do {
                try await ExtraFeedbackService.submit(
                    profile: profile,
                    subject: trimmedSubject,
                    message: trimmedMessage,
                    token: token
                )
                showConfirmation = true
            } catch {
                errorMessage = (error as? DirectoryError)?.message
                    ?? "Le message n’a pas pu être envoyé."
            }
        }
    }

    private func resetForm() {
        subject = ""
        message = ""
    }
}

// MARK: - Envoi du retour

/// `submitFeedback` de `src/utils/socialApi.ts`.
///
/// L'endpoint `POST /feedback` n'est pas exposé par `DuelloAPI` : ce relais
/// local le reproduit sans toucher au fichier partagé. Le corps reprend les
/// quatre champs de la source, l'identité venant de la session.
private enum ExtraFeedbackService {
    static func submit(
        profile: UserProfile,
        subject: String,
        message: String,
        token: String?
    ) async throws {
        let payload = ExtraFeedbackPayload(
            userId: DuelloAPI.publicProfileId(email: profile.email),
            displayName: profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            subject: subject,
            message: message
        )
        let body = try DuelloAPI.encodeBody(payload)
        _ = try await DuelloAPI.request("feedback", method: "POST", token: token, body: body)
    }
}

/// Corps de `POST /feedback` (`FeedbackSubmission` + identité du compte).
private struct ExtraFeedbackPayload: Encodable {
    let userId: String
    let displayName: String
    let subject: String
    let message: String
}

// MARK: - Réglages des horaires

/// Écran annexe des réglages : récapitulatif des horaires de cours et accès à
/// l'éditeur de créneaux (`ScheduleEditorView`).
///
/// Autonome : il porte son propre `NavigationStack` et son bouton « Fermer »,
/// comme les autres sous-pages des paramètres présentées en feuille.
struct ExtraScheduleSettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var slots: [PlanScheduleSlot] = []
    @State private var isEditing = false
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introCard
                    if slots.isEmpty {
                        DuelloEmptyState(
                            icon: "calendar",
                            title: "Aucun cours enregistré",
                            message: "Ajoute tes créneaux pour que Duello adapte ton programme à ton emploi du temps réel."
                        )
                    } else {
                        scheduleList
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Theme.background)
            .navigationTitle("Horaires de cours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Modifier") { isEditing = true }
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                }
            }
            .onAppear(perform: loadIfNeeded)
            .sheet(isPresented: $isEditing) {
                ScheduleEditorView(
                    schedule: slots,
                    onSave: { save($0) },
                    onClose: { isEditing = false }
                )
            }
        }
    }

    private var introCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Renseigne tes heures de cours pour que Duello adapte ton programme en fonction de ton emploi du temps réel.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
    }

    private var scheduleList: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(daysWithSlots, id: \.self) { day in
                VStack(alignment: .leading, spacing: 8) {
                    DuelloSectionHeader(title: day)
                    VStack(spacing: 0) {
                        ForEach(daySlots(day)) { slot in
                            ExtraScheduleSlotRow(slot: slot)
                        }
                    }
                    .duelloCard()
                }
            }
        }
    }

    private var daysWithSlots: [String] {
        ExtraScheduleCatalog.days.filter { day in
            slots.contains { $0.day == day }
        }
    }

    private var accountKey: String {
        let email = session.profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return email.isEmpty ? "local" : DuelloAPI.publicProfileId(email: email)
    }

    private func daySlots(_ day: String) -> [PlanScheduleSlot] {
        slots.filter { $0.day == day }.sorted { $0.startTime < $1.startTime }
    }

    private func loadIfNeeded() {
        guard !hasLoaded else { return }
        if let stored = PlanStorage.loadSchedule(accountKey: accountKey) { slots = stored }
        hasLoaded = true
    }

    private func save(_ updated: [PlanScheduleSlot]) {
        slots = updated
        PlanStorage.saveSchedule(updated, accountKey: accountKey)
    }
}

// MARK: - Ligne de créneau

/// Ligne de lecture d'un créneau : plage horaire, matière et salle éventuelle.
private struct ExtraScheduleSlotRow: View {
    let slot: PlanScheduleSlot

    var body: some View {
        HStack(spacing: 12) {
            Text(slot.startTime)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .frame(width: 46, alignment: .leading)
            Text("-")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.inkFaint)
            Text(slot.endTime)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .frame(width: 46, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.subject)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                if let room = slot.room, !room.isEmpty {
                    Text("Salle \(room)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}
