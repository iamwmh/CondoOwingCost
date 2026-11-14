//
//  MarketDataService.swift
//  CondoOwnersCost
//

import Foundation

enum MarketDataService {
    private static let mortgageSeries = "V80691335"
    private static let bondSeries = "BD.CDN.5YR.DQ.YLD"
    private static let policySeries = "V39079"
    private static let primeSeries = "V80691311"
    private static let cpiVector = 41690973

    static func fetch() async throws -> MarketSnapshot {
        async let rates = bankOfCanada()
        async let inflation = cpiYearOverYear()
        let boc = try await rates
        let cpi = await inflation
        var snapshot = boc
        snapshot.cpiYoY = cpi
        snapshot.fetchedAt = .now
        snapshot.fetchError = nil
        snapshot.statusMessage = ""
        return snapshot
    }

    private static func bankOfCanada() async throws -> MarketSnapshot {
        let series = [mortgageSeries, bondSeries, policySeries, primeSeries].joined(separator: ",")
        guard let url = URL(string: "https://www.bankofcanada.ca/valet/observations/\(series)/json?recent=12") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("CondoOwnersCost/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(ValetResponse.self, from: data)
        var snapshot = MarketSnapshot()
        for observation in decoded.observations {
            for (key, point) in observation.values {
                guard let value = Double(point.v) else { continue }
                switch key {
                case mortgageSeries:
                    snapshot.postedFiveYearMortgage = value
                    snapshot.mortgageAsOf = observation.date
                case bondSeries:
                    snapshot.fiveYearBond = value
                    snapshot.bondAsOf = observation.date
                case policySeries:
                    snapshot.policyRate = value
                    snapshot.policyAsOf = observation.date
                case primeSeries:
                    snapshot.primeRate = value
                    snapshot.primeAsOf = observation.date
                default: break
                }
            }
        }
        guard snapshot.postedFiveYearMortgage != nil || snapshot.fiveYearBond != nil else {
            throw URLError(.cannotParseResponse)
        }
        return snapshot
    }

    private static func cpiYearOverYear() async -> Double? {
        guard let url = URL(string: "https://www150.statcan.gc.ca/t1/wds/rest/getDataFromVectorsAndLatestNPeriods") else {
            return nil
        }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("CondoOwnersCost/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = Data("[{\"vectorId\":\(cpiVector),\"latestN\":14}]".utf8)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let root = try? JSONSerialization.jsonObject(with: data)
        else { return nil }

        var values: [Double] = []
        collectCPI(root, into: &values)
        guard values.count >= 13, let latest = values.last else { return nil }
        let earlier = values[values.count - 13]
        guard earlier > 0 else { return nil }
        let yoy = (latest / earlier - 1) * 100
        guard (-2...15).contains(yoy) else { return nil }
        return yoy
    }

    private static func collectCPI(_ node: Any, into values: inout [Double]) {
        if let dictionary = node as? [String: Any] {
            if dictionary["refPer"] != nil {
                if let value = dictionary["value"] as? Double {
                    values.append(value)
                } else if let value = dictionary["value"] as? Int {
                    values.append(Double(value))
                } else if let text = dictionary["value"] as? String, let value = Double(text) {
                    values.append(value)
                }
            }
            for child in dictionary.values {
                collectCPI(child, into: &values)
            }
        } else if let array = node as? [Any] {
            for child in array {
                collectCPI(child, into: &values)
            }
        }
    }

}

nonisolated private struct ValetResponse: Decodable {
    var observations: [ValetObservation]
}

nonisolated private struct ValetObservation: Decodable {
    var date: String?
    var values: [String: ValetPoint]

    private struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        init(_ string: String) { stringValue = string }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        var values: [String: ValetPoint] = [:]
        var date: String?
        for key in container.allKeys {
            if key.stringValue == "d" {
                date = try? container.decode(String.self, forKey: key)
                continue
            }
            if let point = try? container.decode(ValetPoint.self, forKey: key) {
                values[key.stringValue] = point
            }
        }
        self.date = date
        self.values = values
    }
}

nonisolated private struct ValetPoint: Decodable {
    var v: String
}
