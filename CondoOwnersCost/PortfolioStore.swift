//
//  PortfolioStore.swift
//  CondoOwnersCost
//

import Foundation
import Observation

@Observable
final class PortfolioStore {
    private(set) var document = PortfolioDocument()
    var loadError: String?
    var importMessage: String?
    private var canPersist = true

    init() {
        load()
    }

    var properties: [CondoProperty] {
        document.properties.sorted { $0.updatedAt > $1.updatedAt }
    }

    var houses: [HouseEstimate] {
        document.houses.sorted { $0.updatedAt > $1.updatedAt }
    }

    var entries: [LibraryEntry] {
        let condos = properties.map { property in
            let annual = CostEngine.project(property).year(CalendarYear.current)?.netAnnual
            return LibraryEntry(
                id: property.id,
                name: property.name,
                place: property.location.placeLine,
                figure: annual.map { L10n.t("sidebar.perYear", Money.whole($0)) } ?? "",
                updatedAt: property.updatedAt,
                isHouse: false
            )
        }
        let homes = houses.map { house in
            let monthly = HouseCostEngine.evaluate(house).monthlyCash
            let place = house.location.address.isEmpty && house.location.city.isEmpty
                ? L10n.t(house.kind.titleKey)
                : "\(L10n.t(house.kind.titleKey)) · \(house.location.placeLine)"
            return LibraryEntry(
                id: house.id,
                name: house.name,
                place: place,
                figure: L10n.t("house.sidebar", Money.whole(monthly)),
                updatedAt: house.updatedAt,
                isHouse: true
            )
        }
        return (condos + homes).sorted { $0.updatedAt > $1.updatedAt }
    }

    func property(_ id: UUID) -> CondoProperty? {
        document.properties.first { $0.id == id }
    }

    func house(_ id: UUID) -> HouseEstimate? {
        document.houses.first { $0.id == id }
    }

    func contains(_ id: UUID) -> Bool {
        property(id) != nil || house(id) != nil
    }

    @discardableResult
    func addNew() -> UUID {
        let property = CondoProperty()
        document.properties.append(property)
        save()
        return property.id
    }

    @discardableResult
    func addExample() -> UUID {
        let property = CondoProperty.example()
        document.properties.append(property)
        save()
        return property.id
    }

    @discardableResult
    func addHouse(_ kind: HouseKind) -> UUID {
        var house = HouseEstimate.make(kind: kind)
        if let rate = document.snapshot.discountedMortgage {
            house.mortgageRatePercent = rate
        }
        document.houses.append(house)
        save()
        return house.id
    }

    func duplicateHouse(_ id: UUID) -> UUID? {
        guard var house = house(id) else { return nil }
        house.id = UUID()
        house.name += L10n.t("copy.suffix")
        house.createdAt = .now
        house.updatedAt = .now
        document.houses.append(house)
        save()
        return house.id
    }

    func deleteHouse(_ id: UUID) {
        document.houses.removeAll { $0.id == id }
        save()
    }

    func mutateHouse(_ id: UUID, _ body: (inout HouseEstimate) -> Void) {
        guard let index = document.houses.firstIndex(where: { $0.id == id }) else { return }
        body(&document.houses[index])
        document.houses[index].updatedAt = .now
        save()
    }

    func duplicate(_ id: UUID) -> UUID? {
        guard var property = property(id) else { return nil }
        property.id = UUID()
        property.name += L10n.t("copy.suffix")
        property.createdAt = .now
        property.updatedAt = .now
        document.properties.append(property)
        save()
        return property.id
    }

    func delete(_ id: UUID) {
        document.properties.removeAll { $0.id == id }
        save()
    }

    func delete(at offsets: IndexSet, in listed: [CondoProperty]) {
        let ids = offsets.map { listed[$0].id }
        document.properties.removeAll { ids.contains($0.id) }
        save()
    }

    func mutate(_ id: UUID, _ body: (inout CondoProperty) -> Void) {
        guard let index = document.properties.firstIndex(where: { $0.id == id }) else { return }
        body(&document.properties[index])
        document.properties[index].updatedAt = .now
        save()
    }

    func refreshMarket(force: Bool = false) async {
        await ReferenceLibrary.refreshIfStale()
        if !force, let fetched = document.snapshot.fetchedAt, Date().timeIntervalSince(fetched) < 15 * 60 {
            return
        }
        do {
            document.snapshot = try await MarketDataService.fetch()
            save()
            applyLiveRates()
        } catch {
            document.snapshot.fetchError = error.localizedDescription
            document.snapshot.statusMessage = L10n.t("mkt.offline", error.localizedDescription)
            save()
        }
    }

    func applyLiveRates() {
        let snapshot = document.snapshot
        guard snapshot.fiveYearBond != nil || snapshot.postedFiveYearMortgage != nil else { return }
        for index in document.properties.indices where document.properties[index].inputs.followBankRate {
            let includeInflation = document.properties[index].inputs.ratesAreSuggested
            document.properties[index].applyMarket(snapshot, choice: .discounted, includeInflation: includeInflation)
            document.properties[index].inputs.followBankRate = true
        }
        save()
    }

    func exportData(propertyIDs: [UUID]?) throws -> Data {
        var copy = document
        if let propertyIDs {
            copy.properties = document.properties.filter { propertyIDs.contains($0.id) }
            copy.houses = document.houses.filter { propertyIDs.contains($0.id) }
        }
        copy.schemaVersion = PortfolioDocument.currentSchema
        copy.exportedAt = .now
        return try PortfolioDocument.encoder.encode(copy)
    }

    func importData(_ data: Data) throws {
        let decoder = PortfolioDocument.decoder
        if let envelope = try? decoder.decode(PortfolioDocument.self, from: data),
           envelope.schemaVersion > 0 || !envelope.properties.isEmpty || !envelope.houses.isEmpty {
            merge(envelope)
            return
        }
        if let property = try? decoder.decode(CondoProperty.self, from: data) {
            merge(property)
            return
        }
        throw CocoaError(.coderReadCorrupt)
    }

    private func merge(_ envelope: PortfolioDocument) {
        if let importedDate = envelope.snapshot.fetchedAt,
           importedDate > (document.snapshot.fetchedAt ?? .distantPast) {
            document.snapshot = envelope.snapshot
        }
        for property in envelope.properties {
            merge(property)
        }
        for house in envelope.houses {
            merge(house)
        }
        let count = envelope.properties.count + envelope.houses.count
        importMessage = count == 0 ? L10n.t("import.empty") : L10n.t("import.merged", count)
        save()
    }

    private func merge(_ house: HouseEstimate) {
        if let index = document.houses.firstIndex(where: { $0.id == house.id }) {
            document.houses[index] = house
        } else {
            document.houses.append(house)
        }
    }

    private func merge(_ property: CondoProperty) {
        if let index = document.properties.firstIndex(where: { $0.id == property.id }) {
            document.properties[index] = property
        } else {
            document.properties.append(property)
        }
    }

    private func load() {
        let url = Self.fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            canPersist = true
            return
        }
        do {
            let data = try Data(contentsOf: url)
            document = try PortfolioDocument.decoder.decode(PortfolioDocument.self, from: data)
            canPersist = true
        } catch {
            canPersist = false
            loadError = L10n.t("load.fail")
        }
    }

    private func save() {
        guard canPersist else { return }
        do {
            let data = try PortfolioDocument.encoder.encode(document)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            loadError = L10n.t("save.fail", error.localizedDescription)
        }
    }

    private static var fileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CondoOwnersCost", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("portfolio.json")
    }
}
