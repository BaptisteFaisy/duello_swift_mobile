//
//  ChalUiChrono.swift
//  Duello
//
//  Lot 11-A — chronomètre d'un défi : mise en forme du temps et carte du chrono.
//
//  Fichiers source Expo portés (libellés et mesures repris mot pour mot) :
//    - src/screens/ChallengesScreen.tsx (plage 166-410) : `formatChrono` et
//      `DuelChrono` (styles `chronoCard`, `chronoValue`, `chronoLabel`,
//      `chronoTrack`, `chronoTrackFill`).
//
//  Réutilise sans les recréer : `ChalTimer` (décompte borné, porté par le lot
//  « Extras de défi »). Le lot 11-C a posé un chrono d'en-tête compact
//  (`ChalRunChrono`, un simple texte) ; la carte pleine de la source, avec son
//  libellé d'état et sa barre de progression, est portée ici, sans redéfinir
//  `ChalRunChrono`.
//
//  Le compte à rebours ne bat que pour lui-même : le tic ne redessine que cette
//  carte, et l'écran n'est prévenu qu'une fois, quand le temps est écoulé.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import SwiftUI
import Foundation
import Combine

/// Mise en forme du chrono (`formatChrono`).
enum ChalUiFormat {
    /// Décompte « mm:ss », minutes et secondes sur deux chiffres.
    ///
    /// Distinct de `ChalTimer.clock` (« m:ss », sans zéro de tête) : la source
    /// porte les deux — `formatChrono` pour la carte du chrono, `formatClock`
    /// pour l'en-tête du joueur.
    static func chrono(_ totalSeconds: Double) -> String {
        let safeSeconds = max(0, Int(totalSeconds.rounded(.down)))
        return String(format: "%02d:%02d", safeSeconds / 60, safeSeconds % 60)
    }
}

/// Compte à rebours du défi (`DuelChrono`) : carte sombre, décompte « mm:ss »,
/// libellé d'état et barre de progression.
///
/// Le chrono lit `ChalTimer` entre le départ et la durée maximale ; il est figé
/// dès que la copie est rendue (`stoppedAt` non nul), et `onTimeUp` n'est appelé
/// qu'une fois par manche.
struct ChalUiDuelChrono: View {
    /// Instant de départ, en millisecondes depuis l'époque Unix.
    let startedAt: Double
    /// Instant de remise : non nul une fois la copie rendue, le chrono s'arrête.
    let stoppedAt: Double?
    /// Durée maximale du défi, en secondes.
    let totalSeconds: Double
    /// Appelé une seule fois, quand le temps est écoulé.
    var onTimeUp: () -> Void

    @State private var now: Double = Date().timeIntervalSince1970 * 1000
    @State private var notified = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Clé des entrées du chrono : tout changement remet la notification à zéro.
    private var resetKey: String { "\(startedAt)#\(stoppedAt ?? -1)#\(totalSeconds)" }

    /// Instantané borné du chrono (`challengeTimerSnapshot`).
    private var snapshot: ChalTimer.Snapshot {
        ChalTimer.snapshot(.init(
            startedAt: startedAt,
            totalSeconds: totalSeconds,
            stoppedAt: stoppedAt,
            now: now
        ))
    }

    private var remainingSeconds: Int { snapshot.remainingSeconds }

    var body: some View {
        VStack(spacing: 0) {
            Text(ChalUiFormat.chrono(Double(remainingSeconds)))
                .font(.system(size: 30, weight: .black).monospacedDigit())
                .tracking(-1)
                .foregroundStyle(Theme.white)
            if let label { stateLabel(label) }
            track
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Theme.primary)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .duelloShadow()
        .padding(.top, 20)
        .onAppear { tick() }
        .onReceive(ticker) { _ in tick() }
        .onChange(of: resetKey) { _ in
            notified = false
            tick()
        }
    }

    /// Libellé d'état, absent tant que le temps court encore.
    private var label: String? {
        if stoppedAt != nil { return "Réponse rendue — chrono arrêté" }
        if remainingSeconds == 0 {
            return "Temps écoulé — rends ta réponse pour la comparaison"
        }
        return nil
    }

    private func stateLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.primaryLight)
            .multilineTextAlignment(.center)
            .padding(.top, 6)
    }

    /// Barre de progression du temps écoulé (`chronoTrack` + `chronoTrackFill`).
    private var track: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule().fill(Theme.white).frame(width: geometry.size.width * fillRatio)
            }
        }
        .frame(height: 5)
        .padding(.top, 12)
    }

    /// Part du temps écoulé, bornée à 100 % (`Math.min(100, …)`).
    private var fillRatio: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1, max(0, Double(snapshot.elapsedSeconds) / totalSeconds))
    }

    /// Lit le chrono et prévient l'écran une seule fois quand le temps est
    /// écoulé. Sans effet une fois la copie rendue (`stoppedAt` non nul) : le
    /// tic continue de battre mais ne fait plus rien.
    private func tick() {
        now = Date().timeIntervalSince1970 * 1000
        guard stoppedAt == nil, !notified else { return }
        if snapshot.remainingSeconds == 0 {
            notified = true
            onTimeUp()
        }
    }
}
