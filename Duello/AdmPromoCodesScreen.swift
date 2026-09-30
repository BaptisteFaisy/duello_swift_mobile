//
//  AdmPromoCodesScreen.swift
//  Duello
//
//  Codes promotionnels : création, suivi des utilisations, activation.
//
//  Fichier source Expo porté : src/admin/AdminPromoCodesScreen.tsx
//  (`AdminPromoCodesScreen`, `createCode`, `toggleCode`, `generate`,
//  `formatDate`). Les libellés et les mesures sont repris mot pour mot.
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
            // Marges par bloc de la source (`AdminPromoCodesScreen.tsx:324-345`) :
            // `pageHeader` `marginBottom: 16`, `createCard` `marginBottom: 16`
            // (les messages gardent leur `marginBottom: 10`).
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 16)
                createCard
                    .padding(.bottom, 16)
                if !successMessage.isEmpty {
                    HStack(spacing: 6) {
                        IonIcon(name: "checkmark-circle", size: 15, color: Theme.premium)
                        Text(successMessage)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.premium)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 10)
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.like)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 10)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Générer un code promo")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Theme.ink)
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    AdmFieldLabel(title: "Code")
                    HStack(spacing: 8) {
                        promoField(
                            placeholder: "RENTREE2026",
                            text: $code,
                            autocapitalization: .characters,
                            autocorrect: false,
                            weight: .heavy,
                            tracking: 1
                        )
                        Button {
                            code = AdmPromoForm.generateCode()
                            successMessage = ""
                            errorMessage = ""
                        } label: {
                            IonIcon(name: "dice-outline", size: 19, color: Theme.ink)
                                .frame(width: 44, height: 44)
                                .background(Theme.surfaceMuted)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Générer un code aléatoire")
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    AdmFieldLabel(title: "Remise %")
                    promoField(
                        placeholder: "10",
                        text: $percent,
                        width: 96,
                        keyboard: .numberPad,
                        autocapitalization: .never,
                        maxLength: 2
                    )
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                AdmFieldLabel(title: "Texte affiché (libellé)")
                promoField(placeholder: "Offre rentrée — moins 10 %", text: $label)
            }
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    AdmFieldLabel(title: "Limite d'utilisations (optionnel)")
                    promoField(
                        placeholder: "Illimité (500 par défaut)",
                        text: $maxRedemptions,
                        keyboard: .numberPad,
                        autocapitalization: .never
                    )
                }
                VStack(alignment: .leading, spacing: 4) {
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
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Theme.surface)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel("Générer le code promo")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .admCardShadow()
    }

    /// Champ du formulaire : clavier, capitalisation, correction et limite de
    /// saisie alignés sur le source (`autoCorrect={false}` et `fontWeight: 800`
    /// pour le code, clavier numérique pour les nombres, `maxLength={2}` pour la
    /// remise).
    private func promoField(
        placeholder: String,
        text: Binding<String>,
        width: CGFloat? = nil,
        keyboard: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .sentences,
        autocorrect: Bool = true,
        weight: Font.Weight = .regular,
        tracking: CGFloat = 0,
        maxLength: Int? = nil
    ) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 14, weight: weight))
            .tracking(tracking)
            .foregroundStyle(Theme.ink)
            .autocorrectionDisabled(!autocorrect)
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocapitalization)
            .onChange(of: text.wrappedValue) { newValue in
                if let maxLength, newValue.count > maxLength {
                    text.wrappedValue = String(newValue.prefix(maxLength))
                }
            }
            .padding(.horizontal, 12)
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
            AdmStateCard(
                icon: "pricetag-outline",
                message: "Chargement des codes promo…",
                isLoading: true,
                showsIconWhenLoading: true
            )
        } else if codes.isEmpty {
            AdmStateCard(icon: "pricetag-outline", message: "Aucun code promo pour le moment.")
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
            rowIcon(entry)
            rowDetails(entry)
            Spacer(minLength: 8)
            Button {
                Task { await toggle(entry) }
            } label: {
                IonIcon(
                    name: entry.disabled ? "play-outline" : "pause-outline",
                    size: 18,
                    color: Theme.inkSoft
                )
                .frame(width: 40, height: 40)
                .background(Theme.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel(entry.disabled ? "Réactiver ce code promo" : "Désactiver ce code promo")
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .stroke(Theme.border, lineWidth: 1)
        )
        .admCardShadow()
    }

    /// Icône d'état de la ligne : `close-circle-outline` si le code est
    /// désactivé, sinon `pricetag-outline` — extrait de `row()`.
    private func rowIcon(_ entry: AdmPromoCodeStat) -> some View {
        IonIcon(
            name: entry.disabled ? "close-circle-outline" : "pricetag-outline",
            size: 18,
            color: Theme.ink
        )
        .frame(width: 40, height: 40)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Code, remise, libellé et méta de la ligne — extrait de `row()`.
    private func rowDetails(_ entry: AdmPromoCodeStat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.codeHint)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Theme.ink)
                .textSelection(.enabled)
                .lineLimit(1)
            Text("−\(entry.percentOff) % · \(entry.label.isEmpty ? "Campagne" : entry.label)\(entry.disabled ? " · désactivé" : "")")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
            Text(metaText(entry))
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
                .lineLimit(2)
                .padding(.top, 2)
        }
    }

    /// « 3 personnes · 12/500 · créé 12 sept. 14:30 · expire … ».
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

    /// `Intl.DateTimeFormat('fr-FR', { day, month:'short', hour, minute })` :
    /// séparateur espace entre la date et l'heure.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM HH:mm"
        return formatter
    }()
}
