//
//  ExGExerciseLeaderboard.swift
//  Duello
//
//  Classement d'exercice : modèles (`exerciseLeaderboard.ts`), client du relais
//  et fenêtre du classement (`ExerciseTrophyButton.tsx`).
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/ExerciseTrophyButton.tsx          (classement du bilan)
//    - src/utils/exerciseLeaderboard.ts, socialApi.ts
//
//  Découpé de `ExerciseGradingViews.swift` (1 975 lignes) le 2026-09-21 : contenu
//  repris ligne pour ligne — aucun type, propriété, méthode ni signature renommé.
//  Spécification de référence : specs/exws_C.md (§0 socle commun, §1 à §5
//  composants, §6 récapitulatif animations, §7 dépendances non portables).
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import SwiftUI

/// `ExerciseLeaderboardActivity` de `utils/exerciseLeaderboard.ts`.
enum ExGLeaderboardActivity: String {
    case exercice, colle, annale
}

/// Bouton de classement du bilan (`ExerciseTrophyButton.tsx`).
struct ExGTrophy: Equatable {
    var itemId: String
    var subject: String
    var title: String
    var activity: ExGLeaderboardActivity = .exercice
    /// Un sujet d'annales n'a pas de bilan interactif : il garde ses boutons.
    var isAnnale: Bool = false
    /// Masque la fenêtre native pendant la consultation d'un autre onglet.
    var active: Bool = true
}

/// Ligne d'un classement d'exercice (`ExerciseLeaderboardEntry`).
struct ExGLeaderboardEntry: Identifiable, Equatable, Decodable {
    var id: String
    var displayName: String
    var photoUri: String?
    var academicStatus: String?
    var score: Double
    var firstTry: Bool
    var achievedAt: String
    var rank: Int

    enum CodingKeys: String, CodingKey {
        case id, displayName, photoUri, academicStatus, score, firstTry, achievedAt, rank
    }

    /// Décodage tolérant, comme `Models.swift` : le serveur omet parfois un
    /// champ ou en change le type.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        photoUri = try? c.decodeIfPresent(String.self, forKey: .photoUri)
        academicStatus = try? c.decodeIfPresent(String.self, forKey: .academicStatus)
        score = (try? c.decode(Double.self, forKey: .score)) ?? 0
        firstTry = (try? c.decode(Bool.self, forKey: .firstTry)) ?? false
        achievedAt = (try? c.decode(String.self, forKey: .achievedAt)) ?? ""
        rank = (try? c.decode(Int.self, forKey: .rank)) ?? 0
    }

    init(id: String, displayName: String, photoUri: String? = nil,
         academicStatus: String? = nil, score: Double, firstTry: Bool,
         achievedAt: String, rank: Int) {
        self.id = id
        self.displayName = displayName
        self.photoUri = photoUri
        self.academicStatus = academicStatus
        self.score = score
        self.firstTry = firstTry
        self.achievedAt = achievedAt
        self.rank = rank
    }
}

// MARK: - §1 — Classement d'exercice

/// `fetchExerciseLeaderboard` de `utils/socialApi.ts`.
///
/// L'annuaire social n'est pas exposé par `DuelloAPI` : ce client local
/// réutilise le relais (`DuelloAPI.request`) sur `exercise-leaderboard`.
/// L'enrichissement des statuts scolaires par l'annuaire des profils n'est pas
/// repris — le serveur sert déjà `academicStatus` quand il le connaît.
private enum ExGLeaderboardClient {
    private struct Payload: Decodable {
        var entries: [ExGLeaderboardEntry]?
    }

    static func fetch(activity: ExGLeaderboardActivity, itemId: String,
                      subject: String, token: String?) async throws -> [ExGLeaderboardEntry] {
        let query = [
            URLQueryItem(name: "activity", value: activity.rawValue),
            URLQueryItem(name: "itemId", value: itemId),
            URLQueryItem(name: "subject", value: subject),
        ]
        let payload = try await DuelloAPI.request(
            Payload.self,
            "exercise-leaderboard",
            token: token,
            query: query
        )
        return payload.entries ?? []
    }
}

