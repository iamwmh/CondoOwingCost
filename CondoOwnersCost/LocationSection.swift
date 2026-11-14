//
//  LocationSection.swift
//  CondoOwnersCost
//

import CoreLocation
import MapKit
import SwiftUI

struct LocationSection: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(LanguageSettings.self) private var lang
    let propertyID: UUID
    @State private var query = ""
    @State private var results: [PlaceCandidate] = []
    @State private var status: String?
    @State private var searching = false
    @State private var camera: MapCameraPosition = .automatic

    private var property: CondoProperty? { store.property(propertyID) }

    var body: some View {
        if let property {
            SectionCard(title: lang.t("loc.title"), subtitle: lang.t("loc.subtitle")) {
                map(property)
                HStack {
                    TextField(lang.t("loc.search"), text: $query)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onSubmit { Task { await runSearch() } }
                    Button(lang.t("loc.go")) { Task { await runSearch() } }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.teal)
                        .disabled(searching)
                }
                if searching { ProgressView() }
                if let status {
                    Footnote(text: status)
                }
                ForEach(results) { place in
                    Button {
                        Task { await choose(place) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.title)
                                .foregroundStyle(Theme.ink)
                            Text(place.subtitle)
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                HStack {
                    Button(lang.t("loc.mine")) { Task { await useCurrentLocation() } }
                    Spacer()
                    if property.location.latitude != nil {
                        Button(lang.t("loc.maps")) { openInMaps(property) }
                    }
                }
                .font(.subheadline)
                if let lat = property.location.latitude, let lon = property.location.longitude {
                    Text(String(format: "%.6f, %.6f", lat, lon))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
                baselineMenu(property)
                mismatch(property)
            }
            .onAppear {
                if query.isEmpty {
                    query = property.location.query.isEmpty ? property.location.address : property.location.query
                }
                look(at: property)
            }
        }
    }

    @ViewBuilder
    private func map(_ property: CondoProperty) -> some View {
        MapReader { proxy in
            Map(position: $camera) {
                if let lat = property.location.latitude, let lon = property.location.longitude {
                    Marker(property.location.buildingName.isEmpty ? property.name : property.location.buildingName,
                           coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                }
            }
            .mapStyle(.standard)
            .mapControls { MapCompass() }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                Task { await dropPin(latitude: coordinate.latitude, longitude: coordinate.longitude) }
            }
        }
    }

    @ViewBuilder
    private func baselineMenu(_ property: CondoProperty) -> some View {
        Menu(lang.t("loc.baseline")) {
            ForEach(CityBaselines.selectableGroups, id: \.code) { group in
                Section(group.name) {
                    ForEach(group.cities) { city in
                        Button(city.menuTitle) {
                            store.mutate(propertyID) { $0.apply(baseline: city, includingStrata: false) }
                        }
                    }
                }
            }
        }
        if let applied = property.location.appliedBaselineID, let city = CityBaselines.byID[applied] {
            Footnote(text: city.localizedSource())
        } else {
            Footnote(text: CityBaselines.taxNote(for: property))
        }
    }

    @ViewBuilder
    private func mismatch(_ property: CondoProperty) -> some View {
        if let matched = CityBaselines.match(city: property.location.city, province: property.location.provinceCode),
           matched.id != property.location.appliedBaselineID {
            VStack(alignment: .leading, spacing: 8) {
                Text(lang.t("loc.mismatch", matched.localizedName))
                    .font(.footnote)
                    .foregroundStyle(Theme.ink)
                Button(lang.t("loc.updateTax")) {
                    store.mutate(propertyID) { $0.apply(baseline: matched, includingStrata: false) }
                }
                Button(lang.t("loc.updateAll")) {
                    store.mutate(propertyID) { $0.apply(baseline: matched, includingStrata: true) }
                }
            }
            .padding(10)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func runSearch() async {
        searching = true
        status = nil
        defer { searching = false }
        do {
            results = try await PlaceSearch.search(query: query)
            status = nil
        } catch {
            results = []
            status = error.localizedDescription
        }
    }

    private func choose(_ candidate: PlaceCandidate) async {
        var place = candidate
        if let refined = try? await PlaceSearch.reverse(latitude: candidate.latitude, longitude: candidate.longitude) {
            if place.city.isEmpty { place.city = refined.city }
            if place.provinceCode.isEmpty { place.provinceCode = refined.provinceCode }
            if place.postalCode.isEmpty { place.postalCode = refined.postalCode }
            if place.address.isEmpty { place.address = refined.address }
        }
        store.mutate(propertyID) {
            $0.location.query = query
            $0.apply(place: place)
        }
        results = []
        if let property = store.property(propertyID) { look(at: property) }
    }

    private func dropPin(latitude: Double, longitude: Double) async {
        guard let place = try? await PlaceSearch.reverse(latitude: latitude, longitude: longitude) else {
            store.mutate(propertyID) {
                $0.location.latitude = latitude
                $0.location.longitude = longitude
            }
            return
        }
        store.mutate(propertyID) { $0.apply(place: place) }
        if let property = store.property(propertyID) { look(at: property) }
    }

    private func useCurrentLocation() async {
        do {
            let coordinate = try await PlaceSearch.currentCoordinate()
            await dropPin(latitude: coordinate.latitude, longitude: coordinate.longitude)
        } catch {
            status = error.localizedDescription
        }
    }

    private func openInMaps(_ property: CondoProperty) {
        guard let lat = property.location.latitude, let lon = property.location.longitude else { return }
        let item = MKMapItem(location: CLLocation(latitude: lat, longitude: lon), address: nil)
        item.name = property.location.buildingName.isEmpty ? property.name : property.location.buildingName
        item.openInMaps(launchOptions: nil, from: nil) { _ in }
    }

    private func look(at property: CondoProperty) {
        guard let lat = property.location.latitude, let lon = property.location.longitude else { return }
        camera = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        ))
    }
}
