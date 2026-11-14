//
//  Models.swift
//  CondoOwnersCost
//

import Foundation

nonisolated enum CalendarYear {
    static var current: Int {
        Calendar.current.component(.year, from: .now)
    }
}

nonisolated enum Occupancy: String, Codable, CaseIterable, Equatable, Hashable {
    case principal
    case investment

    var title: String {
        switch self {
        case .principal: L10n.t("occ.principal")
        case .investment: L10n.t("occ.investment")
        }
    }
}

nonisolated enum DownPaymentMode: String, Codable, CaseIterable, Equatable, Hashable {
    case percent
    case amount

    var title: String {
        switch self {
        case .percent: L10n.t("down.percent")
        case .amount: L10n.t("down.amount")
        }
    }
}

nonisolated enum LevyMode: String, Codable, CaseIterable, Equatable, Hashable {
    case percentOfStrata
    case fixedAnnual

    var title: String {
        switch self {
        case .percentOfStrata: L10n.t("levy.percent")
        case .fixedAnnual: L10n.t("levy.fixed")
        }
    }
}

nonisolated enum AreaUnit: String, Codable, CaseIterable, Equatable, Hashable {
    case sqft
    case sqm

    var title: String {
        switch self {
        case .sqft: L10n.t("area.sqft")
        case .sqm: L10n.t("area.sqm")
        }
    }
}

nonisolated enum CostGroup: String, CaseIterable, Equatable, Hashable {
    case fixed
    case variable
    case capital

    var title: String {
        switch self {
        case .fixed: L10n.t("group.fixed")
        case .variable: L10n.t("group.variable")
        case .capital: L10n.t("group.capital")
        }
    }
}

nonisolated enum MortgageChoice: String, Equatable {
    case discounted
    case posted
}

nonisolated struct ProjectionAssumptions: Codable, Equatable {
    var targetYear: Int = CalendarYear.current + 5
    var assessmentGrowthPercent: Double = 3
    var taxRateGrowthPercent: Double = 2.5
    var strataInflationPercent: Double = 4
    var insuranceInflationPercent: Double = 5
    var utilitiesInflationPercent: Double = 3

    private enum CodingKeys: String, CodingKey {
        case targetYear, assessmentGrowthPercent, taxRateGrowthPercent
        case strataInflationPercent, insuranceInflationPercent, utilitiesInflationPercent
    }

    init() {}

    init(from decoder: Decoder) throws {
        let fallback = ProjectionAssumptions()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targetYear = container.soft(.targetYear, fallback.targetYear)
        assessmentGrowthPercent = container.soft(.assessmentGrowthPercent, fallback.assessmentGrowthPercent)
        taxRateGrowthPercent = container.soft(.taxRateGrowthPercent, fallback.taxRateGrowthPercent)
        strataInflationPercent = container.soft(.strataInflationPercent, fallback.strataInflationPercent)
        insuranceInflationPercent = container.soft(.insuranceInflationPercent, fallback.insuranceInflationPercent)
        utilitiesInflationPercent = container.soft(.utilitiesInflationPercent, fallback.utilitiesInflationPercent)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(targetYear, forKey: .targetYear)
        try container.encode(assessmentGrowthPercent, forKey: .assessmentGrowthPercent)
        try container.encode(taxRateGrowthPercent, forKey: .taxRateGrowthPercent)
        try container.encode(strataInflationPercent, forKey: .strataInflationPercent)
        try container.encode(insuranceInflationPercent, forKey: .insuranceInflationPercent)
        try container.encode(utilitiesInflationPercent, forKey: .utilitiesInflationPercent)
    }
}

