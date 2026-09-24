// Port de src/utils/chapterNotebook.ts (RN) — carnet de notes d'un chapitre :
// astuces typées, colles et DS.
//
// Fichiers source Expo portés (libellés repris mot pour mot) :
//   - `src/utils/chapterNotebook.ts` — `ChapterTipType`, `ChapterTip`,
//     `ChapterNotebook`, `EMPTY_CHAPTER_NOTEBOOK`, `parseChapterNotebook`,
//     `serializeChapterNotebook`, `chapterTipTypeKey` ;
//   - `src/storage/keys.ts` — `chapterNotebookStorageKey(chapterId)` et
//     `ACCOUNT_STORAGE_PREFIXES.chapterNotebook`
//     (`prepapp-chapter-notebook:v1:<chapitre>`).
//
// Limite assumée (24/09/2026) : la source lit/écrit via `AccountStorage`
// (asynchrone, cloisonné par compte). Le portage conserve la clé logique
// (`préfixe + chapterId`) dans `UserDefaults`, comme `CollStorage` : lecture et
// écriture synchrones, portée = appareil.
//
// Cible : iOS 16, aucune dépendance externe (CoreFoundation est un framework
// système, utilisé seulement pour distinguer un vrai booléen JSON d'un nombre).
//
import Foundation
import CoreFoundation

// MARK: - Modèle

/// `ChapterTipType` : une famille d'astuces (« Calcul », « Méthode »…).
struct ChapterTipType: Equatable {
    let key: String
    let label: String
}

/// `ChapterTip` : une astuce, éventuellement rangée dans une famille.
///
/// `createdAt` est un nombre de millisecondes, comme la source (`Date.now()`),
/// et non une `Date` : le modèle reste aligné sur le JSON échangé.
struct ChapterTip: Equatable {
    let id: String
    let text: String
    let typeKey: String?
    let createdAt: Double
}

/// `ChapterNotebook` : les trois carnets d'un chapitre.
struct ChapterNotebook: Equatable {
    var tips: [ChapterTip]
    var tipTypes: [ChapterTipType]
    var colles: String
    var ds: String

    /// `EMPTY_CHAPTER_NOTEBOOK` : carnet vide, jamais partagé (valeur).
    static let empty = ChapterNotebook(tips: [], tipTypes: [], colles: "", ds: "")
}

// MARK: - Codec

/// `parseChapterNotebook` / `serializeChapterNotebook` / `chapterTipTypeKey`.
///
/// Une valeur corrompue ne doit jamais empêcher l'ouverture d'un chapitre : le
/// parseur est tolérant entrée par entrée, comme `HecJourneyTimelineCodec`.
enum ChapterNotebookCodec {
    /// `parseChapterNotebook` : enveloppe illisible → carnet vide.
    static func parseChapterNotebook(_ raw: String?) -> ChapterNotebook {
        guard let raw,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any]
        else { return .empty }

        let tipTypes = parseTipTypes(payload["tipTypes"])
        let knownTypes = Set(tipTypes.map { $0.key })
        return ChapterNotebook(
            tips: parseTips(payload["tips"], knownTypes: knownTypes),
            tipTypes: tipTypes,
            colles: payload["colles"] as? String ?? "",
            ds: payload["ds"] as? String ?? ""
        )
    }

    /// `serializeChapterNotebook` : l'enveloppe complète. `typeKey` nul devient
    /// `null` ; `createdAt` reste un nombre.
    static func serializeChapterNotebook(_ notebook: ChapterNotebook) -> String {
        let tips: [[String: Any]] = notebook.tips.map { tip in
            [
                "id": tip.id,
                "text": tip.text,
                "typeKey": tip.typeKey ?? NSNull(),
                "createdAt": tip.createdAt,
            ]
        }
        let tipTypes: [[String: Any]] = notebook.tipTypes.map { ["key": $0.key, "label": $0.label] }
        let payload: [String: Any] = [
            "tips": tips,
            "tipTypes": tipTypes,
            "colles": notebook.colles,
            "ds": notebook.ds,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8)
        else { return "" }
        return text
    }

    /// `chapterTipTypeKey` : clé stable dérivée du libellé, translittéré en
    /// ASCII (NFD, marques retirées, minuscules), ponctuation réduite à `-`.
    /// Un libellé vide ou purement ponctuel retombe sur le rang fourni.
    static func chapterTipTypeKey(label: String, fallback: Int) -> String {
        var lowered = ""
        for scalar in label.decomposedStringWithCanonicalMapping.unicodeScalars
        where !(0x0300...0x036F).contains(scalar.value) {
            lowered.unicodeScalars.append(scalar)
        }
        let slug = slugify(lowered.lowercased())
        return "custom-\(slug.isEmpty ? String(fallback) : slug)"
    }

    // MARK: Détails

    /// `parseTipTypes` : `key` et `label` non vides, sinon l'entrée est écartée.
    private static func parseTipTypes(_ value: Any?) -> [ChapterTipType] {
        guard let array = value as? [Any] else { return [] }
        return array.compactMap { item in
            guard let dict = item as? [String: Any],
                  let key = dict["key"] as? String, !isBlank(key),
                  let label = dict["label"] as? String, !isBlank(label)
            else { return nil }
            return ChapterTipType(key: key, label: label)
        }
    }

    /// `parseTips` : une chaîne (ancien carnet) devient une astuce « legacy » ;
    /// sinon chaque astuce est validée et son type ramené à un type connu.
    private static func parseTips(_ value: Any?, knownTypes: Set<String>) -> [ChapterTip] {
        if let string = value as? String {
            return isBlank(string)
                ? []
                : [ChapterTip(id: "legacy-tip", text: string, typeKey: nil, createdAt: 0)]
        }
        guard let array = value as? [Any] else { return [] }
        return array.compactMap { item -> ChapterTip? in
            guard let dict = item as? [String: Any],
                  let id = dict["id"] as? String, !isBlank(id),
                  let text = dict["text"] as? String, !isBlank(text),
                  let rawType = dict["typeKey"],
                  rawType is NSNull || rawType is String,
                  let createdAtValue = dict["createdAt"],
                  let number = createdAtValue as? NSNumber, !isJSONBoolean(number)
            else { return nil }
            let createdAt = number.doubleValue
            guard createdAt.isFinite else { return nil }
            let candidate = rawType as? String
            let typeKey = candidate.flatMap { knownTypes.contains($0) ? $0 : nil }
            return ChapterTip(id: id, text: text, typeKey: typeKey, createdAt: createdAt)
        }
    }

    /// `[^a-z0-9]+` → `-`, puis `^-|-$` retirés. Seuls les scalaires ASCII
    /// alphanumériques sont conservés (comme la source après minuscules).
    private static func slugify(_ text: String) -> String {
        var slug = ""
        var pendingDash = false
        for scalar in text.unicodeScalars {
            if isAsciiAlphanumeric(scalar) {
                if pendingDash && !slug.isEmpty { slug.append("-") }
                pendingDash = false
                slug.unicodeScalars.append(scalar)
            } else {
                pendingDash = true
            }
        }
        return slug
    }

    private static func isAsciiAlphanumeric(_ scalar: Unicode.Scalar) -> Bool {
        (scalar.value >= 97 && scalar.value <= 122) || (scalar.value >= 48 && scalar.value <= 57)
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Vrai si `number` est un booléen JSON (`true`/`false`) et non un nombre :
    /// `NSNumber(1)` répondrait `true` à `is Bool`, on interroge donc le type
    /// CoreFoundation sous-jacent.
    private static func isJSONBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}
