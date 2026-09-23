//
//  ChalRunReveal.swift
//  Duello
//
//  Lot 11-C — déroulé d'un défi : salle d'attente, adversaire trouvé et
//  révélation différée avant l'ouverture de l'énoncé.
//
//  Fichiers source Expo portés (plage 3020-3131 de ChallengesScreen.tsx) :
//    - carte de recherche (`searchingCard`) : mode salle d'attente ou invitation,
//      nombre de joueurs présents, attente écoulée, date de départ, annulation ;
//    - carte d'adversaire trouvé (`opponentCard`) : blason « ADVERSAIRE TROUVÉ »
//      / « ADVERSAIRE D’ENTRAÎNEMENT », initiale, cote, résumé du duel ;
//    - délai de révélation `MATCH_REVEAL_MS` (ligne 251, appliqué ligne 1011) :
//      l'adversaire s'affiche un instant, puis l'énoncé s'ouvre tout seul.
//
//  Note de périmètre : la constante `MATCH_REVEAL_MS` vit hors de la plage
//  1700-3135 (ligne 1011), mais son effet — la révélation avant l'ouverture —
//  appartient au déroulé du match et est donc porté ici.
//
//  Réutilise sans les recréer : `MatchView`, `ChalRunFormat`, `ChalTimer`, le
//  modificateur `.duelloCard()` et `Theme`.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Constantes de la révélation d'un match (`MATCH_REVEAL_MS`,
/// `PLAYERS_PER_CHALLENGE`).
enum ChalRunReveal {
    /// Temps d'affichage de l'adversaire trouvé avant l'ouverture de l'exercice.
    static let matchRevealMilliseconds: Int = 900
    /// Un défi oppose deux joueurs (limite temporaire, en attendant le multijoueur).
    static let playersPerChallenge: Int = 2

    /// Le même délai, exprimé en nanosecondes pour `Task.sleep`.
    static var matchRevealNanoseconds: UInt64 { UInt64(matchRevealMilliseconds) * 1_000_000 }
}

/// Réglages de la file d'attente, tels que la carte de recherche les affiche
/// (`queue` de la source).
struct ChalRunQueueSearch: Equatable {
    /// Vrai en salle d'attente d'un défi planifié (`mode === 'scheduled'`).
    var scheduled: Bool
    /// Nombre de joueurs déjà présents (`queue.queued`).
    var queued: Int
    /// Attente écoulée, en millisecondes (`queue.waitedMs`).
    var waitedMs: Double
    /// Départ prévu, en millisecondes (`queue.scheduledStartAt`).
    var scheduledStartAt: Double?
    /// Connexion momentanément perdue (`queue.offline`).
    var offline: Bool
    /// Nom de l'invité en attente de réponse (`queue.invitedName`).
    var invitedName: String?
    var subject: String
    var durationMinutes: Int
}

/// Carte de recherche d'adversaire (`searchingCard`) : attente ou invitation.
struct ChalRunSearchingCard: View {
    let search: ChalRunQueueSearch
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .frame(width: 54, height: 54)
                .background(Theme.white)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            Text(search.scheduled ? "Salle d’attente" : "Invitation envoyée")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            ChalUiQueueStatsRow {
                ChalUiQueueStat(
                    label: "ATTENTE",
                    value: ChalTimer.clock(Int(search.waitedMs / 1000))
                )
                ChalUiQueueStat(
                    label: search.scheduled ? "DÉPART" : "RÉPONSE",
                    value: search.scheduled
                        ? search.scheduledStartAt.map(ChalRunFormat.deadline) ?? "En attente"
                        : "En attente"
                )
            }
            if search.offline || search.scheduled {
                Text(hint)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 13)
            }
            Button("Annuler") { onCancel() }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(29)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var subtitle: String {
        if search.scheduled {
            let plural = search.queued > 1 ? "s" : ""
            return "\(search.queued) joueur\(plural) présent\(plural) · \(search.subject) · \(search.durationMinutes) minutes"
        }
        return "\(search.invitedName ?? "Ton adversaire") peut accepter ou refuser · \(search.subject) · \(search.durationMinutes) minutes"
    }

    private var hint: String {
        search.offline
            ? "Connexion momentanément perdue — la réponse sera relue automatiquement."
            : "Reste dans la salle : le défi démarrera à l’heure prévue dès qu’un camarade sera présent."
    }
}

/// Carte de l'adversaire trouvé (`opponentCard`), affichée le temps de la
/// révélation avant l'ouverture de l'énoncé.
struct ChalRunOpponentCard: View {
    let match: MatchView

    private var opponent: MatchView.Opponent { match.opponent }
    private var isTraining: Bool { opponent.training == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            badge
            HStack(spacing: 12) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(opponent.displayName)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(metaLine)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("COTE")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(Theme.inkFaint)
                    Text(ChalRunFormat.elo(opponent.elo))
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Theme.ink)
                }
            }
            HStack(spacing: 8) {
                summaryItem(icon: "book", text: match.subject)
                summaryItem(icon: "timer", text: "\(match.durationMinutes) minutes")
                summaryItem(icon: "person.2", text: "\(ChalRunReveal.playersPerChallenge) joueurs")
            }
            HStack(spacing: 9) {
                ProgressView()
                Text("Ouverture de l’énoncé…")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 49)
            .background(Theme.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .duelloCard()
    }

    private var badge: some View {
        HStack(spacing: 5) {
            Image(systemName: isTraining ? "dumbbell" : "checkmark")
                .font(.system(size: 14, weight: .bold))
            Text(isTraining ? "ADVERSAIRE D’ENTRAÎNEMENT" : "ADVERSAIRE TROUVÉ")
                .font(.system(size: 8, weight: .heavy))
                .tracking(0.8)
        }
        .foregroundStyle(Theme.ink)
        .padding(.vertical, 6)
        .padding(.horizontal, 9)
        .background(Theme.primaryLight)
        .clipShape(Capsule())
    }

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surfaceMuted)
                    .frame(width: 55, height: 55)
                Text(String(opponent.displayName.prefix(1)).uppercased())
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(Theme.inkSoft)
            }
            // Pastille réservée aux joueurs réellement connectés.
            if !isTraining {
                Circle()
                    .fill(Theme.primaryLight)
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
            }
        }
    }

    /// Filière, année et prépa de l'adversaire. Le serveur n'envoie que la
    /// prépa (`MatchView.Opponent` ne porte ni `track` ni `year`) : la source
    /// joignait ces trois champs, seule la prépa reste affichable ici.
    private var metaLine: String {
        if isTraining { return "Personne dans la file — même exo, même chrono" }
        return opponent.prepName
    }

    private func summaryItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, minHeight: 43)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

/// Affiche la carte de l'adversaire trouvé, puis ouvre le contenu après le
/// délai de révélation (`MATCH_REVEAL_MS`).
struct ChalRunRevealGate<Content: View>: View {
    let match: MatchView
    @ViewBuilder var content: () -> Content

    @State private var revealed = false

    var body: some View {
        Group {
            if revealed {
                content()
            } else {
                ChalRunOpponentCard(match: match)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(Theme.background)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: ChalRunReveal.matchRevealNanoseconds)
            revealed = true
        }
    }
}