nonisolated struct CostInputs: Codable, Equatable {
    var purchasePrice: Double = 800_000
    var assessedValue: Double = 800_000
    var assessedLocked: Bool = false
    var useDirectPropertyTax: Bool = false
    var directPropertyTaxAnnual: Double = 0
    var indoorSqft: Double = 700
    var areaUnit: AreaUnit = .sqft
    var yearBuilt: Int = 2012
    var hasPool: Bool = false
    var hasConcierge: Bool = false
    var hasHeatPump: Bool = false
    var downPaymentMode: DownPaymentMode = .percent
    var downPaymentPercent: Double = 20
    var downPaymentAmount: Double = 160_000
    var amortYears: Int = 25
    var mortgageStartYear: Int = CalendarYear.current
    var mortgageRatePercent: Double = 4.9
    var renewalUsesInitialRate: Bool = true
    var renewalEveryYears: Int = 5
    var renewalRatePercent: Double = 4.9
    var capitalizePremium: Bool = true
    var payInFull: Bool = false
    var followBankRate: Bool = true
    var ratesAreSuggested: Bool = true
    var usesPlaceholderCosts: Bool = true
    var occupancy: Occupancy = .principal
    var marginalTaxPercent: Double = 33
    var annualRent: Double = 0
    var useMonthlyStrata: Bool = false
    var strataPerSqftMonthly: Double = 0.70
    var strataMonthly: Double = 490
    var propertyTaxPercent: Double = 0.35
    var taxRateOfficial: Bool = false
    var taxSourceNote: String = "placeholder"
    var insuranceAnnual: Double = 900
    var hydroMonthly: Double = 65
    var internetMonthly: Double = 80
    var heatPumpMonthly: Double = 0
    var waterMonthly: Double = 0
    var otherMonthly: Double = 0
    var waterIncludedInStrata: Bool = true
    var levyMode: LevyMode = .percentOfStrata
    var levyPercent: Double = 15
    var levyFixedAnnual: Double = 1_500
    var levyUsesFloor: Bool = true
    var levyFloorAnnual: Double = 1_000
    var includeOpportunity: Bool = true
    var riskFreePercent: Double = 3.6
    var projection: ProjectionAssumptions = ProjectionAssumptions()

    private enum CodingKeys: String, CodingKey {
        case purchasePrice, assessedValue, assessedLocked, useDirectPropertyTax, directPropertyTaxAnnual
        case indoorSqft, areaUnit, yearBuilt, hasPool, hasConcierge, hasHeatPump
        case downPaymentMode, downPaymentPercent, downPaymentAmount, amortYears, mortgageStartYear
        case mortgageRatePercent, renewalUsesInitialRate, renewalEveryYears, renewalRatePercent
        case capitalizePremium, payInFull, followBankRate, ratesAreSuggested, usesPlaceholderCosts, occupancy, marginalTaxPercent, annualRent
        case useMonthlyStrata, strataPerSqftMonthly, strataMonthly, propertyTaxPercent, taxRateOfficial, taxSourceNote
        case insuranceAnnual, hydroMonthly, internetMonthly, heatPumpMonthly, waterMonthly, otherMonthly
        case waterIncludedInStrata, levyMode, levyPercent, levyFixedAnnual, levyUsesFloor, levyFloorAnnual
        case includeOpportunity, riskFreePercent, projection
    }

    init() {}

    init(from decoder: Decoder) throws {
        let fallback = CostInputs()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        purchasePrice = container.soft(.purchasePrice, fallback.purchasePrice)
        assessedValue = container.soft(.assessedValue, fallback.assessedValue)
        assessedLocked = container.soft(.assessedLocked, fallback.assessedLocked)
        useDirectPropertyTax = container.soft(.useDirectPropertyTax, fallback.useDirectPropertyTax)
        directPropertyTaxAnnual = container.soft(.directPropertyTaxAnnual, fallback.directPropertyTaxAnnual)
        indoorSqft = container.soft(.indoorSqft, fallback.indoorSqft)
        areaUnit = container.soft(.areaUnit, fallback.areaUnit)
        yearBuilt = container.soft(.yearBuilt, fallback.yearBuilt)
        hasPool = container.soft(.hasPool, fallback.hasPool)
        hasConcierge = container.soft(.hasConcierge, fallback.hasConcierge)
        hasHeatPump = container.soft(.hasHeatPump, fallback.hasHeatPump)
        downPaymentMode = container.soft(.downPaymentMode, fallback.downPaymentMode)
        downPaymentPercent = container.soft(.downPaymentPercent, fallback.downPaymentPercent)
        downPaymentAmount = container.soft(.downPaymentAmount, fallback.downPaymentAmount)
        amortYears = container.soft(.amortYears, fallback.amortYears)
        mortgageStartYear = container.soft(.mortgageStartYear, fallback.mortgageStartYear)
        mortgageRatePercent = container.soft(.mortgageRatePercent, fallback.mortgageRatePercent)
        renewalUsesInitialRate = container.soft(.renewalUsesInitialRate, fallback.renewalUsesInitialRate)
        renewalEveryYears = container.soft(.renewalEveryYears, fallback.renewalEveryYears)
        renewalRatePercent = container.soft(.renewalRatePercent, fallback.renewalRatePercent)
        capitalizePremium = container.soft(.capitalizePremium, fallback.capitalizePremium)
        payInFull = container.soft(.payInFull, false)
        ratesAreSuggested = container.soft(.ratesAreSuggested, fallback.ratesAreSuggested)
        followBankRate = container.soft(.followBankRate, ratesAreSuggested)
        usesPlaceholderCosts = container.soft(.usesPlaceholderCosts, fallback.usesPlaceholderCosts)
        occupancy = container.soft(.occupancy, fallback.occupancy)
        marginalTaxPercent = container.soft(.marginalTaxPercent, fallback.marginalTaxPercent)
        annualRent = container.soft(.annualRent, fallback.annualRent)
        useMonthlyStrata = container.soft(.useMonthlyStrata, fallback.useMonthlyStrata)
        strataPerSqftMonthly = container.soft(.strataPerSqftMonthly, fallback.strataPerSqftMonthly)
        strataMonthly = container.soft(.strataMonthly, fallback.strataMonthly)
        propertyTaxPercent = container.soft(.propertyTaxPercent, fallback.propertyTaxPercent)
        taxRateOfficial = container.soft(.taxRateOfficial, fallback.taxRateOfficial)
        taxSourceNote = container.soft(.taxSourceNote, fallback.taxSourceNote)
        insuranceAnnual = container.soft(.insuranceAnnual, fallback.insuranceAnnual)
        hydroMonthly = container.soft(.hydroMonthly, fallback.hydroMonthly)
        internetMonthly = container.soft(.internetMonthly, fallback.internetMonthly)
        heatPumpMonthly = container.soft(.heatPumpMonthly, fallback.heatPumpMonthly)
        waterMonthly = container.soft(.waterMonthly, fallback.waterMonthly)
        otherMonthly = container.soft(.otherMonthly, fallback.otherMonthly)
        waterIncludedInStrata = container.soft(.waterIncludedInStrata, fallback.waterIncludedInStrata)
        levyMode = container.soft(.levyMode, fallback.levyMode)
        levyPercent = container.soft(.levyPercent, fallback.levyPercent)
        levyFixedAnnual = container.soft(.levyFixedAnnual, fallback.levyFixedAnnual)
        levyUsesFloor = container.soft(.levyUsesFloor, fallback.levyUsesFloor)
        levyFloorAnnual = container.soft(.levyFloorAnnual, fallback.levyFloorAnnual)
        includeOpportunity = container.soft(.includeOpportunity, fallback.includeOpportunity)
        riskFreePercent = container.soft(.riskFreePercent, fallback.riskFreePercent)
        projection = container.soft(.projection, fallback.projection)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(purchasePrice, forKey: .purchasePrice)
        try container.encode(assessedValue, forKey: .assessedValue)
        try container.encode(assessedLocked, forKey: .assessedLocked)
        try container.encode(useDirectPropertyTax, forKey: .useDirectPropertyTax)
        try container.encode(directPropertyTaxAnnual, forKey: .directPropertyTaxAnnual)
        try container.encode(indoorSqft, forKey: .indoorSqft)
        try container.encode(areaUnit, forKey: .areaUnit)
        try container.encode(yearBuilt, forKey: .yearBuilt)
        try container.encode(hasPool, forKey: .hasPool)
        try container.encode(hasConcierge, forKey: .hasConcierge)
        try container.encode(hasHeatPump, forKey: .hasHeatPump)
        try container.encode(downPaymentMode, forKey: .downPaymentMode)
        try container.encode(downPaymentPercent, forKey: .downPaymentPercent)
        try container.encode(downPaymentAmount, forKey: .downPaymentAmount)
        try container.encode(amortYears, forKey: .amortYears)
        try container.encode(mortgageStartYear, forKey: .mortgageStartYear)
        try container.encode(mortgageRatePercent, forKey: .mortgageRatePercent)
        try container.encode(renewalUsesInitialRate, forKey: .renewalUsesInitialRate)
        try container.encode(renewalEveryYears, forKey: .renewalEveryYears)
        try container.encode(renewalRatePercent, forKey: .renewalRatePercent)
        try container.encode(capitalizePremium, forKey: .capitalizePremium)
        try container.encode(payInFull, forKey: .payInFull)
        try container.encode(followBankRate, forKey: .followBankRate)
        try container.encode(ratesAreSuggested, forKey: .ratesAreSuggested)
        try container.encode(usesPlaceholderCosts, forKey: .usesPlaceholderCosts)
        try container.encode(occupancy, forKey: .occupancy)
        try container.encode(marginalTaxPercent, forKey: .marginalTaxPercent)
        try container.encode(annualRent, forKey: .annualRent)
        try container.encode(useMonthlyStrata, forKey: .useMonthlyStrata)
        try container.encode(strataPerSqftMonthly, forKey: .strataPerSqftMonthly)
        try container.encode(strataMonthly, forKey: .strataMonthly)
        try container.encode(propertyTaxPercent, forKey: .propertyTaxPercent)
        try container.encode(taxRateOfficial, forKey: .taxRateOfficial)
        try container.encode(taxSourceNote, forKey: .taxSourceNote)
        try container.encode(insuranceAnnual, forKey: .insuranceAnnual)
        try container.encode(hydroMonthly, forKey: .hydroMonthly)
        try container.encode(internetMonthly, forKey: .internetMonthly)
        try container.encode(heatPumpMonthly, forKey: .heatPumpMonthly)
        try container.encode(waterMonthly, forKey: .waterMonthly)
        try container.encode(otherMonthly, forKey: .otherMonthly)
        try container.encode(waterIncludedInStrata, forKey: .waterIncludedInStrata)
        try container.encode(levyMode, forKey: .levyMode)
        try container.encode(levyPercent, forKey: .levyPercent)
        try container.encode(levyFixedAnnual, forKey: .levyFixedAnnual)
        try container.encode(levyUsesFloor, forKey: .levyUsesFloor)
        try container.encode(levyFloorAnnual, forKey: .levyFloorAnnual)
        try container.encode(includeOpportunity, forKey: .includeOpportunity)
        try container.encode(riskFreePercent, forKey: .riskFreePercent)
        try container.encode(projection, forKey: .projection)
    }
}

