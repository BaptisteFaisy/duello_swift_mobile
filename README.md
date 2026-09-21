# Duello pour iOS — version SwiftUI native

Port natif SwiftUI de l'application **Duello** (app Expo/React Native hébergée
en production sur le VPS Azure `duello-prod-vm`). Cette version iOS parle au
même backend que l'application officielle :

```
https://duello-api-relay.duello.workers.dev/api
```

## Contenu de la version 1

| Onglet | Écran | Source Expo portée |
| --- | --- | --- |
| Accueil | Bienvenue (fond noir, logo, « Créer un compte » / « Me connecter », **Google**) | `src/screens/WelcomeScreen.tsx` |
| — | Connexion / inscription e-mail + mot de passe | `src/utils/serverSession.ts` (`/auth/password/login`, `/auth/password/register`) |
| — | Connexion Google native (`POST /auth/google`) | `src/components/GoogleAuthButton.native.tsx`, `src/utils/googleAuth.ts`, `src/utils/googleIdentity.ts` |
| Mon compte | Profil, parcours (filière, année, spécialité, prépa), objectif, déconnexion | `src/screens/AccountScreen.tsx` |
| Entraînement | Matières du parcours + programme complet en chapitres | `src/screens/SubjectsScreen.tsx`, `src/data/tracks.ts`, `src/data/ecgMathsProgram.ts` |
| Défis | File d'attente d'appariement, défi trouvé, **joueur de défi complet**, classement matière, XP hebdo | `src/screens/ChallengesScreen.tsx`, `src/utils/matchmaking.ts`, `src/utils/duelJudge.ts`, `src/utils/socialApi.ts` |

## Poursuite du portage (v2)

Deuxième vague : première configuration, messages, suivi de progression et
écrans annexes du compte.

| Écran | Contenu | Source Expo portée |
| --- | --- | --- |
| Première configuration | Après inscription, choix **année → filière → option → récapitulatif** | `src/screens/OnboardingScreen.tsx`, `src/utils/onboardingSteps.ts`, `src/utils/academicPath.ts`, `src/data/tracks.ts` |
| Messages | Onglets **Direct** (conversations, fil de bulles, composeur) et **Forum** (sujets, réponses) | `src/screens/MessagesScreen.tsx` |
| Progression | Store local d'activité/maîtrise/ELO + vue par matière (Exercices / Colles / Défis / Heures) | `src/screens/EnhancedProgressScreen.tsx`, `src/utils/activity.ts`, `src/utils/exerciseProgress.ts`, `src/utils/subjectElo.ts` |
| Compte — écrans annexes | Confidentialité, CGU, avis, utilisateurs bloqués, parcours détaillé, mot de passe oublié | `src/screens/{PrivacyPolicyScreen,TermsOfUseScreen,FeedbackScreen,BlockedUsersScreen,AccountTrackScreen,ForgotPasswordScreen,PasswordResetScreen}.tsx` |

L'onboarding s'affiche à la racine tant que le profil n'a ni année ni filière
(`RootView`). Les écrans annexes s'ouvrent en **feuille** depuis « Mon compte ».
Le `ProgressStore` (`final class`, persistance `UserDefaults` + JSON, comme
`SessionStore`) est injecté dans l'environnement à la racine ; ses méthodes
`recordExercise` / `recordDuel` sont prêtes à être branchées sur le joueur de
défi et l'entraînement.

Programmes embarqués : **ECG** (maths approfondies/appliquées, ESH, HGG,
Lettres, Philosophie, Anglais, LV2), **MPSI**, **MP**, **PSI** — avec les
identifiants de chapitres identiques à ceux de l'app Expo (même clé
d'appariement côté serveur).

Comme dans l'app Expo, les **défis ne portent que sur les mathématiques**
(`getChallengeTrackSubjects` filtre `subject.id === 'maths'`), et la file
n'apparie que les filières **ECG** et **MPSI** (les seules pourvues de banques
d'exercices côté serveur). La banque d'exercices annoncée au serveur
(`DuelloExerciseCatalog.swift`) est extraite **des banques servies par le
backend lui-même** (`GET /content/manifest.json` puis fichiers de chapitres) :
chaque identifiant y correspond à un énoncé réellement téléchargeable — la
même vérité terrain que `challengeExercisesFor` (Expo), qui ne met en pool
que les exercices à énoncé retranscrit. Le corps de la requête `POST /queue`
est borné à 58 Ko : le serveur refuse toute requête de plus de 64 Ko
(`MAX_BODY_BYTES`, vérifié en production) avant même la validation ; la
sous-banque annoncée est tronquée de façon déterministe et identique chez
tous les joueurs, pour que l'intersection reste large.

