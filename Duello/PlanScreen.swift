//
//  PlanScreen.swift
//  Duello
//
//  Écran « Plan » : planning journalier par blocs horaires (grille 00:00 → 00:00),
//  saisie de tâches en langage naturel, répartition automatique des tâches sur
//  les jours du programme, coche et report d'une tâche.
//
//  Sources Expo portées (lecture seule) :
//   • expo_ref/src/screens/EnhancedPlanScreen.tsx   — écran principal (677 lignes)
//   • expo_ref/src/components/TaskCaptureCard.tsx   — carte « AJOUT RAPIDE »
//   • expo_ref/src/utils/taskParser.ts              — analyseur local + urgence
//   • expo_ref/src/utils/date.ts                    — jours du programme, clés
//   • expo_ref/src/utils/ollamaClient.ts            — analyse IA locale + repli
//   • premium_extract/01_EnhancedPlanScreen.md      — spécification de portage
//
//  Limites assumées, documentées au fil du fichier :
//   • le repli IA locale (`ollamaClient`) est porté mais dormant : réglages
//     désactivés par défaut et URL `http://` sur le réseau local (ATS peut la
//     refuser) — l'analyseur local prend toujours le relais ;
//   • l'éditeur d'horaires de cours (`ScheduleEditor.tsx`) n'appartient à aucun
//     lot : la grille lit les créneaux persistés s'ils existent, sinon le rappel
//     « Ajoute tes horaires de cours… » s'affiche, comme dans la source ;
//   • le `console.log` de repli (EnhancedPlanScreen ligne 168) n'est pas porté :
//     aucun `print` dans ce fichier ;
//   • Écart (2026-09-30) — le fond du détail de séance est posé en `overlay` du
//     `ScrollView` de `PlanView`, pas à la racine (`MainTabView.swift` porte la
//     barre d'onglets) : le voile défile jusqu'au bas de la fenêtre (safe area
//     comprise), mais **la barre d'onglets reste au-dessus du voile**. Corriger
//     vraiment exige de monter l'overlay à la racine (`MainTabView.swift`), hors
//     périmètre : une `fullScreenCover` transparente rendrait la `Modal` Expo
//     mais `presentationBackground` (iOS 16.4+) est interdit par `check-ios16.sh`.
//
//  Extensions locales exigées par le contrat du lot, absentes de l'écran Expo :
//  coche d'une tâche (`isDone`), report d'un jour (`postponedDays`), liste des
//  tâches et repère hebdomadaire. S'y ajoutent, pour tenir l'écran sur iOS :
//  la section « Objectifs du jour » (pendant accessible de la grille), la touche
//  « Terminé » du clavier numérique (la source validait au `onBlur`), et les
//  mentions « Prévue … », « Sans échéance » et « reportée de n jour(s) » des
//  lignes de tâche.
//

import Foundation
import SwiftUI

// MARK: - Écran

/// Planning journalier : carrousel de jours, grille horaire 00:00 → 00:00,
/// saisie de tâches en langage naturel, coche et report.
struct PlanView: View {
    @EnvironmentObject private var session: SessionStore

    @State var selectedDayOffset = 0
    @State var days: [PlanDay] = [PlanDateEngine.firstDay()]
    @State var tasks: [PlanTask] = PlanTask.starters
    @State private var schedule: [PlanScheduleSlot] = []
    @State private var hasLoaded = false
    @State var lastAddedCount = 0
    @State var isAnalyzing = false
    @State var ollamaFallbackNotice = false
    @State var ollamaSettings = PlanOllamaSettings()
    @State private var selectedSession: PlanSession?
    @State var dateInput: String = PlanDateEngine.longDate(Date())
    @State var dateError: String?
    @State var isEditingDate = false
    @State var composerText = ""
    /// Hauteur de la fenêtre et des sections au-dessus de la grille, mesurées
    /// pour que la zone-jour occupe l'espace restant (source `onLayout`, l. 258).
    @State private var viewportHeight: CGFloat = 0
    @State private var measuredSections: [String: CGFloat] = [:]
    @FocusState private var dateFieldFocused: Bool

    /// Rythme quotidien du profil (`profile.dinnerTime/showerTime/bedtime`,
    /// EnhancedPlanScreen lignes 574-576), et non plus des constantes.
    private var routine: PlanRoutine {
        PlanRoutine.from(session.profile)
    }

    // MARK: Clés et dérivés

    private var accountKey: String {
        let email = session.profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return email.isEmpty ? "local" : DuelloAPI.publicProfileId(email: email)
    }

    var selectedDay: PlanDay {
        day(for: selectedDayOffset)
    }

    func day(for offset: Int) -> PlanDay {
        if let match = days.first(where: { $0.dayOffset == offset }) { return match }
        if let first = days.first { return first }
        return PlanDateEngine.firstDay()
    }

    private func sessions(for day: PlanDay) -> [PlanSession] {
        distributedSessions.filter { $0.dayOffset == day.dayOffset }
    }

