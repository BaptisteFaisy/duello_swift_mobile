//
//  SocialInviteChapterPicker.swift
//  Duello
//
//  Lot « Social » — amis choisis et sélection des chapitres du volet
//  d'invitation à un défi.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/ChallengeInviteModal.tsx   (selectedMember, selectedChip,
//                                                 chapterTrigger, chapterMenu)
//    - src/utils/challengeInvites.ts             (invitedNamesSummary)
//
//  Découpé de `SocialInviteModal.swift` (règle des 500 lignes) : contenu repris
//  à l'identique, aucun type ni libellé renommé.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI

// MARK: - Amis choisis

/// Bandeau des amis choisis (`selectedMember`) : pastilles défilables et
/// récapitulatif des noms.
struct SocInviteSelectedStrip: View {
    let members: [SocSocialProfile]
    let summary: String
    let isOnline: (String?) -> Bool
    let onRemove: (SocSocialProfile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(members) { member in
                        SocInviteSelectedChip(
                            member: member,
                            online: isOnline(member.id),
                            onRemove: { onRemove(member) }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            if !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .padding(.top, 12)
    }
}

/// Pastille d'un ami choisi (`selectedChip`) : avatar, pseudo et croix.
struct SocInviteSelectedChip: View {
    let member: SocSocialProfile
    let online: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            SocialAvatarPresence(online: online, dotSize: 7) {
                SocInviteAvatar(member: member, size: 24)
            }
            Text(member.displayName)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retirer \(member.displayName) du défi")
        }
        .padding(.leading, 4)
        .padding(.trailing, 7)
        .padding(.vertical, 4)
        .background(Theme.surface)
        .clipShape(Capsule())
    }
}

// MARK: - Chapitres

/// Déclencheur du sélecteur de chapitres (`chapterTrigger`).
struct SocInviteChapterTrigger: View {
    let summary: String
    let hasSelection: Bool
    let isOpen: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                Text(summary)
                    .font(.system(size: 14, weight: hasSelection ? .heavy : .semibold))
                    .foregroundStyle(hasSelection ? Theme.ink : Theme.inkFaint)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 48)
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusMedium).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("Choisir les chapitres")
        .padding(.top, 9)
    }
}

/// Sélecteur de chapitres (`chapterMenu`) : « Chapitres communs » puis
/// « Autres chapitres », avec un filtre de frappe.
struct SocInviteChaptersMenu: View {
    let chapters: [SocChallengeChapter]
    let playableKeys: Set<String>
    let selectedKeys: Set<String>
    let allChecked: Bool
    /// Année du joueur : une deuxième année voit l'année de chaque chapitre.
    let viewerYear: String
    @Binding var query: String
    let onToggleAll: () -> Void
    let onToggle: (SocChallengeChapter) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            filterField
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader(
                        title: playableKeys.isEmpty
                            ? "Tous les chapitres"
                            : "Chapitres communs · \(common.count)",
                        showsToggleAll: !playableKeys.isEmpty
                    )
                    ForEach(common) { chapter in row(chapter) }
                    if !others.isEmpty {
                        Rectangle()
                            .fill(Theme.border)
                            .frame(height: 1)
                            .padding(.horizontal, 12)
                            .padding(.top, 6)
                        sectionHeader(
                            title: playableKeys.isEmpty
                                ? "Aucun chapitre en commun"
                                : "Autres chapitres · \(others.count)",
                            showsToggleAll: false
                        )
                        ForEach(others) { chapter in row(chapter) }
                    }
                    if common.isEmpty && others.isEmpty {
                        Text("Aucun chapitre ne correspond à cette recherche.")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                }
            }
            .frame(maxHeight: 286)
        }
        .padding(.vertical, 6)
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMedium).stroke(Theme.border, lineWidth: 1))
        .padding(.top, 9)
    }

    /// Champ « Filtrer les chapitres… ».
    private var filterField: some View {
        TextField("Filtrer les chapitres…", text: $query)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(Theme.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            .padding(8)
    }

    /// Chapitres partagés avec l'ami sélectionné, dans l'ordre du raccourci
    /// « Chapitres communs ».
    private var common: [SocChallengeChapter] {
        filtered.filter { playableKeys.contains($0.key) }
    }

    /// Autres chapitres de la matière.
    private var others: [SocChallengeChapter] {
        filtered.filter { !playableKeys.contains($0.key) }
    }

    /// Toute la matière disponible, réduite par la frappe.
    private var filtered: [SocChallengeChapter] {
        let normalized = query.socSearchNormalized
        guard !normalized.isEmpty else { return chapters }
        return chapters.filter { $0.name.socSearchNormalized.contains(normalized) }
    }

    /// Titre de section et action « Tout cocher » / « Tout décocher ».
    private func sectionHeader(title: String, showsToggleAll: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .black))
                .kerning(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
            Spacer(minLength: 0)
            if showsToggleAll {
                Button(action: onToggleAll) {
                    Text(allChecked ? "Tout décocher" : "Tout cocher")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    allChecked ? "Décocher tous les chapitres communs" : "Cocher tous les chapitres communs"
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .frame(minHeight: 30)
    }

    /// Ligne d'un chapitre (`chapterRow`), avec sa case à cocher.
    private func row(_ chapter: SocChallengeChapter) -> some View {
        let checked = selectedKeys.contains(chapter.key)
        return Button { onToggle(chapter) } label: {
            HStack(spacing: 9) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(checked ? Theme.ink : Theme.inkFaint)
                Text(chapterLabel(chapter))
                    .font(.system(size: 10, weight: checked ? .heavy : .semibold))
                    .foregroundStyle(checked ? Theme.ink : Theme.inkSoft)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chapterLabel(chapter))
        .accessibilityValue(checked ? "Coché" : "Non coché")
    }

    /// Une deuxième année voit l'année du chapitre devant son nom.
    private func chapterLabel(_ chapter: SocChallengeChapter) -> String {
        guard viewerYear == "2e année" else { return chapter.name }
        return "\(chapter.year == 1 ? "1re" : "2e") année · \(chapter.name)"
    }
}