nonisolated struct PropertyLocation: Codable, Equatable {
    var query: String = ""
    var buildingName: String = ""
    var address: String = ""
    var city: String = ""
    var provinceCode: String = ""
    var postalCode: String = ""
    var latitude: Double? = nil
    var longitude: Double? = nil
    var appliedBaselineID: String? = nil

    var singleLine: String {
        if !address.isEmpty { return address }
        return [buildingName, city, provinceCode, postalCode]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var placeLine: String {
        let cityLine = [city, provinceCode].filter { !$0.isEmpty }.joined(separator: " ")
        let line = [cityLine, postalCode].filter { !$0.isEmpty }.joined(separator: " · ")
        return line.isEmpty ? L10n.t("place.missing") : line
    }

    private enum CodingKeys: String, CodingKey {
        case query, buildingName, address, city, provinceCode, postalCode, latitude, longitude, appliedBaselineID
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        query = container.soft(.query, "")
        buildingName = container.soft(.buildingName, "")
        address = container.soft(.address, "")
        city = container.soft(.city, "")
        provinceCode = container.soft(.provinceCode, "")
        postalCode = container.soft(.postalCode, "")
        latitude = container.optional(.latitude)
        longitude = container.optional(.longitude)
        appliedBaselineID = container.optional(.appliedBaselineID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(query, forKey: .query)
        try container.encode(buildingName, forKey: .buildingName)
        try container.encode(address, forKey: .address)
        try container.encode(city, forKey: .city)
        try container.encode(provinceCode, forKey: .provinceCode)
        try container.encode(postalCode, forKey: .postalCode)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(appliedBaselineID, forKey: .appliedBaselineID)
    }
}

nonisolated struct CondoProperty: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = "新建公寓"
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var location: PropertyLocation = PropertyLocation()
    var inputs: CostInputs = CostInputs()
    var notes: String = ""

    private enum CodingKeys: String, CodingKey {
        case id, name, createdAt, updatedAt, location, inputs, notes
    }

    init() {
        name = L10n.t("property.new")
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.soft(.id, UUID())
        name = container.soft(.name, L10n.t("property.new"))
        createdAt = container.soft(.createdAt, .now)
        updatedAt = container.soft(.updatedAt, .now)
        location = container.soft(.location, PropertyLocation())
        inputs = container.soft(.inputs, CostInputs())
        notes = container.soft(.notes, "")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(location, forKey: .location)
        try container.encode(inputs, forKey: .inputs)
        try container.encode(notes, forKey: .notes)
    }
}

nonisolated struct MarketSnapshot: Codable, Equatable {
    var fetchedAt: Date? = nil
    var postedFiveYearMortgage: Double? = nil
    var fiveYearBond: Double? = nil
    var policyRate: Double? = nil
    var primeRate: Double? = nil
    var cpiYoY: Double? = nil
    var policyAsOf: String? = nil
    var primeAsOf: String? = nil
    var bondAsOf: String? = nil
    var mortgageAsOf: String? = nil
    var fetchError: String? = nil
    var statusMessage: String = ""

    var discountedMortgage: Double? {
        fiveYearBond.map { (($0 + 1.5) * 100).rounded() / 100 }
    }

    private enum CodingKeys: String, CodingKey {
        case fetchedAt, postedFiveYearMortgage, fiveYearBond, policyRate, primeRate, cpiYoY
        case policyAsOf, primeAsOf, bondAsOf, mortgageAsOf, fetchError, statusMessage
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fetchedAt = container.optional(.fetchedAt)
        postedFiveYearMortgage = container.optional(.postedFiveYearMortgage)
        fiveYearBond = container.optional(.fiveYearBond)
        policyRate = container.optional(.policyRate)
        primeRate = container.optional(.primeRate)
        cpiYoY = container.optional(.cpiYoY)
        policyAsOf = container.optional(.policyAsOf)
        primeAsOf = container.optional(.primeAsOf)
        bondAsOf = container.optional(.bondAsOf)
        mortgageAsOf = container.optional(.mortgageAsOf)
        fetchError = container.optional(.fetchError)
        statusMessage = container.soft(.statusMessage, "")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(fetchedAt, forKey: .fetchedAt)
        try container.encodeIfPresent(postedFiveYearMortgage, forKey: .postedFiveYearMortgage)
        try container.encodeIfPresent(fiveYearBond, forKey: .fiveYearBond)
        try container.encodeIfPresent(policyRate, forKey: .policyRate)
        try container.encodeIfPresent(primeRate, forKey: .primeRate)
        try container.encodeIfPresent(cpiYoY, forKey: .cpiYoY)
        try container.encodeIfPresent(policyAsOf, forKey: .policyAsOf)
        try container.encodeIfPresent(primeAsOf, forKey: .primeAsOf)
        try container.encodeIfPresent(bondAsOf, forKey: .bondAsOf)
        try container.encodeIfPresent(mortgageAsOf, forKey: .mortgageAsOf)
        try container.encodeIfPresent(fetchError, forKey: .fetchError)
        try container.encode(statusMessage, forKey: .statusMessage)
    }
}

nonisolated struct PortfolioDocument: Codable, Equatable {
    var schemaVersion: Int = 2
    var exportedAt: Date? = nil
    var snapshot: MarketSnapshot = MarketSnapshot()
    var properties: [CondoProperty] = []
    var houses: [HouseEstimate] = []

    static let currentSchema = 2

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, exportedAt, snapshot, properties, houses
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = container.soft(.schemaVersion, 1)
        exportedAt = container.optional(.exportedAt)
        snapshot = container.soft(.snapshot, MarketSnapshot())
        properties = container.soft(.properties, [])
        houses = container.soft(.houses, [])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(exportedAt, forKey: .exportedAt)
        try container.encode(snapshot, forKey: .snapshot)
        try container.encode(properties, forKey: .properties)
        try container.encode(houses, forKey: .houses)
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

nonisolated struct CostLine: Identifiable, Equatable {
    var id: String
    var group: CostGroup
    var title: String
    var detail: String
    var amount: Double
}

nonisolated struct YearResult: Identifiable, Equatable {
    var id: Int { year }
    var year: Int
    var lines: [CostLine]
    var netAnnual: Double
    var cashAnnual: Double
    var mortgagePrincipal: Double
    var mortgagePaymentAnnual: Double
    var monthlyPayment: Double
    var endingBalance: Double
    var assessedValue: Double
    var deductible: Double
    var ratePercentUsed: Double
    var loanYearIndex: Int?
}

nonisolated struct Funding: Equatable {
    var price: Double
    var downPayment: Double
    var minimumDown: Double
    var baseLoan: Double
    var premiumRate: Double
    var premium: Double
    var premiumTax: Double
    var totalLoan: Double
    var ltv: Double
    var insured: Bool
    var monthlyPayment: Double
}

nonisolated struct Projection: Equatable {
    var funding: Funding
    var years: [YearResult]
    var warnings: [String]

    func year(_ year: Int) -> YearResult? {
        years.first { $0.year == year }
    }
}

private extension KeyedDecodingContainer {
    nonisolated func soft<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }

    nonisolated func optional<T: Decodable>(_ key: Key) -> T? {
        guard contains(key) else { return nil }
        return try? decode(T.self, forKey: key)
    }
}
