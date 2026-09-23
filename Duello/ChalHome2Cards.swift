//
//  ChalHome2Cards.swift
//  Duello
//
//  Lot 11-B — accueil des défis : les cartes d'annonce de l'accueil et le
//  retour d'une invitation (« cartes de défi en cours »).
//
//  Fichier source Expo porté (libellés et règles repris mot pour mot) :
//    - src/screens/ChallengesScreen.tsx
//        · avis « exercices jouables » (`successNotice`, lignes 2818-2830) :
//          aucun exercice jouable, ou tous déjà commencés ;
//        · avis d'échec de lancement (`launchError`, lignes 2831-2836) ;
//        · retour d'invitation (`queue.inviteOutcome`, lignes 2890-2913) :
//          indisponible, refusée, expirée, ou envoi impossible ;
//        · style `successNotice` / `successNoticeText` (lignes 3911-3926).
//
//  Réutilise sans les recréer : `Theme`, `ChalQueueController.InviteOutcome` et
//  `.duelloCard()` là où la source pose une carte. Les cartes d'attente et
//  d'adversaire trouvé vivent déjà dans le lot 11-C (`ChalRunReveal.swift`) : le
//  fichier ne les reduplique pas, il porte les avis de l'accueil.
//
//  Substitutions SF Symbols (Ionicons → SF Symbols) : information-circle-outline
//  → info.circle ; alert-circle-outline → exclamationmark.circle ;
//  notifications-outline → bell ; close-circle-outline → xmark.circle.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

/// Ton d'une carte d'annonce : l'information porte l'encre, l'échec le rouge.
enum ChalHome2NoticeTone {
    case info
    case error

    /// Icône par défaut du ton (surchargeable, cf. `ChalHome2NoticeCard`).
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .error: return "exclamationmark.circle"
        }
    }

    /// Couleur de l'icône : encre dans les deux cas (`colors.danger` de la
    /// source vaut `#0A0D0C`, l'encre).
    var color: Color {
        switch self {
        case .info: return Theme.ink
        case .error: return Theme.ink
        }
    }
}

/// Carte d'annonce de l'accueil (`successNotice`) : icône et texte, fond gris
/// clair. Sert aux avis d'exercices jouables comme aux retours d'invitation.
struct ChalHome2NoticeCard: View {
    var tone: ChalHome2NoticeTone
    var text: String
    /// Icône explicite ; à défaut, celle du ton.
    var icon: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon ?? tone.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tone.color)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous))
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }
}

/// Avis « exercices jouables » de l'accueil (lignes 2818-2830).
enum ChalHome2PlayableNotice: Equatable {
    /// Rien à signaler.
    case none
    /// Aucun chapitre de l'année n'a d'exercice jouable.
    case noPlayableExercises
    /// Tous les exercices de la sélection sont déjà commencés.
    case allStarted

    /// Message affiché ; `nil` quand il n'y a rien à dire.
    var message: String? {
        switch self {
        case .none: return nil
        case .noPlayableExercises:
            return "Aucun exercice jouable n’est encore disponible pour les chapitres de ton année."
        case .allStarted:
            return "Tous les exercices de cette sélection ont déjà été commencés sur ce compte."
        }
    }
}

/// Retour d'une invitation privée (`queue.inviteOutcome`).
struct ChalHome2InviteOutcomeCard: View {
    var outcome: ChalQueueController.InviteOutcome

    var body: some View {
        ChalHome2NoticeCard(tone: .info, text: text, icon: icon)
    }

    /// Icône par état : cloche si le joueur était déjà en défi, croix s'il a
    /// refusé, point d'exclamation sinon (expiré ou envoi impossible).
    private var icon: String {
        switch outcome {
        case .unavailable: return "bell"
        case .declined: return "xmark.circle"
        case .expired, .error: return "exclamationmark.circle"
        }
    }

    /// Phrase par état, mot pour mot de la source.
    private var text: String {
        switch outcome {
        case .unavailable(let name):
            return "\(name) est déjà en défi : aucune popup ne s’est affichée, une notification lui a été envoyée."
        case .declined(let name):
            return "\(name) a refusé le défi."
        case .expired(let name):
            return "\(name) n’a pas répondu à temps."
        case .error(let name):
            return "L’invitation à \(name) n’a pas pu être envoyée."
        }
    }
}

/// Les annonces de l'accueil, dans l'ordre de la source : avis d'exercices
/// jouables, puis échec de lancement. Le retour d'invitation
/// (`ChalHome2InviteOutcomeCard`) est posé **après** la carte d'accueil, par
/// l'appelant, comme dans la source.
struct ChalHome2HomeNotices: View {
    var playable: ChalHome2PlayableNotice = .none
    var launchError: String?

    var body: some View {
        VStack(spacing: 0) {
            if let message = playable.message {
                ChalHome2NoticeCard(tone: .info, text: message)
            }
            if let launchError = launchError, !launchError.isEmpty {
                ChalHome2NoticeCard(tone: .error, text: launchError)
            }
        }
    }
}