Le **joueur de défi** (`ChallengePlayerView.swift`) reprend le flux exact de
l'app Expo : l'énoncé réel est téléchargé depuis l'API de contenu servie
(`GET /content/manifest.json` puis le fichier de chapitre, comme
`contentBootstrap.ts`), converti LaTeX → Unicode par le port de
`latexToUnicode.ts`, la copie se rédige sous chrono partagé (`startedAt` du
match, remise automatique à la fin du temps), puis `duelJudge.ts` est porté :
garde-fou « énoncé recopié » (`duelCopyPolicy.ts`), notation IA via le relais
(`POST /relay`, action `grade-duel-copy`, même quota `duel:<matchId>`),
attente de la copie adverse avec tolérance aux hoquets réseau, forfait à la
date limite, et refus de comparer deux barèmes différents. Le barème local
déterministe (`scoreProduction`) sert de second rideau hors ligne, comme côté
Expo — c'est le parcours réellement suivi quand le relais est en panne
(constaté : `POST /relay` peut répondre 502 côté Cloudflare ; les copies partent
alors `graded: false` et le défi n'est pas compté pour la cote).

Diagnostic de la panne du 2026-09-04 (jour des tests) : le correcteur du VPS
(`/opt/duello/app/server`, service `duello-relay`) s'appuie sur des sessions
web ChatGPT/Claude, et les trois comptes configurés étaient expirés
(`nouveau-compte-codex`, `baptiste-faisy-gmail-com`, `nouveau-compte-codex-2` →
« session ChatGPT expirée » → « aucun correcteur de défi configuré »). Le relais
renvoie son propre 502 JSON (« correction automatique indisponible »), que le
tunnel cloudflared transforme en 502 HTML côté client. Panne purement serveur :
ni Expo ni l'app Swift ne sont en cause, et les deux retombent sur le barème
local de la même façon. Réparation : re-synchroniser les sessions web des trois
comptes sur le VPS. L'enveloppe
`settled` du serveur ne porte d'ailleurs jamais de champs Elo :
`before/after/delta/outcome` n'existent pas dans `challenge-queue.mjs`, et
l'écran de verdict n'affiche de cote que si le serveur en envoie un jour.

Palette et typographie reprises de `src/theme.ts` : interface encre sur blanc,
serif pour la lecture, verts réservés à la maîtrise.

## Ouvrir et compiler sur le Mac

1. Copier le dossier `duello_swift_app` sur le Mac (AirDrop, clé USB, iCloud…).
2. Installer **Xcode 15+** depuis l'App Store.
3. Ouvrir `Duello.xcodeproj` (double-clic).
4. Choisir un simulateur **iPhone** (iOS 16.0+) puis ▶︎ Run.

### Sur un iPhone réel

- Brancher l'iPhone, le sélectionner comme destination dans Xcode ;
- Dans *Signing & Capabilities*, choisir ton équipe (un Apple ID gratuit
  suffit) — le bundle est `com.prepapp.mobile.swift` ;
- Sur l'iPhone : Réglages → Général → VPN et gestion des appareils → faire
  confiance au certificat de développeur ;
- ▶︎ Run : l'application s'installe sur le téléphone.

## Comptes et session

- La session (`dus_…`) est stockée dans le **trousseau** iOS, comme côté Expo
  (`expo-secure-store`). Elle est réutilisée au lancement tant qu'elle est
  valide (30 jours côté serveur).
- Un compte créé dans l'app iOS est le même compte que sur Android/Web :
  l'identifiant public (`member-<fnv1a>`) est calculé exactement comme dans
  `publicProfileId` de `socialApi.ts`.

## Limites connues de la v1

- Clavier mathématique dédié, dictée et corrections détaillées par question :
  les réponses se rédigent en texte Unicode (même convention que l'app Expo,
  qui parle aussi Unicode dans ses champs de texte).
- Face ID non câblé.
- Premium, annales et notifications push : non inclus.
- **Messages** : l'écran est porté avec ses **données de démonstration**
  locales (comme `MessagesScreen.tsx`, qui n'appelle aucun backend) ; aucun
  envoi réel de message.
- **Progression** : les écrans sont en place mais l'activité n'est pas encore
  enregistrée automatiquement — il reste à appeler `ProgressStore.recordExercise`
  et `recordDuel` depuis l'entraînement et le joueur de défi.
- **Mot de passe oublié / avis** : confirmations locales, sans appel réseau.

## Connexion Google

Même contrat que l'app Expo : le SDK `GoogleSignIn` (dépendance SPM
`GoogleSignIn-iOS`, résolue automatiquement par Xcode à la première
compilation) fournit le jeton, qui part vers `POST /auth/google` avec
`deviceId` (`ios:<uuid>`) — jamais décodé localement. Le serveur renvoie
`{identity, session}` : l'identité est revalidée strictement (miroir de
`parseGoogleIdentity`), le profil est prérempli comme
`profileWithGoogleIdentity` (prénom en affichage, e-mail Google, profil
public) et la session `dus_…` est stockée au trousseau comme les autres.

