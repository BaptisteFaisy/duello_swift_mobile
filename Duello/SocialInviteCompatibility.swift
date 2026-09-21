//
//  SocialInviteCompatibility.swift
//  Duello
//
//  Lot « Social » — filtres de compatibilité de l'invitation à un défi :
//  filière, option de maths, chapitres communs et pertinence des résultats.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/utils/challengeInvites.ts   (inviteCandidates, inviteSpecialty,
//                                       challengeInviteIncompatibility,
//                                       canProposeChallengeToMember,
//                                       memberChaptersFromProgram,
//                                       commonChallengeChapters,
//                                       compatibleInviteCandidates)
//    - src/utils/subjectElo.ts         (INITIAL_SUBJECT_ELO)
//    - src/utils/search.ts             (searchRank, searchTerms)
//    - src/data/tracks.ts              (toProgramYear, getChallengeTrackSubjects)
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation

/// Compatibilité entre le joueur qui invite et un profil de l'annuaire.
enum SocChallengeInvites {
    /// `INITIAL_SUBJECT_ELO` : Elo annoncé pour un profil qui n'en publie pas.
    static let initialSubjectElo = 1100

    /// Option de mathématiques d'un profil ECG (`mathsOption`).
    enum MathsOption {
        case appliquees
        case approfondies
    }

    /// Contexte du défi en préparation (`compatibleInviteCandidates`).
    struct Context {
        /// Filière du joueur qui invite.
        var track: String
        /// Année du joueur qui invite (n'intervient pas dans l'incompatibilité).
        var year: String
        /// Spécialité du joueur qui invite.
        var specialty: String
        /// Matière du défi, comparée au nom de matière du programme.
        var subject: String
        /// Chapitres du volet ; `nil` laisse passer tout profil compatible.
        var chapters: [SocChallengeChapter]? = nil
        /// Faux pour le Défi-Cours : ses chapitres sont déjà ceux de l'inviteur.
        var requiresCommonChapter: Bool = true
        /// Résultats montrés d'un coup (`MAX_INVITE_RESULTS`).
        var limit: Int = SocInviteDirectory.maxInviteResults
    }

