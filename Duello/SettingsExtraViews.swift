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
//     est journalisé à l'envoi du retour via `AdmUsageAnalyticsRecorder` (journal
//     d'usage local cloisonné par compte) ;
//   • l'auto-agrandissement du champ MESSAGE (`onContentSizeChange`) et le
//     défilement au clavier sont rendus par `TextField(axis: .vertical)` et
//     `scrollDismissesKeyboard`, comportement natif iOS ;
//   • `ExtraScheduleSettingsView` (récapitulatif des horaires) est propre à
//     iOS : la source Expo n'a pas d'écran de réglages dédié, l'éditeur y est
//     ouvert depuis l'écran de compte. Il lit et écrit la même clé persistée
//     que `PlanView`, si bien que le programme s'adapte sans autre câblage.
//
//  V1 (2026-09-29) — écart P2 : `introCard` de l'écran des horaires remplace le
//  dernier symbole SF de l'unité (`Image(systemName: "info.circle")`) par le
//  glyphe Ionicons `information-circle-outline`.
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
        // `scrollContent` de la source (`FeedbackScreen.tsx:203-209`) : `flexGrow: 1`,
        // `formArea` (82 % / 420) centré verticalement, bouton d'envoi collé au bas
        // (`marginTop: 'auto'`).
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let onBack { backButton(onBack) }
                    Spacer(minLength: 0)
                    formArea
                        .frame(width: min((proxy.size.width - 40) * 0.82, 420))
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .alert("Message envoyé", isPresented: $showConfirmation) {
            Button("OK") { resetForm() }
        } message: {
            Text("Ton retour a bien été transmis à l’équipe Duello. Merci pour ta contribution !")
        }
    }

    /// `formArea` de la source : carte de formulaire, puis la carte d'erreur le
    /// cas échéant (`FeedbackScreen.tsx:117-174`).
    private var formArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            formCard
            if !errorMessage.isEmpty {
                errorCard
                    .padding(.top, 12)
            }
        }
    }

    // MARK: Formulaires

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            field(title: "SUJET") {
                TextField("Ex: Problème de synchronisation", text: $subject)
                    // `textInput` (`FeedbackScreen.tsx:234-243`) : 14, sans graisse (400).
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
            field(title: "MESSAGE") {
                TextField("Décris ton retour en détail...", text: $message, axis: .vertical)
                    .lineLimit(6...12)
                    .font(.system(size: 14, weight: .regular))
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
            IonIcon(name: "alert-circle-outline", size: 18, color: Theme.white)
            Text(errorMessage)
                // `errorText` (`FeedbackScreen.tsx:262-268`) : 11, `fontWeight: '700'`.
                .font(.system(size: 11, weight: .bold))
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
                    IonIcon(name: "send", size: 18, color: Theme.white)
                    Text("Envoyer mon message")
                }
            }
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(Theme.surface)
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(DuelloPrimaryButton())
        // `submitButton.borderRadius: radii.medium` (14) de `FeedbackScreen.tsx:276`,
        // là où `DuelloPrimaryButton` (partagé) pose `radii.large` (18).
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.5)
    }

    private func backButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            IonIcon(name: "chevron-back", size: 20, color: Theme.ink)
                .offset(x: -4)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
                .padding(8)
                .contentShape(Rectangle())
                .padding(-8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Retour aux paramètres")
        .padding(.bottom, 12)
    }

    private func field<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                // `fieldLabel` (`FeedbackScreen.tsx:228-233`) : 12, `fontWeight: '700'`.
                .font(.system(size: 12, weight: .bold))
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
                // `recordUsageAction('feedback_sent')` de la source : le journal
                // d'usage local compte l'action pour le compte courant.
                await AdmUsageAnalyticsRecorder.recordAction(.feedbackSent, email: profile.email)
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
            // Glyphe Ionicons équivalent au symbole SF `info.circle` : plus aucun
            // SF Symbol dans l'unité (écart P2 fermé, 2026-09-29).
            IonIcon(name: "information-circle-outline", size: 18, color: Theme.ink)
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
