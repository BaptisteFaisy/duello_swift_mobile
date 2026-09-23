//
//  ImageCache.swift
//  Duello
//
//  Cache d'images partagé : `NSCache<NSString, UIImage>` pour les images déjà
//  décodées, décodage **hors main thread** (`Task.detached`), et deux vues de
//  remplacement — `CachedRemoteImage` (URLSession + cache, à la place
//  d'`AsyncImage`) et `CachedImage` (octets en mémoire ou fichier local).
//
//  Motif : `parite-gap/5-perf.md` §2 — au scroll, `AsyncImage` re-télécharge et
//  re-décode sur le main thread, et les helpers `UIImage(data:)` /
//  `UIImage(contentsOfFile:)` recalculent une image à chaque évaluation de
//  `body`. Ici, une image n'est décodée qu'une fois, puis servie depuis le
//  cache ; les cellules qui apparaissent à nouveau n'ont plus aucun décodage.
//
//  Cible : iOS 16, aucune API iOS 17.
//
import Foundation
import SwiftUI
import UIKit

// MARK: - Source d'image

/// Source d'une image décodée par le cache.
enum CachedImageSource {
    /// Octets en mémoire (photo reçue, miniature JPEG base64 décodée).
    /// `key` doit identifier le contenu (URI, identifiant de page…).
    case data(Data, key: String)
    /// Fichier local : le chemin du fichier, tel qu'attendu par
    /// `UIImage(contentsOfFile:)`.
    case file(String)
    /// Adresse distante (`http`/`https`).
    case remote(URL)

    /// Clé de cache, peu coûteuse à comparer : elle sert aussi d'identité à
    /// `.task(id:)` (comparer des `Data` bruts serait un coût par rendu).
    var cacheKey: String {
        switch self {
        case .data(_, let key): return key
        case .file(let path): return "file:" + path
        case .remote(let url): return "url:" + url.absoluteString
        }
    }
}

// MARK: - Cache

/// Cache d'images décodées, partagé par toute l'application.
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    /// Nombre d'images conservées ; l'éviction LRU est gérée par `NSCache`.
    private static let countLimit = 240
    /// Plafond mémoire approximatif du cache (96 Mio).
    private static let costLimit = 96 * 1024 * 1024

    private let images = NSCache<NSString, UIImage>()

    /// Session dédiée : le cache HTTP d'`URLSession` (mémoire + disque) évite le
    /// re-téléchargement d'une image distante déjà vue.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024,
                                          diskCapacity: 128 * 1024 * 1024,
                                          diskPath: nil)
        return URLSession(configuration: configuration)
    }()

    private init() {
        images.countLimit = Self.countLimit
        images.totalCostLimit = Self.costLimit
    }

    /// Image déjà décodée, ou `nil`. Lecture synchrone sans travail lourd :
    /// utilisable dans un `body`.
    func image(for key: String) -> UIImage? {
        images.object(forKey: key as NSString)
    }

    /// Mémorise une image décodée.
    func store(_ image: UIImage, key: String) {
        images.setObject(image, forKey: key as NSString, cost: image.cacheCost)
    }

    /// Sonde le cache puis, à défaut, décode `data` dans une `Task.detached`
    /// (publication du résultat sur le main thread). Renvoie immédiatement
    /// l'image si elle est déjà en cache, sinon `nil` : la vue appelante se
    /// rafraîchit via `CachedImage`.
    @discardableResult
    func load(_ data: Data, key: String) -> UIImage? {
        if let cached = image(for: key) { return cached }
        Task.detached(priority: .userInitiated) { [weak self] in
            let decoded = UIImage(data: data)
            await MainActor.run {
                if let decoded { self?.store(decoded, key: key) }
            }
        }
        return nil
    }

    /// Décode des octets hors main thread, une seule fois, puis mémorise.
    func decoded(_ data: Data, key: String) async -> UIImage? {
        if let cached = image(for: key) { return cached }
        let decoded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            UIImage(data: data)
        }.value
        if let decoded { store(decoded, key: key) }
        return decoded
    }

    /// Lit et décode un fichier local hors main thread.
    func decodedFile(_ path: String, key: String) async -> UIImage? {
        if let cached = image(for: key) { return cached }
        let decoded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = FileManager.default.contents(atPath: path) else { return nil }
            return UIImage(data: data)
        }.value
        if let decoded { store(decoded, key: key) }
        return decoded
    }

    /// Charge une adresse distante (`URLSession`) puis la décode hors main
    /// thread.
    func decodedRemote(_ url: URL, key: String) async -> UIImage? {
        if let cached = image(for: key) { return cached }
        guard let (data, _) = try? await Self.session.data(from: url) else { return nil }
        let decoded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            UIImage(data: data)
        }.value
        if let decoded { store(decoded, key: key) }
        return decoded
    }

    /// Point d'entrée unique : cache d'abord, puis décodage selon la source.
    func image(for source: CachedImageSource) async -> UIImage? {
        switch source {
        case .data(let data, let key):
            return await decoded(data, key: key)
        case .file(let path):
            return await decodedFile(path, key: source.cacheKey)
        case .remote(let url):
            return await decodedRemote(url, key: source.cacheKey)
        }
    }

    /// Clé stable et courte dérivée d'une chaîne (une URI `data:` base64 peut
    /// faire plusieurs milliers de caractères : on ne la garde pas en clé).
    /// FNV-1a 64 bits, sans dépendance externe.
    static func key(for string: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return "s:" + String(hash, radix: 16)
    }
}

private extension UIImage {
    /// Coût mémoire approché d'une image : octets du bitmap décodé.
    var cacheCost: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

// MARK: - Vues

/// Remplace `AsyncImage` : même forme d'appel (`content` / `placeholder`), mais
/// servi par `ImageCache` — décodage hors main thread, mémoire + cache HTTP.
struct CachedRemoteImage<Content: View, Placeholder: View>: View {
    let url: URL?

    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var image: UIImage?

    init(url: URL?,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url = url else {
                image = nil
                return
            }
            let key = "url:" + url.absoluteString
            if let cached = ImageCache.shared.image(for: key) {
                image = cached
            } else {
                image = await ImageCache.shared.decodedRemote(url, key: key)
            }
        }
    }
}

/// Image locale (octets en mémoire ou fichier) décodée **une seule fois** hors
/// main thread, via `ImageCache`.
struct CachedImage<Content: View, Placeholder: View>: View {
    let source: CachedImageSource

    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var image: UIImage?

    init(_ source: CachedImageSource,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.source = source
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: source.cacheKey) {
            let key = source.cacheKey
            if let cached = ImageCache.shared.image(for: key) {
                image = cached
            } else {
                image = await ImageCache.shared.image(for: source)
            }
        }
    }
}