    /// `distributeTasks` de la source, rejoué à chaque changement de tâche : la
    /// grille reste le reflet exact de la liste.
    private var distributedSessions: [PlanSession] {
        PlanScheduler.distribute(
            tasks: tasks,
            schedule: schedule,
            dayCount: max(1, days.count),
            routine: routine
        )
    }

    private var doneCount: Int { tasks.filter { $0.isDone }.count }

    private var plannedLabels: [String: String] {
        var labels: [String: String] = [:]
        for session in distributedSessions {
            let target = day(for: session.dayOffset)
            labels[session.taskId] = "\(PlanTaskAnalyzer.capitalize(target.dayLabel)) \(target.dayNumber) · \(session.startTime)"
        }
        return labels
    }

    /// Hauteur réellement disponible pour la journée : mesurée (fenêtre moins
    /// sections du haut moins la réserve basse), comme la source (lignes 61-63,
    /// 256-258, 386). La constante ne sert que tant que la mesure n'est pas là.
    private var dayAreaHeight: CGFloat {
        guard viewportHeight > 0 else { return PlanMetrics.dayAreaHeight }
        let above = measuredSections["above"] ?? 0
        let available = viewportHeight - 8 - above - 12 - PlanMetrics.dayAreaReserve
        return max(PlanMetrics.minimumDayAreaHeight, available)
    }