Identifiants OAuth de l'app Expo, déjà câblés :

- client iOS : `283336474401-hbo36u49j767lqknahakr2937mfa6amn`
- client serveur (audience web) : `283336474401-vnrbe290uqqr308drg290f6p86kji6b4`
- schéma d'URL de retour (`Duello/Info.plist`) :
  `com.googleusercontent.apps.283336474401-hbo36u49j767lqknahakr2937mfa6amn`

Sur un iPhone réel, la fenêtre de connexion passe par le navigateur Google
et revient à l'app par ce schéma ; rien d'autre à configurer dans Xcode
(l'`Info.plist` partiel est fusionné avec celui généré par le projet).

## Structure

```
duello_swift_app/
├── Duello.xcodeproj/
└── Duello/
    ├── DuelloApp.swift        Point d'entrée, routage racine
    ├── Theme.swift            Palette/mesures (src/theme.ts)
    ├── Models.swift           Types profil, classements, défis
    ├── Programs.swift         Programmes ECG/MPSI/MP/PSI embarqués
    ├── DuelloAPI.swift        Client HTTP (socialApi.ts, serverSession.ts),
                                 contenu servi, relais de correction et /auth/google
    ├── SessionStore.swift     Session trousseau + compte local
    ├── GoogleAuth.swift       Connexion Google (GoogleAuthButton.native.tsx,
                                 googleAuth.ts, googleIdentity.ts)
    ├── Info.plist             Schéma d'URL de retour Google
    ├── DuelloExerciseCatalog.swift  Banque d'exercices réels pour les défis
                                     (générée depuis les résumés Expo)
    ├── LatexToUnicode.swift   LaTeX → Unicode (latexToUnicode.ts)
    ├── DuelJudge.swift        Barèmes, garde-fous, notation et verdict
                                 (duel.ts, duelCopyPolicy.ts, duelJudge.ts)
    ├── MainTabView.swift      Onglets Mon compte / Entraînement / Défis
    ├── WelcomeView.swift      Accueil + connexion/inscription + bouton Google
    ├── OnboardingView.swift   Première configuration (année, filière, option)
    ├── AccountView.swift      Mon compte (+ menu vers les écrans annexes)
    ├── AccountDetailViews.swift  Légal, avis, comptes bloqués, parcours, mot de passe
    ├── MessagesView.swift     Messages (Direct + Forum)
    ├── ProgressStore.swift    Store local d'activité, maîtrise et ELO
    ├── ProgressView.swift     Progression par matière
    ├── TrainingView.swift     Entraînement (matières, chapitres)
    ├── ChallengesView.swift   Défis (file, match, classements)
    └── ChallengePlayerView.swift  Joueur de défi (énoncé, copie, verdict)
```

Le projet Xcode liste ses sources explicitement ; après avoir ajouté un
`.swift` dans `Duello/`, lancer `python3 scripts/sync_xcode_sources.py` pour
l'inscrire au `project.pbxproj`.
