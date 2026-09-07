import Foundation

/// Tiny runtime EN/FR switch driven by the system locale, so the UI follows
/// macOS language settings even though the app ships a single localization.
enum L10n {
    static var isFrench: Bool {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("fr") ?? false
    }

    static func pick(_ en: String, _ fr: String) -> String {
        isFrench ? fr : en
    }

    /// Locale used for currency/number formatting, matching the UI language.
    static var formattingLocale: Locale {
        isFrench ? Locale(identifier: "fr_FR") : Locale(identifier: "en_US")
    }
}
