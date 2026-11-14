//
//  HouseEditing.swift
//  CondoOwnersCost
//

import Foundation

nonisolated struct PlaceCandidate: Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var subtitle: String
    var latitude: Double
    var longitude: Double
    var city: String
    var provinceCode: String
    var postalCode: String
    var address: String
}

nonisolated enum ClimateEstimate {
    /// Approximate annual heating degree days for a postal climate band.
    /// These are planning bands, not a reading from a weather station.
    static func heatingDegreeDays(postal: String, province: String) -> Double {
        let compact = postal.uppercased().filter { $0.isLetter || $0.isNumber }
        let letter = compact.first
        let fsa = String(compact.prefix(2))
        switch letter {
        case "V":
            if fsa == "V0" || fsa == "V1" || fsa == "V2" { return 4500 }
            return 2900
        case "T":
            if fsa == "T5" || fsa == "T6" || fsa == "T8" || fsa == "T9" { return 5700 }
            return 5000
        case "S": return 5600
        case "R": return 5700
        case "M": return 3600
        case "L", "N": return 3900
        case "K": return 4500
        case "P": return 5500
        case "H", "J": return 4500
        case "G": return 5200
        case "B": return 4000
        case "C": return 4600
        case "E": return 4700
        case "A": return 4800
        case "Y": return 8000
        case "X": return 8500
        default:
            switch province {
            case "BC": return 3000
            case "AB": return 5200
            case "SK", "MB": return 5600
            case "ON": return 4000
            case "QC": return 4700
            case "NS", "NB", "PE": return 4300
            case "NL": return 4800
            default: return 4000
            }
        }
    }

    static func heating(province: String) -> HeatingSystem {
        province == "QC" ? .electricBaseboard : .gasForcedAir
    }
}

nonisolated extension HouseEstimate {
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
        city = location.city
        if L10n.isDefaultName(name) {
            name = place.title
        }
        if estimatesAreSuggested {
            applyMatchedEstimates()
        }
    }

    mutating func apply(baseline: CityBaseline) {
        location.appliedBaselineID = baseline.id
        if location.city.isEmpty { location.city = baseline.localizedName }
        if location.provinceCode.isEmpty { location.provinceCode = baseline.provinceCode }
        city = location.city
        propertyTaxPercent = baseline.propertyTaxPercent
        useDirectTax = false
        if !useUtilityBills {
            heatingDegreeDays = ClimateEstimate.heatingDegreeDays(postal: location.postalCode, province: location.provinceCode)
            heating = ClimateEstimate.heating(province: location.provinceCode)
        }
        seismic = location.provinceCode == "BC"
        waterBilling = .metered
        if kind == .townhouse || hasStrata {
            let perSqft = baseline.suggestedStrata(yearBuilt: yearBuilt, pool: pool, concierge: false, year: CalendarYear.current)
            let factor = kind == .townhouse ? 0.65 : 0.40
            if finishedSqft > 0 {
                strataMonthly = (finishedSqft * perSqft * factor).rounded()
            }
        }
    }

    mutating func applyMatchedEstimates() {
        guard let baseline = CityBaselines.match(city: location.city, province: location.provinceCode) else {
            if !useUtilityBills {
                heatingDegreeDays = ClimateEstimate.heatingDegreeDays(postal: location.postalCode, province: location.provinceCode)
                heating = ClimateEstimate.heating(province: location.provinceCode)
            }
            seismic = location.provinceCode == "BC"
            return
        }
        apply(baseline: baseline)
    }
}
