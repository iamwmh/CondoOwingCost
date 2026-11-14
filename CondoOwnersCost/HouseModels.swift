//
//  HouseModels.swift
//  CondoOwnersCost
//

import Foundation

nonisolated enum HouseKind: String, Codable, CaseIterable, Equatable {
    case detached
    case townhouse

    var titleKey: String {
        switch self {
        case .detached: "house.kind.detached"
        case .townhouse: "house.kind.townhouse"
        }
    }
}

nonisolated enum HeatingSystem: String, Codable, CaseIterable, Equatable {
    case gasForcedAir
    case heatPump
    case electricBaseboard
    case radiant

    var titleKey: String {
        switch self {
        case .gasForcedAir: "house.heat.gas"
        case .heatPump: "house.heat.pump"
        case .electricBaseboard: "house.heat.base"
        case .radiant: "house.heat.radiant"
        }
    }
}

nonisolated enum RoofMaterial: String, Codable, CaseIterable, Equatable {
    case asphalt
    case metal
    case wood

    var titleKey: String {
        switch self {
        case .asphalt: "house.roof.asphalt"
        case .metal: "house.roof.metal"
        case .wood: "house.roof.wood"
        }
    }
}

nonisolated enum WaterBilling: String, Codable, CaseIterable, Equatable {
    case metered
    case flat

    var titleKey: String {
        switch self {
        case .metered: "house.metered"
        case .flat: "house.flat"
        }
    }
}

nonisolated enum MaintenanceMode: String, Codable, CaseIterable, Equatable {
    case percentOfValue
    case perSqft

    var titleKey: String {
        switch self {
        case .percentOfValue: "house.maint.pctMode"
        case .perSqft: "house.maint.psfMode"
        }
    }
}

