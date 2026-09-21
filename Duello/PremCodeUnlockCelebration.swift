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
//  ⚠️ Les animations `react-native-reanimated` de la source (interpolation de
//  `progress` sur une valeur partagée) sont approximées par une transition
//  SwiftUI unique (`withAnimation`) : même enchaînement révélation → maintien →
//  fermeture, sans la courbe d’images de la source. Le lecteur d’écran annonce
//  le message ; le mouvement est réduit si l’accessibilité le demande.
//
//  Cible : iOS 16.
//
import SwiftUI

/// Écran de félicitations « Tu es Premium ».
struct PremCodeUnlockCelebration: View {
    /// Jours d’accès restants, ou `nil` quand la période n’a pas d’échéance.
    var daysRemaining: Int?
    /// Appelée quand la célébration se termine.
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var closing = false

    var body: some View {
        ZStack {
            Color(hex: 0x030604).opacity(revealed ? 0.92 : 0).ignoresSafeArea()
            sparkleField
            card
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Paiement confirmé. Bienvenue en Premium. Toucher pour continuer.")
        .accessibilityAddTraits(.isButton)
        .onAppear { reveal() }
    }

    // MARK: Animations

    private var cardScale: CGFloat {
        if closing { return 0.96 }
        return revealed ? 1 : 0.72
    }

    private var cardOffsetY: CGFloat { revealed ? 0 : 26 }

    private var cardOpacity: Double { revealed ? 1 : 0 }

    /// `useUnlockProgress` : révélation, immédiate si le mouvement est réduit.
    private func reveal() {
        if reduceMotion { revealed = true; return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { revealed = true }
    }

    /// `useUnlockDismissal` : fermeture unique, jamais rejouée.
    private func dismiss() {
        guard !closing else { return }
        closing = true
        if reduceMotion { onFinished(); return }
        withAnimation(.easeIn(duration: 0.2)) { revealed = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onFinished() }
    }

    // MARK: Contenu

    /// `UnlockSparkles` : six éclats autour de la carte.
    private var sparkleField: some View {
        ZStack {
            ForEach(Self.sparkles.indices, id: \.self) { index in
                Image(systemName: Self.sparkles[index].systemName)
                    .font(.system(size: Self.sparkles[index].size, weight: .regular))
                    .foregroundStyle(Self.sparkles[index].color)
                    .offset(Self.sparkles[index].offset)
            }
        }
        .frame(width: 330, height: 430)
        .opacity(revealed ? 1 : 0)
        .scaleEffect(revealed ? 1 : 0.45)
        .rotationEffect(.degrees(revealed ? 14 : -12))
    }

    /// `UnlockCard` : le sceau, le titre et le message d’accès.
    private var card: some View {
        VStack(spacing: 0) {
            Text("PAIEMENT CONFIRMÉ")
                .font(.system(size: 11, weight: .black))
                .kerning(2.4)
                .foregroundStyle(Color.white.opacity(0.64))
            seal
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
        .frame(maxWidth: 350)
        .padding(.horizontal, 24)
        .scaleEffect(cardScale)
        .offset(y: cardOffsetY)
        .opacity(cardOpacity)
    }

    /// Le sceau : anneau vert, disque Premium et diamant blanc.
    private var seal: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x16A34A).opacity(0.14))
                .overlay(Circle().stroke(Color(hex: 0x16A34A).opacity(0.44), lineWidth: 1))
                .frame(width: 124, height: 124)
            Circle().stroke(Theme.progress, lineWidth: 2).frame(width: 100, height: 100)
            Circle()
                .fill(Theme.premium)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "diamond")
                        .font(.system(size: 42, weight: .regular))
                        .foregroundStyle(Color.white)
                )
        }
        .scaleEffect(revealed ? 1 : 0.4)
        .padding(.top, 22)
    }

    /// Pastille « N jour(s) d’accès illimité ».
    private func accessPill(_ daysRemaining: Int) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "flash")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.progress)
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

    /// Éclat décoratif : icône, taille, couleur et décalage depuis le centre.
    private struct Sparkle {
        let systemName: String
        let size: CGFloat
        let color: Color
        let offset: CGSize
    }

    /// Positions relevées sur `styles.sparkle*` (boîte 330 × 430), ramenées à
    /// des décalages depuis le centre.
    private static let sparkles: [Sparkle] = [
        Sparkle(systemName: "sparkles", size: 28, color: .white,
                offset: CGSize(width: -5, height: -195)),
        Sparkle(systemName: "diamond", size: 17, color: Theme.progress,
                offset: CGSize(width: 152, height: -132)),
        Sparkle(systemName: "star", size: 21, color: .white,
                offset: CGSize(width: 148, height: 108)),
        Sparkle(systemName: "sparkles", size: 23, color: Theme.progress,
                offset: CGSize(width: 3, height: 201)),
        Sparkle(systemName: "diamond", size: 15, color: .white,
                offset: CGSize(width: -151, height: 123)),
        Sparkle(systemName: "star", size: 19, color: Theme.progress,
                offset: CGSize(width: -151, height: -135)),
    ]
}

/// Hôte de la célébration : écoute les déblocages Premium et présente la vue.
///
/// Portage de `PremiumUnlockCelebrationCoordinator` de la même source Expo. Le
/// composant se pose une fois à la racine ; son câblage appartient à
/// l’application, hors de ce lot.
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
