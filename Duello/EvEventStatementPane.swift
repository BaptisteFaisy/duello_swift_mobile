//
//  EvEventStatementPane.swift
//  Duello
//
//  Moitié haute de la page d'épreuve : le sujet, question par question, chaque
//  question présentée avec son numéro et ses points, comme sur une copie papier.
//
//  Fichier source Expo porté : `src/components/event/EventStatementPane.tsx`.
//
//  Cible : iOS 16.
//
import SwiftUI

struct EvEventStatementPane: View {
    let title: String
    let questions: [EvEventQuestion]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Theme.ink)
                ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                    card(index: index, question: question)
                }
            }
            .padding(16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Une question du sujet : pastille du numéro, points, énoncé.
    private func card(index: Int, question: EvEventQuestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 24, height: 24)
                    .background(Theme.surfaceMuted)
                    .clipShape(Circle())
                Text("\(question.points) pts")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
                Spacer(minLength: 0)
            }
            Text(question.statement)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}
