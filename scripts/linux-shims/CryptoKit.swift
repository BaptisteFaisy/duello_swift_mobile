// Shim de vérification Linux — NE FAIT PAS PARTIE DE L'APP.
//
// `CryptoKit` n'existe pas sous Linux. Un seul appelant,
// `OfflContentHash.swift` : `SHA256.hash(data:)` puis parcours de l'empreinte
// octet par octet (`map { String(format: "%02x", $0) }`).
//
// `SHA256Digest` est donc une `Sequence` d'`UInt8` — c'est ce que le vrai type
// fournit, et c'est tout ce dont le code se sert.
import Foundation

public struct SHA256Digest: Sequence, Hashable, Sendable {
    public typealias Element = UInt8

    private let bytes: [UInt8]

    public init() { self.bytes = [] }

    public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }

    public var count: Int { bytes.count }

    public subscript(position: Int) -> UInt8 { bytes[position] }
}

public enum SHA256 {
    public static func hash<D: DataProtocol>(data: D) -> SHA256Digest { SHA256Digest() }
}