/// `ExerciseTrophyButton` : le déclencheur du classement.
///
/// La présence temps réel (`usePresence`, socket) n'est pas portée : la
/// pastille « en ligne » du classement est laissée de côté, faute de source de
/// présence côté natif. L'historique des métriques
/// (`ExerciseMetricHistoryPage`) appartient à un autre écran : il est exposé
/// par `onOpenHistory`, appelé depuis la ligne du joueur lui-même.
struct ExGTrophyButton: View {
    let trophy: ExGTrophy
    var onOpenProfile: ((String) -> Void)? = nil
    var onOpenHistory: ((String) -> Void)? = nil

    @State private var visible = false

    private var triggerLabel: String {
        trophy.activity == .colle
            ? "Ouvrir le classement de la colle"
            : "Ouvrir le classement de l’exercice"
    }

    var body: some View {
        Button(action: { visible = true }) {
            Image(systemName: "trophy")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 32, height: 32)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(triggerLabel)
        .sheet(isPresented: $visible) {
            ExGLeaderboardSheet(
                trophy: trophy,
                onOpenProfile: onOpenProfile,
                onOpenHistory: onOpenHistory
            )
        }
    }
}

/// Fenêtre du classement : en-tête, états de chargement, liste des rangs.
struct ExGLeaderboardSheet: View {
    let trophy: ExGTrophy
    var onOpenProfile: ((String) -> Void)? = nil
    var onOpenHistory: ((String) -> Void)? = nil

    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var state: LoadState = .idle
    @State private var entries: [ExGLeaderboardEntry] = []

    private var viewerPublicId: String? {
        if let publicId = session.session?.publicId, !publicId.isEmpty { return publicId }
        let email = session.profile.email
        return email.isEmpty ? nil : DuelloAPI.publicProfileId(email: email)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Theme.background.ignoresSafeArea())
        .task { await load() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 42, height: 42)
                    .background(Theme.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer le classement")

            if trophy.activity == .colle || trophy.isAnnale {
                VStack(spacing: 2) {
                    Text(trophy.isAnnale ? "Classement de l’annale" : "Classement de la colle")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.primary)
                    Text(trophy.title)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                Color.clear.frame(width: 42, height: 42)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(minHeight: 74)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle, .loading:
            VStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Chargement du classement…")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
            VStack(spacing: 10) {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Text("Classement indisponible")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(Theme.ink)
                Text("Réessaie dans quelques instants.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready:
            if entries.isEmpty {
                DuelloEmptyState(icon: "trophy", title: "Aucun classement")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(entries) { entry in
                            row(entry)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
        }
    }

    private func row(_ entry: ExGLeaderboardEntry) -> some View {
        Button(action: { onOpenProfile?(entry.id) }) {
            HStack(spacing: 10) {
                Text("\(entry.rank)")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 20)

                avatar(entry)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(entry.displayName)
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        if let status = entry.academicStatus, !status.isEmpty {
                            // `DuelloPill` du kit : la casse majuscule reste
                            // purement visuelle, le libellé serveur est rendu
                            // tel quel à la lecture d'écran.
                            DuelloPill(text: status, tone: .neutral)
                        }
                        if entry.firstTry {
                            Text("1er coup")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(Theme.primary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Theme.primaryLight)
                                .clipShape(Capsule())
                        }
                    }
                    Text("Meilleure note obtenue le \(ExGFormat.achievementDate(entry.achievedAt))")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(ExGFormat.score(entry.score))
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.primary)

                if entry.id == viewerPublicId, let onOpenHistory {
                    Button(action: { onOpenHistory(entry.id) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Historique")
                                .font(.system(size: 10, weight: .black))
                        }
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 28)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                                .stroke(Theme.primary, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Voir mon historique de métriques")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(minHeight: 76)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(onOpenProfile == nil)
        .accessibilityLabel("Voir le profil de \(entry.displayName), rang \(entry.rank), note \(ExGFormat.score(entry.score))")
    }

    private func avatar(_ entry: ExGLeaderboardEntry) -> some View {
        Group {
            if let photoUri = entry.photoUri, let url = URL(string: photoUri) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Theme.surfaceMuted)
                }
                .frame(width: 42, height: 42)
                .clipShape(Circle())
            } else {
                ZStack {
                    Circle().fill(Theme.surfaceMuted)
                    Image(systemName: "person.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(width: 42, height: 42)
            }
        }
    }

    private func load() async {
        state = .loading
        do {
            entries = try await ExGLeaderboardClient.fetch(
                activity: trophy.activity,
                itemId: trophy.itemId,
                subject: trophy.subject,
                token: session.token
            )
            state = .ready
        } catch {
            state = .error
        }
    }
}
