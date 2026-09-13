//===----------------------------------------------------------------------===//
//
// WINCATALYST FORK ADDITION -- not upstream swift-foundation.
//
// "Which language does this user read, and how do they want numbers written?",
// answered for the off-Darwin arms. `LocaleCache`'s non-Darwin `preferences()`
// used to be three hardcoded lines (`prefs.locale = "en_001"`), so
// `Locale.current` was `en_001` on every machine regardless of the host, the
// environment or anything else -- which meant a French user got French strings
// (CFBundle follows the host) and American number, date, currency and
// measurement formatting from every `FormatStyle` and every formatter that does
// not carry an explicit locale. Half-translated, with no way for an app to fix
// it: `LocaleCache`, `LocalePreferences` and `resetCurrent(to:)` are all
// `internal`, so nothing outside this module could move it.
//
// ⚠️⚠️ THIS IS THE SECOND IMPLEMENTATION OF ONE FACT, AND IT IS DELIBERATE.
// WinCatalyst already answers this question in C++, at
// `Frameworks/include/Platform/PlatformLocale.h` + `Frameworks/Platform/`, which
// is what CFBundle, `NSUserDefaults` and `+[NSLocale preferredLanguages]` are
// fed from. This file cannot call it: `FoundationEssentials` sits BELOW
// `platform.lib` in the build graph and linking upward is not available to it.
//
// The duplication is contained by GATING THE AGREEMENT rather than hoping for
// it -- `examples/swiftpm-resourcetest` asserts that `Locale.current` and
// `+[NSLocale preferredLanguages]` name the same language, on every arm and on
// every language leg. If the two implementations ever drift, that gate goes red
// naming both values. ⚠️ So any change here belongs in BOTH places:
//
//     Frameworks/Platform/PlatformLocale_Common.cpp      the overrides + normalizer
//     Frameworks/Platform/posix/PlatformLocale_Posix.cpp the POSIX/Android chain
//     Frameworks/Platform/win32/PlatformLocale_Win32.cpp the Win32 query
//
// Every rule below is transcribed from those three files, and the comments say
// which. The behaviour they define, in one paragraph: two environment overrides
// (`WINCAT_LANGUAGES`, `WINCAT_LOCALE`) that win outright when PRESENT, even
// when they name no language; otherwise the host's own answer; everything
// normalized to BCP-47 with hyphens; `C` and `POSIX` dropped rather than
// translated to English, because they name a codeset, not a language.
//
//===----------------------------------------------------------------------===//

internal import _FoundationCShims

#if canImport(Darwin)
import Darwin
#elseif canImport(WinSDK)
import WinSDK
#elseif canImport(Android)
@preconcurrency import Android
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#endif

/// The host's answer to the two locale questions, off Darwin.
///
/// Nothing here is cached: `LocaleCache` caches, and caching in two places would
/// make the environment overrides untestable from inside one process -- the same
/// rule `PlatformLocale.h` states for the C++ seam.
enum _WinCatalystHostLocale {

    // MARK: - Normalization (PlatformLocale_Common.cpp's NormalizeTag)

    /// `fr_FR.UTF-8@euro` -> `fr-FR`; `zh_Hans_CN` -> `zh-Hans-CN`; `C` -> nil.
    ///
    /// ⚠️ Not cosmetic. A POSIX host answers `fr_FR.UTF-8@euro`, Windows answers
    /// `fr-FR`, and a hand-typed override may be either; a tag that reached a
    /// matcher with a codeset suffix would simply MISS, silently.
    static func normalize(_ raw: String) -> String? {
        // Strip the POSIX codeset (`.UTF-8`) and modifier (`@euro`) suffixes.
        var tag = raw
        if let cut = tag.firstIndex(where: { $0 == "." || $0 == "@" }) {
            tag = String(tag[tag.startIndex..<cut])
        }
        tag = tag.trimmingASCIIWhitespace()
        if tag.isEmpty { return nil }
        tag = tag.replacing("_", with: "-")
        if tag.isEmpty { return nil }
        // ⚠️ `C` and `POSIX` are DROPPED, not translated to `en`. They name a
        // codeset and collation, not a human language, and a login that has them
        // is saying "I did not choose" -- which this seam spells "no answer, have
        // a fallback". Mapping them to English would make an unconfigured account
        // indistinguishable from a user who really picked English.
        switch tag {
        case "C", "c", "POSIX", "posix": return nil
        default: break
        }
        // Lowercase the language subtag only; BCP-47 canonical case for the rest
        // is the canonicalizer's job, but every matcher keys on this one first.
        if let dash = tag.firstIndex(of: "-") {
            return tag[tag.startIndex..<dash].lowercased() + tag[dash...]
        }
        return tag.lowercased()
    }

