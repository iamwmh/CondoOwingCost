//
//  ReferenceLibrary.swift
//  CondoOwnersCost
//

import Foundation

nonisolated struct StoredCityRate: Codable, Equatable {
    var propertyTaxPercent: Double
    var taxYear: Int
    var sourceURL: String
    var fetchedAt: Date
}

nonisolated struct ReferenceLibraryFile: Codable, Equatable {
    var checkedAt: Date?
    var rates: [String: StoredCityRate] = [:]
}

nonisolated enum ReferenceLibrary {
    /// Tax bylaws change yearly. Two weeks is often enough, and a failed network leaves the saved copy in place.
    static let refreshInterval: TimeInterval = 14 * 24 * 60 * 60

    static func read() -> ReferenceLibraryFile {
        guard let data = try? Data(contentsOf: fileURL) else { return ReferenceLibraryFile() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(ReferenceLibraryFile.self, from: data)) ?? ReferenceLibraryFile()
    }

    static func refreshIfStale() async {
        let file = read()
        if let checked = file.checkedAt, Date().timeIntervalSince(checked) < refreshInterval {
            CityBaselines.install(file)
            return
        }
        await refresh()
    }

    static func refresh() async {
        var file = read()
        var reachedAPage = false
        for page in pages {
            guard let html = try? await fetch(page.url) else { continue }
            reachedAPage = true
            guard let percent = page.parse(html), (0.15...3).contains(percent) else { continue }
            file.rates[page.id] = StoredCityRate(
                propertyTaxPercent: percent,
                taxYear: publishedYear(in: html),
                sourceURL: page.url.absoluteString,
                fetchedAt: .now
            )
        }
        guard reachedAPage else { return }
        file.checkedAt = .now
        write(file)
        CityBaselines.install(file)
    }

    static func parseToronto(_ html: String) -> Double? {
        guard let slice = residentialSlice(html, stop: "Multi-Residential") else { return nil }
        let numbers = values(in: slice, pattern: #"([0-9]+\.[0-9]+)\s*%"#)
        guard numbers.count >= 4 else { return nil }
        let total = numbers[3]
        let parts = numbers[0] + numbers[1] + numbers[2]
        guard abs(parts - total) < 0.00005, (0.2...2.5).contains(total) else { return nil }
        return total
    }

    static func parseCalgary(_ html: String) -> Double? {
        guard let slice = residentialSlice(html, stop: "Non-Residential") else { return nil }
        let numbers = values(in: slice, pattern: #"(0\.00[0-9]+)"#)
        guard numbers.count >= 3 else { return nil }
        let total = numbers[2]
        guard abs((numbers[0] + numbers[1]) - total) < 0.0000005 else { return nil }
        let percent = total * 100
        guard (0.2...2.5).contains(percent) else { return nil }
        return (percent * 1_000_000).rounded() / 1_000_000
    }

    static func parseVancouver(_ html: String) -> Double? {
        guard let total = html.range(of: "Total") else { return nil }
        let tail = html[total.upperBound...].prefix(180)
        guard let dollar = tail.firstIndex(of: "$") else { return nil }
        let after = tail[tail.index(after: dollar)...]
        let digits = after.prefix { $0.isNumber || $0 == "." }
        guard let perThousand = Double(digits), (1...15).contains(perThousand) else { return nil }
        let percent = perThousand / 10
        guard (0.15...2).contains(percent) else { return nil }
        return (percent * 1_000_000).rounded() / 1_000_000
    }

    private struct Page {
        var id: String
        var url: URL
        var parse: (String) -> Double?
    }

    private static let pages: [Page] = [
        Page(id: "toronto", url: URL(string: "https://www.toronto.ca/services-payments/property-taxes-utilities/property-tax/property-tax-rates-and-fees/")!, parse: parseToronto),
        Page(id: "calgary", url: URL(string: "https://www.calgary.ca/property-owners/taxes/bill-rate-calculation.html")!, parse: parseCalgary),
        Page(id: "vancouver", url: URL(string: "https://vancouver.ca/home-property-development/residential.aspx")!, parse: parseVancouver)
    ]

    private static func residentialSlice(_ html: String, stop: String) -> String? {
        guard let start = html.range(of: ">Residential<") ?? html.range(of: "\nResidential\n") ?? html.range(of: ">Residential</") else {
            return nil
        }
        let rest = html[start.upperBound...]
        if let end = rest.range(of: stop) {
            return String(rest[..<end.lowerBound])
        }
        return String(rest.prefix(800))
    }

    private static func values(in text: String, pattern: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let span = Range(match.range(at: 1), in: text) else { return nil }
            return Double(text[span])
        }
    }

    private static func publishedYear(in html: String) -> Int {
        let now = CalendarYear.current
        for year in [now + 1, now, now - 1] where html.contains(String(year)) {
            return year
        }
        return now
    }

    private static func fetch(_ url: URL) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 25)
        request.setValue("CondoOwnersCost/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw URLError(.cannotDecodeContentData)
        }
        return html
    }

    private static func write(_ file: ReferenceLibraryFile) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(file) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CondoOwnersCost", isDirectory: true)
            .appendingPathComponent("reference.json")
    }
}
