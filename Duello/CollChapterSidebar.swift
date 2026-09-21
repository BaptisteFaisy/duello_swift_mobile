//
//  CollChapterSidebar.swift
//  Duello
//
//  Barre latérale des sections d'un chapitre de cours.
//
//  Fichiers source Expo portés (libellés repris mot pour mot) :
//    - src/components/CourseChapterSidebar.tsx
//        `CourseChapterSection`, `SECTIONS`, `CourseChapterSidebar` et
//        `courseChapterLayoutStyles` (rangée barre latérale + contenu).
//
//  Cible : iOS 16, aucune dépendance externe.
//
import SwiftUI

/// Section ouverte d'un chapitre (`CourseChapterSection`).
enum CollChapterSection: String, CaseIterable, Identifiable {
    case course
    case generate
    case create
    case review

    var id: String { rawValue }

    /// Libellé de la section (`SECTIONS`), mot pour mot.
    var label: String {
        switch self {
        case .course: return "Lire"
        case .generate: return "Générer"
        case .create: return "Créer"
        case .review: return "Réviser"
        }
    }
}

/// Barre latérale des sections du cours (`CourseChapterSidebar`).
struct CollChapterSidebar: View {
    let selected: CollChapterSection?
    let onSelect: (CollChapterSection) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(CollChapterSection.allCases) { section in
                    Button { onSelect(section) } label: {
                        Text(section.label)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                            .padding(.horizontal, 14)
                            .background(section == selected ? Theme.surfaceMuted : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(section.label)
                    .accessibilityAddTraits(section == selected ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 18)
            .padding(.bottom, 18)
        }
        .frame(width: 168)
        .background(Theme.surface)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.border).frame(width: 0.5)
        }
        .accessibilityLabel("Sections du cours")
    }
}

/// Rangée d'un chapitre : barre latérale et contenu (`courseChapterLayoutStyles`).
struct CollChapterLayout<Content: View>: View {
    let selected: CollChapterSection?
    let onSelect: (CollChapterSection) -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            CollChapterSidebar(selected: selected, onSelect: onSelect)
            content()
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
