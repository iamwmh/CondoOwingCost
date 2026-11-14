//
//  HouseCostEngine.swift
//  CondoOwnersCost
//

import Foundation

nonisolated enum HouseCostEngine {
    static func evaluate(_ house: HouseEstimate) -> HouseResult {
        let price = finite(house.purchasePrice)
        let downPercent = min(100, max(0, finite(house.downPaymentPercent)))
        let down = house.payInFull ? price : price * downPercent / 100
        let baseLoan = max(0, price - down)
        let ltv = price > 0 ? baseLoan / price : 0
        let amort = max(1, min(40, house.amortYears))
        let rate = finite(house.mortgageRatePercent)
        var loan = baseLoan
        if !house.payInFull, let cmhc = cmhcRate(ltv: ltv, amortYears: amort, occupancy: house.occupancy, price: price) {
            loan = baseLoan + baseLoan * cmhc
        }
        let monthly = house.payInFull ? 0 : CostEngine.monthlyPayment(principal: loan, annualRate: rate / 100, years: amort)
        let qualifyingRate = max(rate + 2, 5.25)
        let qualifyingMonthly = house.payInFull ? 0 : CostEngine.monthlyPayment(principal: loan, annualRate: qualifyingRate / 100, years: amort)

        let tax = house.useDirectTax
            ? finite(house.directTaxAnnual)
            : finite(house.assessedValue) * finite(house.propertyTaxPercent) / 100

        let strataOn = house.kind == .townhouse || house.hasStrata
        let water = (strataOn && house.strataIncludesWater) ? 0 : finite(house.waterAnnual)
        let sewer = finite(house.sewerAnnual)
        let garbage = finite(house.garbageAnnual)
        let municipal = water + sewer + garbage
        let strata = strataOn ? finite(house.strataMonthly) * 12 : 0

        var warnings: [String] = []
        var levyRate = finite(house.levyPercent)
        if strataOn && house.crfRatioPercent < 25 {
            levyRate = max(levyRate, 25)
            warnings.append(L10n.t("house.warn.crf", house.crfRatioPercent))
        }
        if strataOn && house.complexUnits > 0 && house.complexUnits < 12 {
            warnings.append(L10n.t("house.warn.units"))
        }
        let levy = strata * levyRate / 100

        let energy = energyCost(house, strataOn: strataOn)
        let maintenance = maintenanceCost(house)
        let insurance = insuranceCost(house)

        if !house.payInFull, down + 1 < CostEngine.minimumDown(price: price) {
            warnings.append(L10n.t("house.warn.down"))
        }
        if house.polyB { warnings.append(L10n.t("house.warn.poly")) }
        if house.aluminumWiring { warnings.append(L10n.t("house.warn.alum")) }
        if house.leadPlumbing { warnings.append(L10n.t("house.warn.lead")) }
        if house.floodplain { warnings.append(L10n.t("house.warn.flood")) }
        if house.distantFireProtection { warnings.append(L10n.t("house.warn.fire")) }
        if house.wildfire { warnings.append(L10n.t("house.warn.wild")) }

        let pi = dollars(monthly * 12)
        let taxAmount = dollars(tax)
        let municipalAmount = dollars(municipal)
        let strataAmount = dollars(strata)
        let insuranceAmount = dollars(insurance)
        let energyAmount = dollars(energy.total)
        let maintenanceAmount = dollars(maintenance.total)
        let levyAmount = dollars(levy)

        let lines = [
            CostLine(id: "pi", group: .fixed, title: L10n.t("house.line.pi"), detail: piDetail(house, rate: rate, amort: amort), amount: pi),
            CostLine(id: "tax", group: .fixed, title: L10n.t("house.line.tax"), detail: taxDetail(house), amount: taxAmount),
            CostLine(id: "muni", group: .fixed, title: L10n.t("house.line.muni"), detail: L10n.t("house.detail.muni", cad(water), cad(sewer), cad(garbage)), amount: municipalAmount),
            CostLine(id: "strata", group: .fixed, title: L10n.t("house.line.strata"), detail: L10n.t("house.detail.strata", cad(house.strataMonthly)), amount: strataAmount),
            CostLine(id: "insurance", group: .variable, title: L10n.t("house.line.ins"), detail: insuranceDetail(house), amount: insuranceAmount),
            CostLine(id: "energy", group: .variable, title: L10n.t("house.line.energy"), detail: house.useUtilityBills ? L10n.t("house.detail.energy.bills") : L10n.t("house.detail.energy.model"), amount: energyAmount),
            CostLine(id: "maint", group: .capital, title: L10n.t("house.line.maint"), detail: maintenance.detail, amount: maintenanceAmount),
            CostLine(id: "levy", group: .capital, title: L10n.t("house.line.levy"), detail: L10n.t("house.detail.levy", levyRate), amount: levyAmount)
        ]

        let annual = dollars(lines.reduce(0) { $0 + $1.amount })
        let gdsHousing = dollars(monthly + tax / 12 + energy.heat / 12 + strata * 0.5 / 12)
        let gdsQualifying = dollars(qualifyingMonthly + tax / 12 + energy.heat / 12 + strata * 0.5 / 12)
        let income = finite(house.grossIncomeAnnual)
        let gdsRatio = income > 0 ? gdsHousing * 12 / income * 100 : nil
        let qualifyingGds = income > 0 ? gdsQualifying * 12 / income * 100 : nil
        let tdsRatio = income > 0 ? (gdsHousing + finite(house.otherDebtMonthly)) * 12 / income * 100 : nil
        if let gdsRatio, gdsRatio > 39 {
            warnings.append(L10n.t("house.warn.gds", gdsRatio))
        }
        if let tdsRatio, tdsRatio > 44 {
            warnings.append(L10n.t("house.warn.tds", tdsRatio))
        }

        return HouseResult(
            lines: lines,
            annual: annual,
            monthlyCash: dollars(annual / 12),
            contractPayment: dollars(monthly),
            qualifyingPayment: dollars(qualifyingMonthly),
            qualifyingRate: qualifyingRate,
            gdsHousing: gdsHousing,
            gdsQualifyingHousing: gdsQualifying,
            gdsRatio: gdsRatio,
            qualifyingGdsRatio: qualifyingGds,
            tdsRatio: tdsRatio,
            warnings: warnings
        )
    }

    private static func piDetail(_ house: HouseEstimate, rate: Double, amort: Int) -> String {
        house.payInFull ? L10n.t("house.detail.pi.cash") : L10n.t("house.detail.pi", rate, amort)
    }

    private static func taxDetail(_ house: HouseEstimate) -> String {
        if house.useDirectTax { return L10n.t("house.detail.tax.bill") }
        return L10n.t("house.detail.tax.rate", cad(house.assessedValue), house.propertyTaxPercent)
    }

    private static func insuranceDetail(_ house: HouseEstimate) -> String {
        if house.useQuotedInsurance { return L10n.t("house.detail.ins.quote") }
        return house.kind == .detached ? L10n.t("house.detail.ins.detached") : L10n.t("house.detail.ins.town")
    }

    private static func energyCost(_ house: HouseEstimate, strataOn: Bool) -> (total: Double, heat: Double) {
        if house.useUtilityBills {
            let hydro = finite(house.hydroMonthly) * 12
            let gas = finite(house.gasMonthly) * 12
            let total = hydro + gas
            let heat: Double
            switch house.heating {
            case .gasForcedAir, .radiant:
                heat = gas > 0 ? gas : total * 0.45
            case .heatPump, .electricBaseboard:
                heat = gas > 0 ? gas : hydro * 0.6
            }
            return (total, min(heat, total))
        }

        let area = max(400, finite(house.finishedSqft))
        let hdd = max(500, finite(house.heatingDegreeDays))
        let year = Calendar.current.component(.year, from: Date())
        let age = max(0, year - house.yearBuilt)
        let renovated = house.yearRenovated >= house.yearBuilt + 3
        var envelope = (renovated ? 0.82 : 1.0) * (age > 40 ? 1.18 : age > 20 ? 1.06 : 0.96)
        switch house.roof {
        case .metal: envelope *= 0.98
        case .wood: envelope *= 1.05
        case .asphalt: break
        }

        let heatGJ: Double
        var other: Double
        if house.useEnerGuide && house.enerGuideGJ > 0 {
            heatGJ = finite(house.enerGuideGJ) * 0.68
            other = finite(house.enerGuideGJ) * 0.32 * 277.778 * 0.14
        } else {
            let intensity: Double
            switch house.heating {
            case .gasForcedAir: intensity = 1
            case .heatPump: intensity = 0.42
            case .electricBaseboard: intensity = 1.12
            case .radiant: intensity = 1.05
            }
            heatGJ = area * 0.05 * (hdd / 3000) * envelope * intensity
            other = area * 0.30
        }

        var heatCost: Double
        switch house.heating {
        case .gasForcedAir, .radiant:
            heatCost = heatGJ * 18
        case .heatPump, .electricBaseboard:
            heatCost = heatGJ * 277.778 * 0.14
        }
        if strataOn && (house.strataIncludesHeat || house.strataIncludesGas) {
            heatCost = 0
        }
        if strataOn && house.strataIncludesHotWater {
            other = max(0, other - 280)
        }
        if house.pool { other += 1_800 }
        if house.hotTub { other += 480 }
        if house.centralAC { other += 420 }
        if house.evCharger { other += 720 }
        return (heatCost + other, heatCost)
    }

    private static func maintenanceCost(_ house: HouseEstimate) -> (total: Double, detail: String) {
        let price = finite(house.purchasePrice)
        let area = max(0, finite(house.finishedSqft))
        var cost: Double
        var detail: String
        if house.maintenanceMode == .percentOfValue {
            cost = price * finite(house.maintenancePercent) / 100
            detail = L10n.t("house.detail.maint.pct", house.maintenancePercent)
        } else {
            cost = area * finite(house.maintenancePerSqft)
            detail = L10n.t("house.detail.maint.psf", cad(house.maintenancePerSqft))
        }
        if house.kind == .townhouse && !house.strataIncludesGardening {
            cost += max(500, finite(house.lotSqft) * 0.06)
            detail += " " + L10n.t("house.detail.garden")
        }
        return (cost, detail)
    }

    private static func insuranceCost(_ house: HouseEstimate) -> Double {
        if house.useQuotedInsurance { return finite(house.quotedInsuranceAnnual) }
        let price = finite(house.purchasePrice)
        var base = house.kind == .detached ? max(1_400, price * 0.0022) : max(780, price * 0.00115)
        switch house.roof {
        case .metal: base *= 0.92
        case .wood: base *= 1.20
        case .asphalt: break
        }
        let year = Calendar.current.component(.year, from: Date())
        if year - house.yearBuilt > 40 { base *= 1.10 }
        var multiplier = 1.0
        if house.distantFireProtection { multiplier *= 1.20 }
        if house.floodplain { multiplier *= 1.35 }
        if house.wildfire { multiplier *= 1.28 }
        if house.seismic { multiplier *= 1.12 }
        if house.aluminumWiring { multiplier *= 1.35 }
        if house.polyB { multiplier *= 1.45 }
        if house.leadPlumbing { multiplier *= 1.08 }
        return base * min(multiplier, 3)
    }

    private static func cmhcRate(ltv: Double, amortYears: Int, occupancy: Occupancy, price: Double) -> Double? {
        guard occupancy == .principal, price > 0, price < 1_500_000 else { return nil }
        let rounded = (ltv * 1_000_000).rounded() / 1_000_000
        guard rounded > 0.80, rounded <= 0.95 else { return nil }
        var rate: Double
        if rounded <= 0.85 { rate = 0.028 }
        else if rounded <= 0.90 { rate = 0.031 }
        else { rate = 0.040 }
        if amortYears > 25 { rate += 0.002 }
        return rate
    }

    private static func finite(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    private static func dollars(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        let rounded = (value * 100).rounded() / 100
        return abs(rounded) < 0.004 ? 0 : rounded
    }

    private static func cad(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CAD"
        formatter.locale = Locale(identifier: "en_CA")
        let cents = abs(value) < 100 && value != 0
        formatter.minimumFractionDigits = cents ? 2 : 0
        formatter.maximumFractionDigits = cents ? 2 : 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}
