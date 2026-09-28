//
//  PremCodeUnlockCelebration.swift
//  Duello
//
//  Célébration d’un paiement Premium tout juste confirmé par le serveur.
//
//  Fichier source Expo porté : `src/components/PremiumUnlockCelebration.tsx`
//  (la vue de célébration et son coordinateur `PremiumUnlockCelebrationCoordinator`).
//  L’événement part de la synchronisation d’abonnement (`PremCodeSync`) :
//  l’accès est déjà ouvert quand l’élève est félicité, et rien ici ne modifie
//  un droit. La célébration relit l’abonnement stocké, seule source de vérité.
//
//  Les animations `react-native-reanimated` de la source (interpolation de
//  `progress` sur une valeur partagée) sont reproduites à l’identique : un
//  pilote `progress` unique, recalculé image par image (`TimelineView`), avec
//  les **mêmes** durées, courbes et paliers d’interpolation (révélation
//  `withTiming(0.5, 680 ms, Easing.out(cubic))`, fermeture
//  `withTiming(1, 200 ms, Easing.in(cubic))`, `STATIC_PROGRESS = 0.5` en
//  mouvement réduit). Le lecteur d’écran annonce le message.
//
//  Cible : iOS 16.
//
import SwiftUI

/// Phases du pilote `progress` de la source (`useUnlockProgress` /
/// `useUnlockDismissal`).
enum PremUnlockPhase {
    /// Révélation : `progress` de 0 vers `STATIC_PROGRESS`.
    case revealing
    /// Palier atteint : `progress` figé à `STATIC_PROGRESS` jusqu’au toucher.
    case holding
    /// Fermeture : `progress` de `STATIC_PROGRESS` vers 1.
    case closing
}

/// Durées, courbes et interpolations exactes de `PremiumUnlockCelebration.tsx`.
enum PremUnlockAnimation {
    /// `CELEBRATION_REVEAL_DURATION_MS`.
    static let revealDuration: TimeInterval = 0.680
    /// `CELEBRATION_DISMISS_DURATION_MS`.
    static let dismissDuration: TimeInterval = 0.200
    /// `STATIC_PROGRESS` : valeur figée en mouvement réduit.
    static let staticProgress: Double = 0.5

    /// `progress` de la source : `Easing.out(Easing.cubic)` à la révélation,
    /// `Easing.in(Easing.cubic)` à la fermeture.
    static func progress(phase: PremUnlockPhase, elapsed: TimeInterval, reduceMotion: Bool) -> Double {
        if reduceMotion { return staticProgress }
        switch phase {
        case .revealing:
            let t = min(max(elapsed / revealDuration, 0), 1)
            return (1 - pow3(1 - t)) * staticProgress
        case .holding:
            return staticProgress
        case .closing:
            let t = min(max(elapsed / dismissDuration, 0), 1)
            return staticProgress + pow3(t) * staticProgress
        }
    }

    /// `interpolate(x, inputRange, outputRange)` de la source : linéaire par
    /// morceaux. La sortie est bornée aux extrémités, ce qui équivaut à
    /// `Extrapolation.CLAMP` **et** à l’extrapolation par défaut dès que `x`
    /// reste dans `[0, 1]` — toujours le cas ici (`progress` ∈ [0, 1]).
    static func interpolate(_ x: Double, _ input: [Double], _ output: [Double]) -> Double {
        if x <= input[0] { return output[0] }
        if x >= input[input.count - 1] { return output[output.count - 1] }
        for index in 1..<input.count where x <= input[index] {
            let span = input[index] - input[index - 1]
            let t = span == 0 ? 0 : (x - input[index - 1]) / span
            return output[index - 1] + t * (output[index] - output[index - 1])
        }
        return output[output.count - 1]
    }

    /// `t * t * t` (cubic), sans dépendance à `pow`.
    private static func pow3(_ value: Double) -> Double { value * value * value }
}

/// Écran de félicitations « Tu es Premium ».
struct PremCodeUnlockCelebration: View {
    /// Jours d’accès restants, ou `nil` quand la période n’a pas d’échéance.
    var daysRemaining: Int?
    /// Appelée quand la célébration se termine.
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: PremUnlockPhase = .revealing
    @State private var phaseStart = Date()
    @State private var finished = false