nonisolated struct HouseEstimate: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var kind: HouseKind = .detached
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var city: String = ""
    var location: PropertyLocation = PropertyLocation()
    var estimatesAreSuggested: Bool = false
    var notes: String = ""

    var purchasePrice: Double = 0
    var downPaymentPercent: Double = 20
    var payInFull: Bool = false
    var mortgageRatePercent: Double = 4.5
    var amortYears: Int = 25
    var occupancy: Occupancy = .principal

    var assessedValue: Double = 0
    var propertyTaxPercent: Double = 0.35
    var useDirectTax: Bool = false
    var directTaxAnnual: Double = 0

    var waterAnnual: Double = 0
    var sewerAnnual: Double = 0
    var garbageAnnual: Double = 0
    var waterBilling: WaterBilling = .metered

    var finishedSqft: Double = 0
    var lotSqft: Double = 0
    var yearBuilt: Int = 1990
    var yearRenovated: Int = 1990
    var roof: RoofMaterial = .asphalt
    var heating: HeatingSystem = .gasForcedAir

    var enerGuideGJ: Double = 0
    var useEnerGuide: Bool = false
    var heatingDegreeDays: Double = 2800

    var pool: Bool = false
    var hotTub: Bool = false
    var centralAC: Bool = false
    var evCharger: Bool = false

    var useUtilityBills: Bool = false
    var hydroMonthly: Double = 0
    var gasMonthly: Double = 0

    var hasStrata: Bool = false
    var strataMonthly: Double = 0
    var strataIncludesHeat: Bool = false
    var strataIncludesHotWater: Bool = false
    var strataIncludesGas: Bool = false
    var strataIncludesWater: Bool = false
    var strataIncludesGardening: Bool = false
    var crfRatioPercent: Double = 50
    var complexUnits: Int = 1
    var levyPercent: Double = 15

    var useQuotedInsurance: Bool = false
    var quotedInsuranceAnnual: Double = 0
    var distantFireProtection: Bool = false
    var floodplain: Bool = false
    var wildfire: Bool = false
    var seismic: Bool = false
    var aluminumWiring: Bool = false
    var polyB: Bool = false
    var leadPlumbing: Bool = false

    var maintenanceMode: MaintenanceMode = .percentOfValue
    var maintenancePercent: Double = 1
    var maintenancePerSqft: Double = 1.5

    var grossIncomeAnnual: Double = 0
    var otherDebtMonthly: Double = 0

    static func make(kind: HouseKind) -> HouseEstimate {
        var house = HouseEstimate()
        house.kind = kind
        house.name = L10n.t(kind == .detached ? "house.new.detached" : "house.new.townhouse")
        house.purchasePrice = kind == .detached ? 1_600_000 : 1_100_000
        house.assessedValue = house.purchasePrice
        house.finishedSqft = kind == .detached ? 2_200 : 1_600
        house.lotSqft = kind == .detached ? 4_000 : 1_200
        house.yearBuilt = 1998
        house.yearRenovated = 2016
        house.hasStrata = kind == .townhouse
        house.strataMonthly = kind == .townhouse ? 420 : 0
        house.complexUnits = kind == .townhouse ? 24 : 1
        house.maintenancePercent = kind == .detached ? 1 : 0.4
        house.maintenancePerSqft = kind == .detached ? 1.5 : 0.75
        house.waterAnnual = 480
        house.sewerAnnual = 360
        house.garbageAnnual = 280
        house.centralAC = true
        house.estimatesAreSuggested = true
        return house
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, createdAt, updatedAt, city, location, estimatesAreSuggested, notes
        case purchasePrice, downPaymentPercent, payInFull, mortgageRatePercent, amortYears, occupancy
        case assessedValue, propertyTaxPercent, useDirectTax, directTaxAnnual
        case waterAnnual, sewerAnnual, garbageAnnual, waterBilling
        case finishedSqft, lotSqft, yearBuilt, yearRenovated, roof, heating
        case enerGuideGJ, useEnerGuide, heatingDegreeDays
        case pool, hotTub, centralAC, evCharger
        case useUtilityBills, hydroMonthly, gasMonthly
        case hasStrata, strataMonthly, strataIncludesHeat, strataIncludesHotWater
        case strataIncludesGas, strataIncludesWater, strataIncludesGardening
        case crfRatioPercent, complexUnits, levyPercent
        case useQuotedInsurance, quotedInsuranceAnnual
        case distantFireProtection, floodplain, wildfire, seismic, aluminumWiring, polyB, leadPlumbing
        case maintenanceMode, maintenancePercent, maintenancePerSqft
        case grossIncomeAnnual, otherDebtMonthly
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        id = container.take(.id, id)
        name = container.take(.name, name)
        kind = container.take(.kind, kind)
        createdAt = container.take(.createdAt, createdAt)
        updatedAt = container.take(.updatedAt, updatedAt)
        city = container.take(.city, city)
        location = container.take(.location, location)
        if location.city.isEmpty { location.city = city }
        city = location.city
        estimatesAreSuggested = container.take(.estimatesAreSuggested, estimatesAreSuggested)
        notes = container.take(.notes, notes)
        purchasePrice = container.take(.purchasePrice, purchasePrice)
        downPaymentPercent = container.take(.downPaymentPercent, downPaymentPercent)
        payInFull = container.take(.payInFull, payInFull)
        mortgageRatePercent = container.take(.mortgageRatePercent, mortgageRatePercent)
        amortYears = container.take(.amortYears, amortYears)
        occupancy = container.take(.occupancy, occupancy)
        assessedValue = container.take(.assessedValue, assessedValue)
        propertyTaxPercent = container.take(.propertyTaxPercent, propertyTaxPercent)
        useDirectTax = container.take(.useDirectTax, useDirectTax)
        directTaxAnnual = container.take(.directTaxAnnual, directTaxAnnual)
        waterAnnual = container.take(.waterAnnual, waterAnnual)
        sewerAnnual = container.take(.sewerAnnual, sewerAnnual)
        garbageAnnual = container.take(.garbageAnnual, garbageAnnual)
        waterBilling = container.take(.waterBilling, waterBilling)
        finishedSqft = container.take(.finishedSqft, finishedSqft)
        lotSqft = container.take(.lotSqft, lotSqft)
        yearBuilt = container.take(.yearBuilt, yearBuilt)
        yearRenovated = container.take(.yearRenovated, yearRenovated)
        roof = container.take(.roof, roof)
        heating = container.take(.heating, heating)
        enerGuideGJ = container.take(.enerGuideGJ, enerGuideGJ)
        useEnerGuide = container.take(.useEnerGuide, useEnerGuide)
        heatingDegreeDays = container.take(.heatingDegreeDays, heatingDegreeDays)
        pool = container.take(.pool, pool)
        hotTub = container.take(.hotTub, hotTub)
        centralAC = container.take(.centralAC, centralAC)
        evCharger = container.take(.evCharger, evCharger)
        useUtilityBills = container.take(.useUtilityBills, useUtilityBills)
        hydroMonthly = container.take(.hydroMonthly, hydroMonthly)
        gasMonthly = container.take(.gasMonthly, gasMonthly)
        hasStrata = container.take(.hasStrata, hasStrata)
        strataMonthly = container.take(.strataMonthly, strataMonthly)
        strataIncludesHeat = container.take(.strataIncludesHeat, strataIncludesHeat)
        strataIncludesHotWater = container.take(.strataIncludesHotWater, strataIncludesHotWater)
        strataIncludesGas = container.take(.strataIncludesGas, strataIncludesGas)
        strataIncludesWater = container.take(.strataIncludesWater, strataIncludesWater)
        strataIncludesGardening = container.take(.strataIncludesGardening, strataIncludesGardening)
        crfRatioPercent = container.take(.crfRatioPercent, crfRatioPercent)
        complexUnits = container.take(.complexUnits, complexUnits)
        levyPercent = container.take(.levyPercent, levyPercent)
        useQuotedInsurance = container.take(.useQuotedInsurance, useQuotedInsurance)
        quotedInsuranceAnnual = container.take(.quotedInsuranceAnnual, quotedInsuranceAnnual)
        distantFireProtection = container.take(.distantFireProtection, distantFireProtection)
        floodplain = container.take(.floodplain, floodplain)
        wildfire = container.take(.wildfire, wildfire)
        seismic = container.take(.seismic, seismic)
        aluminumWiring = container.take(.aluminumWiring, aluminumWiring)
        polyB = container.take(.polyB, polyB)
        leadPlumbing = container.take(.leadPlumbing, leadPlumbing)
        maintenanceMode = container.take(.maintenanceMode, maintenanceMode)
        maintenancePercent = container.take(.maintenancePercent, maintenancePercent)
        maintenancePerSqft = container.take(.maintenancePerSqft, maintenancePerSqft)
        grossIncomeAnnual = container.take(.grossIncomeAnnual, grossIncomeAnnual)
        otherDebtMonthly = container.take(.otherDebtMonthly, otherDebtMonthly)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(city, forKey: .city)
        try container.encode(location, forKey: .location)
        try container.encode(estimatesAreSuggested, forKey: .estimatesAreSuggested)
        try container.encode(notes, forKey: .notes)
        try container.encode(purchasePrice, forKey: .purchasePrice)
        try container.encode(downPaymentPercent, forKey: .downPaymentPercent)
        try container.encode(payInFull, forKey: .payInFull)
        try container.encode(mortgageRatePercent, forKey: .mortgageRatePercent)
        try container.encode(amortYears, forKey: .amortYears)
        try container.encode(occupancy, forKey: .occupancy)
        try container.encode(assessedValue, forKey: .assessedValue)
        try container.encode(propertyTaxPercent, forKey: .propertyTaxPercent)
        try container.encode(useDirectTax, forKey: .useDirectTax)
        try container.encode(directTaxAnnual, forKey: .directTaxAnnual)
        try container.encode(waterAnnual, forKey: .waterAnnual)
        try container.encode(sewerAnnual, forKey: .sewerAnnual)
        try container.encode(garbageAnnual, forKey: .garbageAnnual)
        try container.encode(waterBilling, forKey: .waterBilling)
        try container.encode(finishedSqft, forKey: .finishedSqft)
        try container.encode(lotSqft, forKey: .lotSqft)
        try container.encode(yearBuilt, forKey: .yearBuilt)
        try container.encode(yearRenovated, forKey: .yearRenovated)
        try container.encode(roof, forKey: .roof)
        try container.encode(heating, forKey: .heating)
        try container.encode(enerGuideGJ, forKey: .enerGuideGJ)
        try container.encode(useEnerGuide, forKey: .useEnerGuide)
        try container.encode(heatingDegreeDays, forKey: .heatingDegreeDays)
        try container.encode(pool, forKey: .pool)
        try container.encode(hotTub, forKey: .hotTub)
        try container.encode(centralAC, forKey: .centralAC)
        try container.encode(evCharger, forKey: .evCharger)
        try container.encode(useUtilityBills, forKey: .useUtilityBills)
        try container.encode(hydroMonthly, forKey: .hydroMonthly)
        try container.encode(gasMonthly, forKey: .gasMonthly)
        try container.encode(hasStrata, forKey: .hasStrata)
        try container.encode(strataMonthly, forKey: .strataMonthly)
        try container.encode(strataIncludesHeat, forKey: .strataIncludesHeat)
        try container.encode(strataIncludesHotWater, forKey: .strataIncludesHotWater)
        try container.encode(strataIncludesGas, forKey: .strataIncludesGas)
        try container.encode(strataIncludesWater, forKey: .strataIncludesWater)
        try container.encode(strataIncludesGardening, forKey: .strataIncludesGardening)
        try container.encode(crfRatioPercent, forKey: .crfRatioPercent)
        try container.encode(complexUnits, forKey: .complexUnits)
        try container.encode(levyPercent, forKey: .levyPercent)
        try container.encode(useQuotedInsurance, forKey: .useQuotedInsurance)
        try container.encode(quotedInsuranceAnnual, forKey: .quotedInsuranceAnnual)
        try container.encode(distantFireProtection, forKey: .distantFireProtection)
        try container.encode(floodplain, forKey: .floodplain)
        try container.encode(wildfire, forKey: .wildfire)
        try container.encode(seismic, forKey: .seismic)
        try container.encode(aluminumWiring, forKey: .aluminumWiring)
        try container.encode(polyB, forKey: .polyB)
        try container.encode(leadPlumbing, forKey: .leadPlumbing)
        try container.encode(maintenanceMode, forKey: .maintenanceMode)
        try container.encode(maintenancePercent, forKey: .maintenancePercent)
        try container.encode(maintenancePerSqft, forKey: .maintenancePerSqft)
        try container.encode(grossIncomeAnnual, forKey: .grossIncomeAnnual)
        try container.encode(otherDebtMonthly, forKey: .otherDebtMonthly)
    }
}

nonisolated struct HouseResult: Equatable {
    var lines: [CostLine]
    var annual: Double
    var monthlyCash: Double
    var contractPayment: Double
    var qualifyingPayment: Double
    var qualifyingRate: Double
    var gdsHousing: Double
    var gdsQualifyingHousing: Double
    var gdsRatio: Double?
    var qualifyingGdsRatio: Double?
    var tdsRatio: Double?
    var warnings: [String]
}

private extension KeyedDecodingContainer {
    nonisolated func take<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}
