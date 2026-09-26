//
//  OfflDownloadProgressView.swift
//  Duello
//
//  Bandeau de progression du téléchargement hors connexion.
//
//  Fichier source Expo porté : `src/components/OfflineDownloadProgress.tsx`
//  (titre « Téléchargement hors connexion », pourcentage, détail, et les
//  messages « Préparation du téléchargement… », « Téléchargement interrompu ·
//  Réessayer », « … / … téléchargés », « Aucun contenu téléchargé »).
//
//  Le bandeau disparaît une fois le téléchargement complet (`return null` de la
//  source). Les libellés sont repris mot pour mot ; les octets sont formatés en
//  Kio/Mio (base 1024) comme `formatByteCount`.
//
//  Cible : iOS 16.
//
import SwiftUI

/// Bandeau de progression (`OfflineDownloadProgress`).
struct OfflDownloadProgressView: View {
    let state: OfflOfflineCacheState
    var onPress: () -> Void = {}

    var body: some View {
        if state.status == .complete {
            EmptyView()
        } else {
            card
        }
    }

    private var card: some View {
        Button(action: onPress) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.primary)
                    Text("Téléchargement hors connexion")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(percent) %")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Theme.primary)
                }
                DuelloProgressTrack(fraction: Double(percent) / 100, tint: Theme.primary, height: 6)
                Text(detail)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(11)
            .background(Theme.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .padding(.top, 22)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Téléchargement hors connexion à \(percent) pour cent. \(detail)")
        .accessibilityValue(Text("\(percent) %"))
    }

    private var percent: Int {
        guard state.totalBytes > 0 else { return 0 }
        return min(100, Int(floor(Double(state.downloadedBytes) / Double(state.totalBytes) * 100)))
    }

    private var detail: String {
        if state.status == .requesting { return "Préparation du téléchargement…" }
        if state.status == .error { return "Téléchargement interrompu · Réessayer" }
        if state.totalBytes > 0 {
            return "\(formatByteCount(state.downloadedBytes)) / \(formatByteCount(state.totalBytes)) téléchargés"
        }
        return "Aucun contenu téléchargé"
    }

    private func formatByteCount(_ bytes: Int) -> String {
        let mebibytes = Double(bytes) / (1024 * 1024)
        if mebibytes < 1 {
            return "\(Int((Double(bytes) / 1024).rounded())) Kio"
        }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.maximumFractionDigits = mebibytes < 10 ? 1 : 0
        formatter.minimumFractionDigits = 0
        let number = formatter.string(from: NSNumber(value: mebibytes)) ?? String(format: "%.1f", mebibytes)
        return "\(number) Mio"
    }
}