    /// Normalize a list and drop repeats, preserving order.
    ///
    /// ⚠️ ONE pass for the override and the host alike. In the C++ seam the
    /// override path once skipped de-duplication, so `WINCAT_LANGUAGES=fr,fr`
    /// produced two entries where the identical host answer produced one -- a
    /// difference no end-to-end run exercises, because a gate sets the override
    /// and a user has the host.
    static func normalizeList(_ raw: [String]) -> [String] {
        var tags: [String] = []
        for item in raw {
            guard let tag = normalize(item) else { continue }
            // The list is a PREFERENCE ORDER, so a tag repeated later says
            // nothing new. A POSIX host produces these routinely, since LANGUAGE
            // and LANG usually name the same locale.
            if !tags.contains(tag) { tags.append(tag) }
        }
        return tags
    }

    /// Split a human-written override on commas OR colons. POSIX's `LANGUAGE`
    /// uses colons; whoever types `WINCAT_LANGUAGES` will reach for commas.
    static func splitOverride(_ value: String) -> [String] {
        value.split(whereSeparator: { $0 == "," || $0 == ":" }).map(String.init)
    }

    // MARK: - Environment

    static func env(_ name: String) -> String? {
        #if canImport(WinSDK)
        return name.withCString(encodedAs: UTF16.self) { wname in
            let needed = GetEnvironmentVariableW(wname, nil, 0)
            guard needed > 0 else { return nil }
            return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(needed)) { buffer in
                guard GetEnvironmentVariableW(wname, buffer.baseAddress, needed) == needed - 1,
                      let base = buffer.baseAddress else { return nil }
                let value = String(decodingCString: base, as: UTF16.self)
                return value.isEmpty ? nil : value
            }
        }
        #else
        guard let raw = getenv(name) else { return nil }
        let value = String(cString: raw)
        return value.isEmpty ? nil : value
        #endif
    }

    // MARK: - The host query

    #if canImport(Android)
    /// `persist.sys.locale` is what Android's Settings app writes;
    /// `ro.product.locale` is the image default. Both are BCP-47 already.
    ///
    /// Read through bionic's property API rather than JNI, because this is
    /// consulted at start-up, before any Activity has handed us a Configuration.
    static func systemProperty(_ name: String) -> String? {
        withUnsafeTemporaryAllocation(of: CChar.self, capacity: 128) { buffer in
            guard let base = buffer.baseAddress else { return nil }
            let length = name.withCString {
                _wincat_shims_android_system_property($0, base, 128)
            }
            guard length > 0 else { return nil }
            return String(cString: base)
        }
    }
    #endif

    /// The host's preferred UI languages, most-preferred first, in whatever
    /// spelling the platform uses. Normalization happens above, once.
    static func hostPreferredLanguages() -> [String] {
        #if canImport(WinSDK)
        // GetUserPreferredUILanguages(MUI_LANGUAGE_NAME) -> the ordered list, in
        // the same NUL-separated double-NUL-terminated block shape the C++ seam's
        // public contract uses. Falls back to the SYSTEM list, then to
        // GetUserDefaultLocaleName -- which is always answerable, and without
        // which a machine whose UI language was never explicitly chosen answers
        // nothing at all.
        for systemWide in [false, true] {
            var count: ULONG = 0
            var chars: ULONG = 0
            let sized = systemWide
                ? GetSystemPreferredUILanguages(DWORD(MUI_LANGUAGE_NAME), &count, nil, &chars)
                : GetUserPreferredUILanguages(DWORD(MUI_LANGUAGE_NAME), &count, nil, &chars)
            guard sized, chars > 0 else { continue }
            let tags: [String] = withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(chars)) { buffer in
                guard let base = buffer.baseAddress else { return [] }
                let filled = systemWide
                    ? GetSystemPreferredUILanguages(DWORD(MUI_LANGUAGE_NAME), &count, base, &chars)
                    : GetUserPreferredUILanguages(DWORD(MUI_LANGUAGE_NAME), &count, base, &chars)
                guard filled else { return [] }
                var out: [String] = []
                var cursor = base
                while cursor.pointee != 0 {
                    let tag = String(decodingCString: cursor, as: UTF16.self)
                    out.append(tag)
                    cursor += tag.utf16.count + 1
                }
                return out
            }
            if !tags.isEmpty { return tags }
        }
        var name = [WCHAR](repeating: 0, count: Int(LOCALE_NAME_MAX_LENGTH))
        let len = GetUserDefaultLocaleName(&name, Int32(LOCALE_NAME_MAX_LENGTH))
        if len > 0 {
            let tag = String(decodingCString: name, as: UTF16.self)
            if !tag.isEmpty { return [tag] }
        }
        return []
        #else
        var tags: [String] = []
        #if canImport(Android)
        // ⚠️ THE OS SETTING IS THE WHOLE ANSWER ON ANDROID WHEN IT HAS ONE -- the
        // environment is not consulted at all, not even appended behind it. On a
        // desktop `LANG` is something the user chose; on Android it is whatever
        // the zygote happened to inherit, and a stray `LANG=en_US` in it would
        // put English into the preference list of a device whose owner set it to
        // Japanese. A language nobody chose, sitting second in an ordered list,
        // looks exactly like a fallback and is never questioned. (That is not
        // hypothetical: it is the bug the Android arm of the C++ seam shipped
        // with, and its own gate caught it on the first run.)
        for property in ["persist.sys.locale", "ro.product.locale"] {
            if let value = systemProperty(property) { return [value] }
        }
        #endif
        // The gettext chain, in gettext's own order. LANGUAGE is the only
        // variable on the platform that can express "French, then British
        // English", and is the reason this seam returns a list at all.
        if let language = env("LANGUAGE") {
            tags.append(contentsOf: language.split(separator: ":").map(String.init))
        }
        // The single-valued chain, appended behind LANGUAGE as the fallback;
        // naming the same locale twice is free because the list de-duplicates.
        for name in ["LC_ALL", "LC_MESSAGES", "LANG"] {
            if let value = env(name) {
                tags.append(value)
                break
            }
        }
        return tags
        #endif
    }

    /// The host's regional-formatting locale.
    ///
    /// ⚠️ Deliberately NOT the first entry of the list above, and taking it from
    /// there would be wrong. A user may read an English UI and want French
    /// Canadian dates; Windows has "display language" and "regional format" as
    /// separate Settings controls, POSIX has LC_NUMERIC / LC_TIME separate from
    /// LC_MESSAGES, and Apple models the split as `AppleLanguages` vs
    /// `AppleLocale`.
    static func hostRegionalLocale() -> String? {
        #if canImport(WinSDK)
        var name = [WCHAR](repeating: 0, count: Int(LOCALE_NAME_MAX_LENGTH))
        let len = GetUserDefaultLocaleName(&name, Int32(LOCALE_NAME_MAX_LENGTH))
        guard len > 0 else { return nil }
        let tag = String(decodingCString: name, as: UTF16.self)
        return tag.isEmpty ? nil : tag
        #else
        #if canImport(Android)
        for property in ["persist.sys.locale", "ro.product.locale"] {
            if let value = systemProperty(property) { return value }
        }
        #endif
        // LC_ALL beats every category; then the two that decide what a user
        // actually sees; then LANG.
        for name in ["LC_ALL", "LC_NUMERIC", "LC_TIME", "LANG"] {
            if let value = env(name) { return value }
        }
        return nil
        #endif
    }

    // MARK: - The public answers

    /// The preferred UI languages as BCP-47 tags with HYPHENS, most preferred
    /// first. Empty when neither the override nor the host has anything to say --
    /// which is the ordinary state of an unconfigured POSIX login, not an error.
    static var preferredLanguages: [String] {
        // ⚠️ THE OVERRIDE WINS EVEN WHEN IT NORMALIZES TO NOTHING.
        // `WINCAT_LANGUAGES=C` is a caller asking for the no-host-preference
        // path, and answering with the real host list instead would make that
        // path untestable. (`C` rather than the empty string because the Windows
        // CRT DELETES a variable set to `""`, so an empty override is
        // indistinguishable from no override at all there.)
        if let override = env("WINCAT_LANGUAGES") {
            return normalizeList(splitOverride(override))
        }
        return normalizeList(hostPreferredLanguages())
    }

    /// The regional locale as one BCP-47 tag with hyphens, or nil.
    static var regionalLocale: String? {
        if let override = env("WINCAT_LOCALE") {
            return normalize(override)
        }
        guard let host = hostRegionalLocale() else { return nil }
        return normalize(host)
    }

    /// The locale IDENTIFIER, composed the way the ObjC half composes
    /// `AppleLocale` (`Frameworks/Foundation/NSLocalePreferences.mm`,
    /// `_WCCurrentLocaleIdentifier`): the LANGUAGE (and script) come from the
    /// preferred list, the REGION from the regional setting, and only when the
    /// user has not made one does the language tag's own region stand in.
    ///
    /// ⚠️ UNDERSCORES, not the hyphens the language list uses. A locale
    /// identifier is `en_US` and a language identifier is `en-US`; they are
    /// different Apple spellings for what looks like the same thing, and
    /// `Locale.current.identifier` is the first kind. Getting it wrong is
    /// invisible until something compares it to a literal.
    ///
    /// Returns nil when the host expressed no preference at all, leaving the
    /// caller's own fallback in play -- writing an explicit `en_US` here would be
    /// indistinguishable from a user who really chose it.
    static var localeIdentifier: String? {
        let languages = preferredLanguages
        let language = languages.first.map(Subtags.init) ?? Subtags("")
        let region = regionalLocale.map(Subtags.init)?.region ?? language.region

        var composed = language.language
        if composed.isEmpty { return nil }
        if !language.script.isEmpty { composed += "_" + language.script }
        if let region, !region.isEmpty { composed += "_" + region }
        return composed
    }

    /// The three BCP-47 subtags that have to be separable. Anything past them is
    /// carried by the tag itself; only the REGION must come apart, because it is
    /// the half that comes from the host's other setting.
    struct Subtags {
        var language = ""
        var script = ""
        var region: String?

        init(_ tag: String) {
            let parts = tag.split(whereSeparator: { $0 == "-" || $0 == "_" }).map(String.init)
            guard let first = parts.first else { return }
            language = first
            var next = 1
            // A 4-letter subtag in position 2 is a script; BCP-47 is unambiguous.
            if next < parts.count, parts[next].count == 4, parts[next].allSatisfy(\.isASCIILetter) {
                script = parts[next]
                next += 1
            }
            // Then a 2-letter or 3-digit subtag is the region.
            if next < parts.count {
                let part = parts[next]
                if (part.count == 2 && part.allSatisfy(\.isASCIILetter))
                    || (part.count == 3 && part.allSatisfy(\.isASCIIDigit)) {
                    region = part
                }
            }
        }
    }
}

extension Character {
    fileprivate var isASCIILetter: Bool { ("a"..."z").contains(self) || ("A"..."Z").contains(self) }
    fileprivate var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}

extension String {
    fileprivate func trimmingASCIIWhitespace() -> String {
        // A hand-typed `WINCAT_LANGUAGES=fr, en-GB` collects spaces.
        let isSpace: (Character) -> Bool = { $0 == " " || $0 == "\t" || $0 == "\r" || $0 == "\n" }
        guard let first = self.firstIndex(where: { !isSpace($0) }),
              let last = self.lastIndex(where: { !isSpace($0) }) else {
            return ""
        }
        return String(self[first...last])
    }
}
