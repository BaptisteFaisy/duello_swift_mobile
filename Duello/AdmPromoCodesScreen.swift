//
//  AdmPromoCodesScreen.swift
//  Duello
//
//  Codes promotionnels : création, suivi des utilisations, activation.
//
//  Fichier source Expo porté : src/admin/AdminPromoCodesScreen.tsx
//  (`AdminPromoCodesScreen`, `createCode`, `toggleCode`, `generate`,
//  `formatDate`). Les libellés sont repris mot pour mot.
//
//  Le presse-papiers est le seul service système utilisé (`Clipboard` du
//  source) : la copie reste silencieuse si elle échoue, comme côté Expo.
//
//  Cible : iOS 16. Aucune dépendance externe.
//

import SwiftUI
import UIKit

/// `AdminPromoCodesScreen` : campagne de codes promo.
struct AdmPromoCodesScreen: View {
    let token: String

    @State private var codes: [AdmPromoCodeStat] = []
    @State private var isLoading = true
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var code = ""
    @State private var label = ""
    @State private var percent = "10"
    @State private var maxRedemptions = ""
    @State private var expiresInDays = ""
    @State private var isBusy = false
    @State private var reloadKey = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                createCard
                if !successMessage.isEmpty {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.premium)
                        Text(successMessage)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.premium)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .task(id: AdmLoadKey(reload: reloadKey, token: token)) { await load() }
    }

    private var header: some View {
        AdmPageHeader(
            eyebrow: "ADMINISTRATION",
            title: "Codes promo",
            subtitle: "\(totalPeople) personne\(AdmFormat.plural(totalPeople)) ont utilisé une réduction",
            refreshLabel: "Actualiser les codes promo",
            onRefresh: { reloadKey += 1 }
        )
    }

    /// Total des personnes passées par un code (`totalPeople`).
    private var totalPeople: Int {
        codes.reduce(0) { $0 + $1.peopleCount }
    }

    /// `Générer un code promo` : code, remise, libellé, limite, expiration.
    private var createCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Générer un code promo")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Theme.ink)
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 7) {
                    AdmFieldLabel(title: "Code")
                    HStack(spacing: 8) {
                        promoField(
                            placeholder: "RENTREE2026",
                            text: $code,
                            autocapitalization: .characters
                        )
                        Button {
                            code = AdmPromoForm.generateCode()
                            successMessage = ""
                            errorMessage = ""
                        } label: {
                            Image(systemName: "die.face.5")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 44, height: 44)
                                .background(Theme.surfaceMuted)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Générer un code aléatoire")
                    }
                }
                VStack(alignment: .leading, spacing: 7) {
                    AdmFieldLabel(title: "Remise %")
                    promoField(
                        placeholder: "10",
                        text: $percent,
                        width: 74,
                        keyboard: .numberPad,
                        autocapitalization: .never
                    )
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                AdmFieldLabel(title: "Texte affiché (libellé)")
                promoField(placeholder: "Offre rentrée — moins 10 %", text: $label)
            }
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 7) {
                    AdmFieldLabel(title: "Limite d'utilisations (optionnel)")
                    promoField(
                        placeholder: "Illimité (500 par défaut)",
                        text: $maxRedemptions,
                        keyboard: .numberPad,
                        autocapitalization: .never
                    )
                }
                VStack(alignment: .leading, spacing: 7) {
                    AdmFieldLabel(title: "Expire dans (jours, optionnel)")
                    promoField(
                        placeholder: "Sans expiration",
                        text: $expiresInDays,
                        keyboard: .numberPad,
                        autocapitalization: .never
                    )
                }
            }
            Button {
                Task { await createCode() }
            } label: {
                Group {
                    if isBusy {
                        ProgressView()
                            .tint(Theme.surface)
                    } else {
                        Text("Générer le code")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Theme.surface)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel("Générer le code promo")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// Champ du formulaire : clavier et capitalisation alignés sur le source
    /// (`autoCapitalize="characters"` pour le code, clavier numérique pour les
    /// nombres, capitalisation par défaut ailleurs).
    private func promoField(
        placeholder: String,
        text: Binding<String>,
        width: CGFloat? = nil,
        keyboard: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .sentences
    ) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .autocorrectionDisabled()
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocapitalization)
            .padding(.horizontal, 14)
            .frame(maxWidth: width ?? .infinity, minHeight: 44)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            AdmStateCard(icon: "tag", message: "Chargement des codes promo…", isLoading: true)
        } else if codes.isEmpty {
            AdmStateCard(icon: "tag", message: "Aucun code promo pour le moment.")
        } else {
            VStack(spacing: 10) {
                ForEach(codes) { entry in
                    row(entry)
                }
            }
        }
    }

    private func row(_ entry: AdmPromoCodeStat) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.disabled ? "xmark.circle" : "tag")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .background(Theme.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.codeHint)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .lineLimit(1)
                Text("−\(entry.percentOff) % · \(entry.label.isEmpty ? "Campagne" : entry.label)\(entry.disabled ? " · désactivé" : "")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                Text(metaText(entry))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button {
                Task { await toggle(entry) }
            } label: {
                Image(systemName: entry.disabled ? "play" : "pause")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel(entry.disabled ? "Réactiver ce code promo" : "Désactiver ce code promo")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    /// « 3 personnes · 12/500 · créé 12 sept., 14:30 · expire … ».
    private func metaText(_ entry: AdmPromoCodeStat) -> String {
        let people = "\(entry.peopleCount) personne\(AdmFormat.plural(entry.peopleCount))"
        let limit = entry.maxRedemptions.map { "\($0)" } ?? "∞"
        var text = "\(people) · \(entry.useCount)/\(limit) · créé \(dateText(entry.createdAt))"
        if let expiresAt = entry.expiresAt {
            text += " · expire \(dateText(expiresAt))"
        }
        return text
    }

    /// `formatDate` du source : époque en millisecondes, « — » si absente.
    private func dateText(_ value: Double?) -> String {
        guard let value, value > 0 else { return "—" }
        return AdmPromoCodesScreen.dateFormatter.string(
            from: Date(timeIntervalSince1970: value / 1000)
        )
    }

    /// `createCode` : validation locale, création, copie du code, rechargement.
    @MainActor
    private func createCode() async {
        guard !isBusy else { return }
        let parsed = AdmPromoForm.parse(
            code: code,
            label: label,
            percent: percent,
            maxRedemptions: maxRedemptions,
            expiresInDays: expiresInDays
        )
        guard case let .valid(input) = parsed else {
            if case let .invalid(text) = parsed { errorMessage = text }
            return
        }
        isBusy = true
        successMessage = ""
        errorMessage = ""
        do {
            try await AdmAPI.createPromoCode(token: token, input: input)
            UIPasteboard.general.string = input.code
            successMessage = "Code \(input.code) créé et copié dans le presse-papiers."
            code = ""
            label = ""
            maxRedemptions = ""
            expiresInDays = ""
            reloadKey += 1
        } catch {
            errorMessage = AdmErrorText.message(error, fallback: "Création impossible.")
        }
        isBusy = false
    }

    /// `toggleCode` : active ou désactive un code, puis recharge la liste.
    @MainActor
    private func toggle(_ entry: AdmPromoCodeStat) async {
        isBusy = true
        do {
            try await AdmAPI.setPromoCodeDisabled(
                token: token,
                codeHint: entry.codeHint,
                disabled: !entry.disabled
            )
            reloadKey += 1
        } catch {
            errorMessage = AdmErrorText.message(error, fallback: "Action impossible.")
        }
        isBusy = false
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = ""
        do {
            codes = try await AdmAPI.listPromoCodes(token: token)
        } catch {
            codes = []
            errorMessage = AdmErrorText.message(error, fallback: "Impossible de charger les codes promo.")
        }
        isLoading = false
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter
    }()
}