    // MARK: Corps

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                aboveContent.planMeasureHeight("above")
                dayPager
                PlanObjectivesCard(
                    day: selectedDay,
                    sessions: sessions(for: selectedDay),
                    onSelect: { selectedSession = $0 }
                )
                .padding(.horizontal, 20)
                PlanTaskListCard(
                    tasks: tasks,
                    plannedLabels: plannedLabels,
                    doneCount: doneCount,
                    onToggle: { toggle($0) },
                    onReport: { report($0) }
                )
            }
            .padding(.top, 8)
            // La carte de saisie flotte (source `floatingContainer`) : la réserve
            // basse reprend son `marginBottom: 66` (ligne 640).
            .padding(.bottom, PlanMetrics.dayAreaReserve)
        }
        .background(Theme.background)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: PlanViewportHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(PlanViewportHeightKey.self) { viewportHeight = $0 }
        .onPreferenceChange(PlanSectionHeightKey.self) { measuredSections = $0 }
        .scrollDismissesKeyboard(.interactively)
        .overlay(alignment: .bottom) {
            PlanTaskComposerCard(text: $composerText) { addTasks(from: composerText) }
        }
        .overlay {
            if let session = selectedSession {
                PlanSessionDetailOverlay(session: session) { selectedSession = nil }
                    // `modalBackdrop` (`EnhancedPlanScreen.tsx:298-305`) couvre
                    // toute la fenêtre : le voile doit donc déborder de la zone
                    // de contenu, safe area basse comprise.
                    .ignoresSafeArea(.container, edges: .bottom)
                    .transition(.opacity)
            }
        }
        // `Modal animationType="fade"` (ligne 301) : fondu à l'ouverture/fermeture.
        .animation(.easeInOut(duration: 0.3), value: selectedSession?.id)
        .toolbar {
            // Le clavier numérique n'a pas de touche de retour : ce bouton
            // déclenche la validation de la date (comportement `onBlur` de la
            // source), sinon la saisie resterait ouverte sans issue.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Terminé") { dateFieldFocused = false }
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
        }
        .onAppear {
            refreshProgramIfNeeded()
            loadProgramIfNeeded()
        }
        .onChange(of: selectedDayOffset) { offset in
            guard !isEditingDate else { return }
            dateError = nil
            dateInput = PlanDateEngine.longDate(day(for: offset).date)
        }
        .onChange(of: dateFieldFocused) { focused in
            if focused {
                startEditingDate()
            } else {
                submitDateInput()
            }
        }
        .onChange(of: dateInput) { value in
            handleDateInput(value)
        }
    }

    // MARK: Sections au-dessus de la grille (mesurées ensemble)

    private var aboveContent: some View {
        // Espacement 0 : les marges basses viennent de chaque bloc, comme les
        // `marginBottom` de la source (bandeau 4/12, `dateJump` 12, rappel 12).
        VStack(alignment: .leading, spacing: 0) {
            banners
            dateJumpBar.padding(.bottom, 12)
            if schedule.isEmpty { scheduleHint.padding(.bottom, 12) }
            weekStrip
        }
    }

    // MARK: Bandeaux (B1, B2, B3 de la source)

    @ViewBuilder
    private var banners: some View {
        if isAnalyzing {
            PlanBanner(
                tone: .info,
                icon: nil,
                text: "Qwen analyse tes tâches et tes formules…",
                showsSpinner: true
            )
        }
        if !isAnalyzing && ollamaFallbackNotice {
            PlanBanner(
                tone: .warning,
                icon: "warning-outline",
                iconSize: 18,
                text: "Assistant IA local injoignable, tâches ajoutées avec l’analyseur standard."
            )
        }
        if !isAnalyzing && lastAddedCount > 0 {
            PlanBanner(
                tone: .success,
                icon: "checkmark-circle",
                iconSize: 19,
                text: "\(lastAddedCount) \(lastAddedCount > 1 ? "tâches ajoutées et planifiées" : "tâche ajoutée et planifiée")."
            )
        }
    }

    // MARK: Bloc date

    private var dateJumpBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                IonIcon(name: "calendar-outline", size: 18, color: Theme.inkSoft)

                TextField("JJ/MM/AAAA", text: $dateInput)
                    .keyboardType(.numberPad)
                    .submitLabel(.go)
                    .focused($dateFieldFocused)
                    .font(.system(size: 14, weight: .heavy))
                    .kerning(0.5)
                    .foregroundStyle(Theme.ink)
                    .accessibilityLabel("Aller à une date")

                if selectedDayOffset != 0 {
                    Button {
                        goToToday()
                    } label: {
                        Text("Aujourd’hui")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Theme.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall))
                    }
                    .buttonStyle(PlanPressStyle())
                    .accessibilityLabel("Revenir à aujourd’hui")
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .stroke(Theme.border, lineWidth: 1)
            )

            if let dateError {
                Text(dateError)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: Rappel horaires (B5)

    private var scheduleHint: some View {
        HStack(spacing: 9) {
            IonIcon(name: "time-outline", size: 18, color: Theme.ink)
            Text("Ajoute tes horaires de cours dans ton profil pour éviter automatiquement ces créneaux.")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .padding(.horizontal, 20)
    }

    // MARK: Repère hebdomadaire

    /// La source balaye tout l'horizon du programme ; ici la semaine du jour
    /// sélectionné est rappelée en puces, pour se repérer sans balayer.
    private var weekStrip: some View {
        let weekStart = (selectedDayOffset / 7) * 7
        let week = days.filter { $0.dayOffset >= weekStart && $0.dayOffset < weekStart + 7 }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(week) { entry in
                    DuelloChip(
                        title: "\(PlanTaskAnalyzer.capitalize(entry.dayLabel)) \(entry.dayNumber)",
                        selected: entry.dayOffset == selectedDayOffset
                    ) {
                        goToDay(entry.dayOffset)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: Carrousel de jours (B6)

    private var dayPager: some View {
        TabView(selection: $selectedDayOffset) {
            ForEach(days) { entry in
                PlanDayPage(
                    day: entry,
                    sessions: sessions(for: entry),
                    areaHeight: dayAreaHeight,
                    onSelect: { selectedSession = $0 }
                )
                .tag(entry.dayOffset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: dayAreaHeight)
    }

    // MARK: Chargement et écriture

    /// `hasLoaded` n'affiche aucun écran de chargement : il garde seulement
    /// l'écriture, pour ne pas écraser le programme avant de l'avoir lu
    /// (EnhancedPlanScreen lignes 66-91).
    private func loadProgramIfNeeded() {
        guard !hasLoaded else { return }
        let key = accountKey
        if let stored = PlanStorage.loadTasks(accountKey: key) { tasks = stored }
        if let stored = PlanStorage.loadSchedule(accountKey: key) { schedule = stored }
        if let stored = PlanStorage.loadOllamaSettings(accountKey: key) { ollamaSettings = stored }
        hasLoaded = true
    }

    private func refreshProgramIfNeeded() {
        let fresh = PlanDateEngine.programDays()
        if days.count != fresh.count || days.first?.dateKey != fresh.first?.dateKey {
            days = fresh
        }
        if selectedDayOffset >= days.count { selectedDayOffset = max(0, days.count - 1) }
    }

    func persistTasks(_ value: [PlanTask]) {
        guard hasLoaded else { return }
        PlanStorage.saveTasks(value, accountKey: accountKey)
    }
}

// MARK: - Bandeau

/// Bandeau de retour, motif `successBanner` / `scheduleHint` de la source
/// (fond `primaryLight` dans les deux cas, `accentLight` valant ce même gris).
struct PlanBanner: View {
    enum Tone {
        case info
        case warning
        case success
    }

    let tone: Tone
    /// Nom Ionicons exact de la source (`warning-outline`, `checkmark-circle`).
    let icon: String?
    var iconSize: CGFloat = 18
    let text: String
    var showsSpinner: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if showsSpinner {
                ProgressView()
                    .scaleEffect(0.8)
            } else if let icon {
                IonIcon(name: icon, size: iconSize, color: Theme.ink)
            }
            Text(text)
                // Typo par ton : le bandeau d'avertissement reprend le style du
                // rappel horaires (10 / 600), les bandeaux info et succès leur
                // propre style (11 / 800) — `scheduleHintText` / `successText`.
                .font(.system(
                    size: tone == .warning ? 10 : 11,
                    weight: tone == .warning ? .semibold : .heavy
                ))
                .foregroundStyle(tone == .warning ? Theme.inkSoft : Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMedium))
        .padding(.horizontal, 20)
        // `marginBottom` de la source : 4 pour info/succès (`successBanner`),
        // 12 pour l'avertissement (`scheduleHint`).
        .padding(.bottom, tone == .warning ? 12 : 4)
    }
}