    /// Option de maths reconnue dans un libellé de spécialité.
    static func mathsOption(_ value: String?) -> MathsOption? {
        let normalized = (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalized.contains("appliqu") { return .appliquees }
        if normalized.contains("approfond") { return .approfondies }
        return nil
    }

    /// Spécialité utile dans l'annuaire (`inviteSpecialty`) : l'ECG n'affiche
    /// que l'option de maths, une option absente renvoie une chaîne vide pour
    /// que la ligne d'invitation omette simplement ce segment.
    static func inviteSpecialty(_ member: SocSocialProfile) -> String {
        if member.track == "ECG" {
            guard let option = mathsOption(member.specialty) else { return "" }
            return option == .appliquees ? "Mathématiques appliquées" : "Mathématiques approfondies"
        }
        return member.specialty.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Explique pourquoi un profil trouvé ne peut pas recevoir ce défi, ou
    /// `nil` s'il le peut (`challengeInviteIncompatibility`).
    ///
    /// L'année n'intervient pas : les chapitres proposés sont ensuite limités à
    /// l'intersection des deux programmes. Une spécialité absente ne permet en
    /// revanche pas d'affirmer que le défi est compatible.
    static func incompatibility(_ member: SocSocialProfile, track: String, specialty: String) -> String? {
        if member.track != track { return "Filière différente" }

        let memberSpecialty = member.specialty.trimmingCharacters(in: .whitespacesAndNewlines)
        if memberSpecialty.isEmpty { return "Spécialité non renseignée" }

        if track == "ECG" {
            guard let challengerOption = mathsOption(specialty),
                  let memberOption = mathsOption(memberSpecialty)
            else { return "Spécialité non renseignée" }
            return challengerOption == memberOption ? nil : "Option de maths différente"
        }

        // `normalizeSpecialty` d'Expo : `trim().toLocaleLowerCase('fr-FR')`.
        // Les accents restent distinctifs ici, contrairement à la recherche.
        let normalizedChallenger = specialty.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedChallenger == memberSpecialty.lowercased() { return nil }
        return "Spécialité différente"
    }

    /// Le raccourci depuis une fiche publique n'est proposé que lorsque les
    /// deux élèves ont le même programme (`canProposeChallengeToMember`). Un
    /// profil sans spécialité publiée conserve le bouton Suivre, pas le défi.
    static func canProposeChallenge(
        to member: SocSocialProfile,
        challengerTrack: String,
        challengerSpecialty: String
    ) -> Bool {
        if member.track != challengerTrack { return false }

        let memberSpecialty = member.specialty.trimmingCharacters(in: .whitespacesAndNewlines)
        if challengerTrack == "ECG" {
            guard let challengerOption = mathsOption(challengerSpecialty),
                  let memberOption = mathsOption(memberSpecialty)
            else { return false }
            return challengerOption == memberOption
        }

        let normalizedChallenger = challengerSpecialty
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return !normalizedChallenger.isEmpty && normalizedChallenger == memberSpecialty.lowercased()
    }

    /// Clés des chapitres du programme de l'invité pour la matière du défi.
    ///
    /// Une deuxième année couvre les programmes des deux années, une première
    /// année le sien seulement. Les clés comprennent l'année et la matière :
    /// une autre filière ne peut donc jamais partager artificiellement les
    /// mêmes chapitres.
    static func memberProgramChapterKeys(_ member: SocSocialProfile, subject: String) -> Set<String> {
        // `toProgramYear` (Expo) : seule la 1re année vaut 1, tout le reste vaut 2.
        let currentYear = member.year == "1re année" ? 1 : 2
        let years = currentYear == 2 ? [1, 2] : [1]
        var keys: Set<String> = []
        for year in years {
            let program = DuelloProgram.subjects(
                track: member.track,
                specialty: member.specialty,
                year: String(year)
            )
            for candidate in program {
                guard candidate.id == SocChallengeProgram.mathsId, candidate.name == subject else { continue }
                for chapter in candidate.chapters where !SocChallengeProgram.isInformatique(chapter) {
                    keys.insert("\(year):\(candidate.id):\(chapter.id)")
                }
            }
        }
        return keys
    }

    /// Chapitres du volet présents dans le programme de l'invité, sans exiger
    /// l'intersection avec le programme de l'inviteur : utilisé par le
    /// Défi-Cours, dont la liste de chapitres reflète déjà les flashcards de
    /// l'inviteur (`memberChaptersFromProgram`).
    static func memberChaptersFromProgram(
        _ member: SocSocialProfile,
        subject: String,
        chapters: [SocChallengeChapter]
    ) -> [SocChallengeChapter] {
        let keys = memberProgramChapterKeys(member, subject: subject)
        return chapters.filter { keys.contains($0.key) }
    }

    /// Chapitres réellement présents dans les deux programmes affichés
    /// (`commonChallengeChapters`).
    ///
    /// Les anciens profils ECG ne publiaient pas leur option de mathématiques :
    /// leur année et leur filière restent fiables, mais on ne peut pas inventer
    /// une option — l'intersection se limite alors aux années couvertes, et
    /// elle est revérifiée sur le téléphone du destinataire à l'acceptation.
    static func commonChapters(
        _ member: SocSocialProfile,
        challengerTrack: String,
        subject: String,
        challengerChapters: [SocChallengeChapter]
    ) -> [SocChallengeChapter] {
        guard member.track == challengerTrack else { return [] }

        let currentYear = member.year == "1re année" ? 1 : 2
        let years = currentYear == 2 ? [1, 2] : [1]

        if member.track == "ECG" && mathsOption(member.specialty) == nil {
            return challengerChapters.filter { years.contains($0.year) }
        }

        let keys = memberProgramChapterKeys(member, subject: subject)
        return challengerChapters.filter { keys.contains($0.key) }
    }

    /// Résultats réellement invitables pour le défi en préparation, les plus
    /// proches de la recherche d'abord (`compatibleInviteCandidates`).
    ///
    /// L'annuaire a déjà retenu les profils qui correspondent : les refiltrer
    /// sur la réponse reçue ferait disparaître des personnes pourtant trouvées.
    /// Seul son propre compte est écarté — on ne se défie pas soi-même.
    static func compatibleCandidates(
        _ profiles: [SocSocialProfile],
        query: String,
        selfId: String,
        context: Context
    ) -> [SocSocialProfile] {
        let eligible = profiles.filter { member in
            guard incompatibility(member, track: context.track, specialty: context.specialty) == nil else {
                return false
            }
            guard let chapters = context.chapters else { return true }
            if context.requiresCommonChapter {
                return !commonChapters(
                    member,
                    challengerTrack: context.track,
                    subject: context.subject,
                    challengerChapters: chapters
                ).isEmpty
            }
            return !memberChaptersFromProgram(member, subject: context.subject, chapters: chapters).isEmpty
        }

        var seen: Set<String> = []
        let unique = eligible.filter { member in
            guard member.id != selfId, !seen.contains(member.id) else { return false }
            seen.insert(member.id)
            return true
        }

        let sorted = unique.sorted { first, second in
            let firstRank = searchRank(primary: first.displayName, query: query)
            let secondRank = searchRank(primary: second.displayName, query: query)
            if firstRank != secondRank { return firstRank < secondRank }
            return first.displayName.localizedStandardCompare(second.displayName) == .orderedAscending
        }
        return Array(sorted.prefix(max(0, context.limit)))
    }

    /// Pertinence d'un résultat (`searchRank` de `utils/search.ts`) : plus la
    /// valeur est basse, plus il remonte. Un nom qui commence par la recherche
    /// passe avant une correspondance au milieu.
    private static func searchRank(primary: String, query: String) -> Int {
        let terms = query.socSearchNormalized
            .split(whereSeparator: { " \t\n,.'-".contains($0) })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard let first = terms.first else { return 3 }

        let normalized = primary.socSearchNormalized
        if normalized.hasPrefix(first) { return 0 }
        // Un mot du nom qui commence par la recherche : « Bernard » pour « ber ».
        let words = normalized
            .split(whereSeparator: { " \t-".contains($0) })
            .map(String.init)
        if words.contains(where: { $0.hasPrefix(first) }) { return 1 }
        return normalized.contains(first) ? 2 : 3
    }
}
