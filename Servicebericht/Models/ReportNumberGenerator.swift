import Foundation

/// Erzeugt Berichtsnummern im Format `SB-JJJJMMTT-XXXX`
/// (Einsatzdatum plus 4 zufällige Zeichen A–Z / 0–9).
enum ReportNumberGenerator {
    static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    static func make(for date: Date,
                     existing: Set<String>,
                     calendar: Calendar = .current) -> String {
        var generator = SystemRandomNumberGenerator()
        return make(for: date, existing: existing, calendar: calendar, using: &generator)
    }

    static func make<G: RandomNumberGenerator>(for date: Date,
                                               existing: Set<String>,
                                               calendar: Calendar = .current,
                                               using generator: inout G) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let datePart = String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        while true {
            let suffix = String((0..<4).map { _ in alphabet.randomElement(using: &generator)! })
            let candidate = "SB-\(datePart)-\(suffix)"
            if !existing.contains(candidate) { return candidate }
        }
    }
}
