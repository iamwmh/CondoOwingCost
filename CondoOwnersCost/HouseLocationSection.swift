//
//  HouseLocationSection.swift
//  CondoOwnersCost
//

import CoreLocation
import MapKit
import SwiftUI

struct HouseLocationSection: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(LanguageSettings.self) private var lang
    let houseID: UUID
    @State private var query = ""
    @State private var results: [PlaceCandidate] = []
    @State private var status: String?
    @State private var searching = false
    @State private var camera: MapCameraPosition = .automatic

    private var house: HouseEstimate? { store.house(houseID) }

    var body: some View {
        if let house {
            SectionCard(title: lang.t("loc.title"), subtitle: lang.t("house.loc.subtitle")) {
                map(house)
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
                    if house.location.latitude != nil {
                        Button(lang.t("loc.maps")) { openInMaps(house) }
                    }
                }
                .font(.subheadline)
                details(house)
                baselineMenu(house)
                mismatch(house)
                Footnote(text: lang.t("house.match.note"))
            }
            .onAppear {
                if query.isEmpty {
                    query = house.location.query.isEmpty ? house.location.address : house.location.query
                }
                look(at: house)
            }
        }
    }

    @ViewBuilder
    private func map(_ house: HouseEstimate) -> some View {
        MapReader { proxy in
            Map(position: $camera) {
                if let lat = house.location.latitude, let lon = house.location.longitude {
                    Marker(house.location.buildingName.isEmpty ? house.name : house.location.buildingName,
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
    private func details(_ house: HouseEstimate) -> some View {
        TextField(lang.t("house.address"), text: store.bindHouse(houseID, \.location.address, fallback: ""))
        TextField(lang.t("house.city"), text: cityBinding)
        TextField(lang.t("house.postal"), text: store.bindHouse(houseID, \.location.postalCode, fallback: ""))
            .textInputAutocapitalization(.characters)
        if let lat = house.location.latitude, let lon = house.location.longitude {
            Text(String(format: "%.6f, %.6f", lat, lon))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.muted)
        }
        if let applied = house.location.appliedBaselineID, let city = CityBaselines.byID[applied] {
            Footnote(text: city.localizedSource())
        }
    }

    private var cityBinding: Binding<String> {
        Binding(
            get: { store.house(houseID)?.location.city ?? "" },
            set: { value in
                store.mutateHouse(houseID) {
                    $0.location.city = value
                    $0.city = value
                }
            }
        )
    }

    @ViewBuilder
    private func baselineMenu(_ house: HouseEstimate) -> some View {
        Menu(lang.t("loc.baseline")) {
            ForEach(CityBaselines.selectableGroups, id: \.code) { group in
                Section(group.name) {
                    ForEach(group.cities) { city in
                        Button(city.menuTitle) {
                            store.mutateHouse(houseID) {
                                if $0.location.city.isEmpty { $0.location.city = city.localizedName }
                                $0.location.provinceCode = city.provinceCode
                                $0.city = $0.location.city
                                $0.apply(baseline: city)
                                $0.estimatesAreSuggested = false
                            }
                            if let current = store.house(houseID) { look(at: current) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mismatch(_ house: HouseEstimate) -> some View {
        if let matched = CityBaselines.match(city: house.location.city, province: house.location.provinceCode),
           matched.id != house.location.appliedBaselineID {
            VStack(alignment: .leading, spacing: 8) {
                Text(lang.t("loc.mismatch", matched.localizedName))
                    .font(.footnote)
                    .foregroundStyle(Theme.ink)
                Button(lang.t("house.match.action")) {
                    store.mutateHouse(houseID) {
                        $0.applyMatchedEstimates()
                        $0.estimatesAreSuggested = false
                    }
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
        store.mutateHouse(houseID) {
            $0.location.query = query
            $0.apply(place: place)
        }
        results = []
        query = place.address.isEmpty ? place.title : place.address
        if let house = store.house(houseID) { look(at: house) }
    }

    private func dropPin(latitude: Double, longitude: Double) async {
        guard let place = try? await PlaceSearch.reverse(latitude: latitude, longitude: longitude) else {
            store.mutateHouse(houseID) {
                $0.location.latitude = latitude
                $0.location.longitude = longitude
            }
            return
        }
        store.mutateHouse(houseID) { $0.apply(place: place) }
        if let house = store.house(houseID) { look(at: house) }
    }

    private func useCurrentLocation() async {
        do {
            let coordinate = try await PlaceSearch.currentCoordinate()
            await dropPin(latitude: coordinate.latitude, longitude: coordinate.longitude)
        } catch {
            status = error.localizedDescription
        }
    }

    private func openInMaps(_ house: HouseEstimate) {
        guard let lat = house.location.latitude, let lon = house.location.longitude else { return }
        let item = MKMapItem(location: CLLocation(latitude: lat, longitude: lon), address: nil)
        item.name = house.location.buildingName.isEmpty ? house.name : house.location.buildingName
        item.openInMaps(launchOptions: nil, from: nil) { _ in }
    }

    private func look(at house: HouseEstimate) {
        guard let lat = house.location.latitude, let lon = house.location.longitude else { return }
        camera = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        ))
    }
}
