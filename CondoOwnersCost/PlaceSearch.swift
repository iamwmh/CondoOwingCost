//
//  PlaceSearch.swift
//  CondoOwnersCost
//

import CoreLocation
import Foundation
import MapKit

nonisolated enum PlaceError: LocalizedError {
    case empty
    case notFound
    case locationDenied

    var errorDescription: String? {
        switch self {
        case .empty: L10n.t("place.empty")
        case .notFound: L10n.t("place.notFound")
        case .locationDenied: L10n.t("place.denied")
        }
    }
}

enum PlaceSearch {
    static func search(query raw: String) async throws -> [PlaceCandidate] {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw PlaceError.empty }
        var found: [PlaceCandidate] = []

        if isPostal(query) {
            let geocoder = CLGeocoder()
            if let marks = try? await geocoder.geocodeAddressString("\(query), Canada") {
                for mark in marks where isCanada(mark) {
                    if let candidate = candidate(from: mark, fallbackTitle: formatPostal(query)) {
                        found.append(candidate)
                    }
                }
            }
        }

        let request = MKLocalSearch.Request()
        let mentionsCountry = query.localizedCaseInsensitiveContains("canada") || query.contains("加拿大")
        request.naturalLanguageQuery = mentionsCountry ? query : "\(query), Canada"
        request.resultTypes = [.address, .pointOfInterest]
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 53.5, longitude: -96),
            span: MKCoordinateSpan(latitudeDelta: 36, longitudeDelta: 64)
        )
        if let response = try? await MKLocalSearch(request: request).start() {
            for item in response.mapItems {
                let latitude = item.location.coordinate.latitude
                let longitude = item.location.coordinate.longitude
                guard canadaContains(latitude: latitude, longitude: longitude) else { continue }
                let full = item.address?.fullAddress
                    ?? item.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
                    ?? ""
                let city = item.addressRepresentations?.cityName ?? ""
                let province = provinceCode(in: item.addressRepresentations?.cityWithContext ?? "")
                    ?? provinceCode(in: full)
                    ?? ""
                let postal = postalCode(in: full) ?? ""
                if found.contains(where: { abs($0.latitude - latitude) < 0.00015 && abs($0.longitude - longitude) < 0.00015 }) {
                    continue
                }
                found.append(PlaceCandidate(
                    id: UUID(),
                    title: item.name ?? (city.isEmpty ? query : city),
                    subtitle: full.isEmpty ? [city, province, postal].filter { !$0.isEmpty }.joined(separator: " ") : full,
                    latitude: latitude,
                    longitude: longitude,
                    city: city,
                    provinceCode: province,
                    postalCode: postal,
                    address: full
                ))
            }
        }

        if found.isEmpty { throw PlaceError.notFound }
        return Array(found.prefix(8))
    }

    static func reverse(latitude: Double, longitude: Double) async throws -> PlaceCandidate {
        let geocoder = CLGeocoder()
        let marks = try await geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude))
        guard let mark = marks.first(where: isCanada) ?? (canadaContains(latitude: latitude, longitude: longitude) ? marks.first : nil),
              let candidate = candidate(from: mark, fallbackTitle: L10n.t("marker.pin"))
        else { throw PlaceError.notFound }
        return candidate
    }

    static func currentCoordinate() async throws -> (latitude: Double, longitude: Double) {
        try await CurrentLocation().request()
    }

    static func formatPostal(_ raw: String) -> String {
        let compact = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard compact.count == 6 else { return raw.uppercased() }
        let split = compact.index(compact.startIndex, offsetBy: 3)
        return "\(compact[..<split]) \(compact[split...])"
    }

    private static func candidate(from mark: CLPlacemark, fallbackTitle: String) -> PlaceCandidate? {
        guard let location = mark.location else { return nil }
        let street = [mark.subThoroughfare, mark.thoroughfare].compactMap { $0 }.joined(separator: " ")
        let city = mark.locality ?? mark.subAdministrativeArea ?? ""
        let province = CityBaselines.provinceCode(from: mark.administrativeArea ?? "") ?? ""
        let postal = mark.postalCode.map(formatPostal) ?? ""
        let address = [street, city, province, postal, "Canada"].filter { !$0.isEmpty }.joined(separator: ", ")
        let title = street.isEmpty ? (mark.name ?? fallbackTitle) : street
        return PlaceCandidate(
            id: UUID(),
            title: title,
            subtitle: address,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            city: city,
            provinceCode: province,
            postalCode: postal,
            address: address
        )
    }

    private static func isPostal(_ text: String) -> Bool {
        let compact = text.uppercased().filter { $0.isLetter || $0.isNumber }
        return compact.wholeMatch(of: /[A-Z]\d[A-Z]\d[A-Z]\d/) != nil
    }

    private static func postalCode(in text: String) -> String? {
        guard let match = text.firstMatch(of: /[A-Za-z]\d[A-Za-z][ -]?\d[A-Za-z]\d/) else { return nil }
        return formatPostal(String(text[match.range]))
    }

    private static func provinceCode(in text: String) -> String? {
        let parts = text.split { $0 == "," || $0 == "\n" }.map { String($0).trimmingCharacters(in: .whitespaces) }
        for part in parts.reversed() {
            if let code = CityBaselines.provinceCode(from: part) { return code }
        }
        return nil
    }

    private static func isCanada(_ mark: CLPlacemark) -> Bool {
        if mark.isoCountryCode == "CA" { return true }
        if let location = mark.location {
            return canadaContains(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
        return false
    }

    private static func canadaContains(latitude: Double, longitude: Double) -> Bool {
        (41.6...83.2).contains(latitude) && (-141.1 ... -52.5).contains(longitude)
    }
}

private final class CurrentLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<(latitude: Double, longitude: Double), Error>?
    private var requested = false

    func request() async throws -> (latitude: Double, longitude: Double) {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                requested = true
                manager.requestLocation()
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            default:
                finish { $0.resume(throwing: PlaceError.locationDenied) }
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                guard !self.requested else { return }
                self.requested = true
                manager.requestLocation()
            case .denied, .restricted:
                self.finish { $0.resume(throwing: PlaceError.locationDenied) }
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        let pair = (latitude: coordinate.latitude, longitude: coordinate.longitude)
        Task { @MainActor in
            self.finish { $0.resume(returning: pair) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.finish { $0.resume(throwing: error) }
        }
    }

    private func finish(_ body: (CheckedContinuation<(latitude: Double, longitude: Double), Error>) -> Void) {
        guard let continuation else { return }
        self.continuation = nil
        body(continuation)
    }
}
