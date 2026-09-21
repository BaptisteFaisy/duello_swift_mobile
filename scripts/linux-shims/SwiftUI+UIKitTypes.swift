// Shim SwiftUI — types UIKit référencés par la surface SwiftUI.
// NE FAIT PAS PARTIE DE L'APP.
//
// `UIKeyboardType` et `UITextContentType` appartiennent à UIKit : le shim
// `scripts/linux-shims/UIKit.swift` ne les déclare pas encore. Ils sont donc
// posés ici, dans le module `SwiftUI`, uniquement parce que les signatures de
// `.keyboardType(_:)` et `.textContentType(_:)` en ont besoin. Quand le shim
// UIKit les déclarera, ce fichier deviendra inutile (et devrait être supprimé
// pour éviter une ambiguïté dans les fichiers qui importent les deux modules).

import Foundation

public enum UIKeyboardType: Int, Sendable {
    case `default`
    case asciiCapable
    case numbersAndPunctuation
    case URL
    case numberPad
    case phonePad
    case namePhonePad
    case emailAddress
    case decimalPad
    case twitter
    case webSearch
    case asciiCapableNumberPad
}

public struct UITextContentType: Hashable, Sendable, RawRepresentable {
    public let rawValue: String
    public nonisolated init(rawValue: String) { self.rawValue = rawValue }

    public static let name = UITextContentType(rawValue: "name")
    public static let namePrefix = UITextContentType(rawValue: "namePrefix")
    public static let givenName = UITextContentType(rawValue: "givenName")
    public static let middleName = UITextContentType(rawValue: "middleName")
    public static let familyName = UITextContentType(rawValue: "familyName")
    public static let nameSuffix = UITextContentType(rawValue: "nameSuffix")
    public static let nickname = UITextContentType(rawValue: "nickname")
    public static let jobTitle = UITextContentType(rawValue: "jobTitle")
    public static let organizationName = UITextContentType(rawValue: "organizationName")
    public static let location = UITextContentType(rawValue: "location")
    public static let fullStreetAddress = UITextContentType(rawValue: "fullStreetAddress")
    public static let streetAddressLine1 = UITextContentType(rawValue: "streetAddressLine1")
    public static let streetAddressLine2 = UITextContentType(rawValue: "streetAddressLine2")
    public static let city = UITextContentType(rawValue: "addressCity")
    public static let state = UITextContentType(rawValue: "addressState")
    public static let postalCode = UITextContentType(rawValue: "postalCode")
    public static let countryName = UITextContentType(rawValue: "countryName")
    public static let sublocality = UITextContentType(rawValue: "sublocality")
    public static let countryCode = UITextContentType(rawValue: "countryCode")
    public static let postalAddress = UITextContentType(rawValue: "postalAddress")
    public static let telephoneNumber = UITextContentType(rawValue: "telephoneNumber")
    public static let emailAddress = UITextContentType(rawValue: "emailAddress")
    public static let URL = UITextContentType(rawValue: "URL")
    public static let creditCardNumber = UITextContentType(rawValue: "creditCardNumber")
    public static let username = UITextContentType(rawValue: "username")
    public static let password = UITextContentType(rawValue: "password")
    public static let newPassword = UITextContentType(rawValue: "newPassword")
    public static let oneTimeCode = UITextContentType(rawValue: "oneTimeCode")
    public static let birthdate = UITextContentType(rawValue: "birthdate")
    public static let birthdateDay = UITextContentType(rawValue: "birthdateDay")
    public static let birthdateMonth = UITextContentType(rawValue: "birthdateMonth")
    public static let birthdateYear = UITextContentType(rawValue: "birthdateYear")
    public static let dateTime = UITextContentType(rawValue: "dateTime")
    public static let flightNumber = UITextContentType(rawValue: "flightNumber")
    public static let shipmentTrackingNumber = UITextContentType(rawValue: "shipmentTrackingNumber")
}
