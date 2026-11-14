//
//  PropertyEditing.swift
//  CondoOwnersCost
//

import Foundation

nonisolated extension CondoProperty {
    mutating func setPurchasePrice(_ value: Double) {
        inputs.purchasePrice = max(0, value)
        if !inputs.assessedLocked {
            inputs.assessedValue = inputs.purchasePrice
        }
        syncDownPayment()
    }

    mutating func setAssessedValue(_ value: Double) {
        inputs.assessedValue = max(0, value)
        inputs.assessedLocked = true
    }

    mutating func setDownPercent(_ value: Double) {
        inputs.downPaymentMode = .percent
        inputs.downPaymentPercent = min(100, max(0, value))
        inputs.downPaymentAmount = inputs.purchasePrice * inputs.downPaymentPercent / 100
    }

    mutating func setDownAmount(_ value: Double) {
        inputs.downPaymentMode = .amount
        inputs.downPaymentAmount = min(max(0, value), max(inputs.purchasePrice, 0))
        if inputs.purchasePrice > 0 {
            inputs.downPaymentPercent = inputs.downPaymentAmount / inputs.purchasePrice * 100
        }
    }

    mutating func setTaxPercent(_ value: Double) {
        let next = max(0, value)
        guard abs(next - inputs.propertyTaxPercent) > 0.0000001 else { return }
        inputs.propertyTaxPercent = next
        inputs.taxRateOfficial = false
        inputs.usesPlaceholderCosts = false
        inputs.taxSourceNote = "manual"
    }

    mutating func apply(place: PlaceCandidate) {
        location.query = place.title
        location.buildingName = place.title
        location.address = place.address
        location.city = place.city
        if !place.provinceCode.isEmpty {
            location.provinceCode = place.provinceCode
        }
        if !place.postalCode.isEmpty {
            location.postalCode = place.postalCode
        }
        location.latitude = place.latitude
        location.longitude = place.longitude
        if L10n.isDefaultName(name) {
            name = place.title
        }
        if inputs.usesPlaceholderCosts, let baseline = CityBaselines.match(city: location.city, province: location.provinceCode) {
            apply(baseline: baseline, includingStrata: true)
        }
    }

    mutating func apply(baseline: CityBaseline, includingStrata: Bool) {
        inputs.propertyTaxPercent = baseline.propertyTaxPercent
        inputs.taxRateOfficial = baseline.taxIsOfficial
        inputs.taxSourceNote = "baseline"
        location.appliedBaselineID = baseline.id
        if location.city.isEmpty { location.city = baseline.localizedName }
        if location.provinceCode.isEmpty { location.provinceCode = baseline.provinceCode }
        inputs.insuranceAnnual = baseline.insuranceAnnual
        inputs.hydroMonthly = baseline.hydroMonthly
        inputs.internetMonthly = baseline.internetMonthly
        if includingStrata {
            inputs.strataPerSqftMonthly = baseline.suggestedStrata(
                yearBuilt: inputs.yearBuilt,
                pool: inputs.hasPool,
                concierge: inputs.hasConcierge,
                year: CalendarYear.current
            )
            inputs.useMonthlyStrata = false
        }
        inputs.usesPlaceholderCosts = false
    }

    mutating func applyMarket(_ snapshot: MarketSnapshot, choice: MortgageChoice, includeInflation: Bool) {
        switch choice {
        case .discounted:
            if let value = snapshot.discountedMortgage {
                inputs.mortgageRatePercent = value
                inputs.renewalRatePercent = value
            }
        case .posted:
            if let value = snapshot.postedFiveYearMortgage {
                inputs.mortgageRatePercent = (value * 100).rounded() / 100
                inputs.renewalRatePercent = inputs.mortgageRatePercent
            }
        }
        if let bond = snapshot.fiveYearBond {
            inputs.riskFreePercent = (bond * 100).rounded() / 100
        }
        if includeInflation, let cpi = snapshot.cpiYoY {
            let anchor = (cpi * 100).rounded() / 100
            inputs.projection.utilitiesInflationPercent = anchor
            inputs.projection.taxRateGrowthPercent = anchor
            inputs.projection.assessmentGrowthPercent = max(anchor, 2)
            inputs.projection.strataInflationPercent = ((anchor + 1.5) * 100).rounded() / 100
            inputs.projection.insuranceInflationPercent = ((anchor + 2.5) * 100).rounded() / 100
        }
        inputs.ratesAreSuggested = false
        inputs.followBankRate = choice == .discounted
    }

    mutating func setMortgageRate(_ value: Double) {
        guard abs(value - inputs.mortgageRatePercent) > 0.0001 else { return }
        inputs.mortgageRatePercent = value
        inputs.followBankRate = false
        inputs.ratesAreSuggested = false
    }

    mutating func setRenewalRate(_ value: Double) {
        guard abs(value - inputs.renewalRatePercent) > 0.0001 else { return }
        inputs.renewalRatePercent = value
        inputs.followBankRate = false
        inputs.ratesAreSuggested = false
    }

    mutating func setRiskFree(_ value: Double) {
        guard abs(value - inputs.riskFreePercent) > 0.0001 else { return }
        inputs.riskFreePercent = value
        inputs.followBankRate = false
        inputs.ratesAreSuggested = false
    }

    mutating func setPayInFull(_ on: Bool) {
        inputs.payInFull = on
        if on {
            inputs.downPaymentPercent = 100
            inputs.downPaymentAmount = inputs.purchasePrice
        }
    }

    static func example() -> CondoProperty {
        var property = CondoProperty()
        property.name = L10n.t("property.example")
        property.notes = L10n.t("property.example.notes")
        property.location.buildingName = "Coal Harbour"
        property.location.address = "Vancouver, BC"
        property.location.city = "Vancouver"
        property.location.provinceCode = "BC"
        property.location.postalCode = ""
        property.location.latitude = 49.2902
        property.location.longitude = -123.1207
        property.location.query = "Coal Harbour Vancouver"
        property.inputs.purchasePrice = 980_000
        property.inputs.assessedValue = 980_000
        property.inputs.indoorSqft = 742
        property.inputs.yearBuilt = 2008
        property.inputs.hasConcierge = true
        property.inputs.hasPool = true
        property.inputs.downPaymentPercent = 20
        property.inputs.downPaymentAmount = 196_000
        property.inputs.marginalTaxPercent = 43
        if let baseline = CityBaselines.byID["vancouver"] {
            property.apply(baseline: baseline, includingStrata: true)
        }
        property.inputs.ratesAreSuggested = false
        property.inputs.followBankRate = false
        return property
    }

    private mutating func syncDownPayment() {
        if inputs.downPaymentMode == .percent {
            inputs.downPaymentAmount = inputs.purchasePrice * inputs.downPaymentPercent / 100
        } else if inputs.purchasePrice > 0 {
            inputs.downPaymentPercent = min(100, inputs.downPaymentAmount / inputs.purchasePrice * 100)
        }
    }
}