    /// Le pilote ne tourne que pendant les transitions (`TimelineView` en
    /// pause dès que `progress` est figé).
    private var paused: Bool { reduceMotion || phase == .holding }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: paused)) { context in
            stage(
                PremUnlockAnimation.progress(
                    phase: phase,
                    elapsed: context.date.timeIntervalSince(phaseStart),
                    reduceMotion: reduceMotion
                )
            )
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Paiement confirmé. Bienvenue en Premium. Toucher pour continuer.")
        .accessibilityAddTraits(.isButton)
        .onAppear {
            phaseStart = Date()
            if reduceMotion { phase = .holding }
        }
        // `useUnlockProgress` / `useUnlockDismissal` : la révélation se fige à
        // `STATIC_PROGRESS` à l’échéance, la fermeture appelle `onFinished` à la
        // sienne. `.task(id:)` annule la passe précédente à chaque changement.
        .task(id: phase) {
            switch phase {
            case .revealing:
                try? await Task.sleep(
                    nanoseconds: UInt64(PremUnlockAnimation.revealDuration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                phase = .holding
            case .closing:
                try? await Task.sleep(
                    nanoseconds: UInt64(PremUnlockAnimation.dismissDuration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                onFinished()
            case .holding:
                break
            }
        }
    }

    /// `useUnlockDismissal` : fermeture unique, jamais rejouée.
    private func dismiss() {
        guard !finished else { return }
        finished = true
        if reduceMotion { onFinished(); return }
        phase = .closing
        phaseStart = Date()
    }

    // MARK: Contenu

    /// Le fond assombri, les éclats puis la carte, selon `progress`.
    private func stage(_ progress: Double) -> some View {
        let backdropOpacity = PremUnlockAnimation.interpolate(progress, [0, 0.1, 0.5, 1], [0, 1, 1, 0])
        return ZStack {
            // `styles.backdrop` : `rgba(3, 6, 4, 0.92)`, opacité animée.
            Color(hex: 0x030604)
                .opacity(0.92 * backdropOpacity)
                .ignoresSafeArea()
            sparkleField(progress)
            card(progress)
        }
    }

    /// `UnlockSparkles` : six éclats autour de la carte (`burst`).
    private func sparkleField(_ progress: Double) -> some View {
        let opacity = PremUnlockAnimation.interpolate(progress, [0, 0.12, 0.5, 1], [0, 1, 0.85, 0])
        let scale = PremUnlockAnimation.interpolate(progress, [0, 0.3, 0.5, 1], [0.45, 1, 1, 1.3])
        let rotation = PremUnlockAnimation.interpolate(progress, [0, 1], [-12, 14])
        return ZStack {
            ForEach(Self.sparkles.indices, id: \.self) { index in
                IonIcon(
                    name: Self.sparkles[index].name,
                    size: Self.sparkles[index].size,
                    color: Self.sparkles[index].color
                )
                .offset(Self.sparkles[index].offset)
            }
        }
        .frame(width: 330, height: 430)
        .opacity(opacity)
        .scaleEffect(scale)
        .rotationEffect(.degrees(rotation))
        .allowsHitTesting(false)
    }

    /// `UnlockCard` : le sceau, le titre et le message d’accès (`card` + `seal`).
    private func card(_ progress: Double) -> some View {
        let opacity = PremUnlockAnimation.interpolate(progress, [0, 0.1, 0.22, 0.5, 1], [0, 1, 1, 1, 0])
        let scale = PremUnlockAnimation.interpolate(progress, [0, 0.14, 0.24, 0.5, 1], [0.72, 1.1, 1, 1, 0.96])
        let translateY = PremUnlockAnimation.interpolate(progress, [0, 0.24, 0.5, 1], [26, 0, 0, -8])
        return VStack(spacing: 0) {
            Text("PAIEMENT CONFIRMÉ")
                .font(.system(size: 11, weight: .black))
                .kerning(2.4)
                .foregroundStyle(Color.white.opacity(0.64))
            seal(progress)
            Text("Tu es Premium")
                .font(.system(size: 28, weight: .black))
                .kerning(-0.7)
                .foregroundStyle(Color.white)
                .padding(.top, 22)
            Text("Ton accès illimité est activé : corrections IA, annales et banque d'exercices sans limite.")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .padding(.top, 7)
            if let daysRemaining { accessPill(daysRemaining) }
            Text("TOUCHER POUR CONTINUER")
                .font(.system(size: 9, weight: .black))
                .kerning(1.25)
                .foregroundStyle(Color.white.opacity(0.38))
                .padding(.top, 26)
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x0F2418), location: 0),
                    .init(color: Color(hex: 0x08130C), location: 0.58),
                    .init(color: Color(hex: 0x050706), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        // `cardShadow` de la carte (`styles.card`) : encre 0.04, rayon 8, y 2.
        .shadow(color: Theme.ink.opacity(0.04), radius: 8, x: 0, y: 2)
        .frame(maxWidth: 350)
        .padding(.horizontal, 24)
        .scaleEffect(scale)
        .offset(y: translateY)
        .opacity(opacity)
    }

    /// Le sceau : anneau vert, disque Premium et diamant blanc (`seal`).
    private func seal(_ progress: Double) -> some View {
        let scale = PremUnlockAnimation.interpolate(progress, [0, 0.17, 0.28, 0.5, 1], [0.4, 1.18, 1, 1, 1])
        return ZStack {
            Circle()
                .fill(Color(hex: 0x16A34A).opacity(0.14))
                .overlay(Circle().stroke(Color(hex: 0x16A34A).opacity(0.44), lineWidth: 1))
                .frame(width: 124, height: 124)
            Circle().stroke(Theme.progress, lineWidth: 2).frame(width: 100, height: 100)
            Circle()
                .fill(Theme.premium)
                .frame(width: 80, height: 80)
                .overlay(IonIcon(name: "diamond", size: 42, color: .white))
        }
        .scaleEffect(scale)
        .padding(.top, 22)
    }

    /// Pastille « N jour(s) d’accès illimité » (`accessPill`).
    private func accessPill(_ daysRemaining: Int) -> some View {
        HStack(spacing: 7) {
            IonIcon(name: "flash", size: 13, color: Theme.progress)
            Text("\(daysRemaining) \(daysRemaining == 1 ? "jour" : "jours") d'accès illimité")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color(hex: 0x16A34A).opacity(0.12)))
        .overlay(Capsule().stroke(Color(hex: 0x16A34A).opacity(0.4), lineWidth: 1))
        .padding(.top, 16)
    }

    /// Éclat décoratif : glyphe Ionicons, taille, couleur et décalage depuis le
    /// centre de la boîte 330 × 430.
    private struct Sparkle {
        let name: String
        let size: CGFloat
        let color: Color
        let offset: CGSize
    }

    /// Positions relevées sur `styles.sparkle*` (boîte 330 × 430), ramenées à
    /// des décalages depuis le centre.
    private static let sparkles: [Sparkle] = [
        Sparkle(name: "sparkles", size: 28, color: .white,
                offset: CGSize(width: -5, height: -195)),
        Sparkle(name: "diamond", size: 17, color: Theme.progress,
                offset: CGSize(width: 152, height: -132)),
        Sparkle(name: "star", size: 21, color: .white,
                offset: CGSize(width: 148, height: 108)),
        Sparkle(name: "sparkles", size: 23, color: Theme.progress,
                offset: CGSize(width: 3, height: 201)),
        Sparkle(name: "diamond", size: 15, color: .white,
                offset: CGSize(width: -151, height: 123)),
        Sparkle(name: "star", size: 19, color: Theme.progress,
                offset: CGSize(width: -151, height: -135)),
    ]
}

/// Hôte de la célébration : écoute les déblocages Premium et présente la vue.
///
/// Portage de `PremiumUnlockCelebrationCoordinator` de la même source Expo. Le
/// composant se pose une fois à la racine (`App.tsx:2586`) ; ici il est monté
/// par `PremSubscriptionSyncView` (fichier premium déjà racine).
struct PremCodeUnlockCoordinator: View {
    /// Compte dont on écoute les déblocages (`member-…`).
    let accountId: String
    /// Jours d’accès restants à afficher, fournis par l’appelant.
    var daysRemaining: Int? = nil

    @State private var visible = false
    @State private var unsubscribe: (() -> Void)?

    var body: some View {
        Color.clear
            .onAppear {
                unsubscribe = PremCodeEvents.subscribeToUnlocks(accountId: accountId) {
                    visible = true
                }
            }
            .onDisappear {
                unsubscribe?()
                unsubscribe = nil
            }
            .fullScreenCover(isPresented: $visible) {
                PremCodeUnlockCelebration(daysRemaining: daysRemaining) {
                    visible = false
                }
            }
    }
}
