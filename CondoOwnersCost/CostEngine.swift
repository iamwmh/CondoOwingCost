//
//  CostEngine.swift
//  CondoOwnersCost
//

import Foundation

nonisolated enum CostEngine {
    static func project(_ property: CondoProperty) -> Projection {
        let inputs = property.inputs
        let current = CalendarYear.current
        let target = max(current, inputs.projection.targetYear)
        var warnings: [String] = []

        let price = finite(inputs.purchasePrice)
        let cash = inputs.payInFull
        var down = cash
            ? price
            : (inputs.downPaymentMode == .percent
                ? price * finite(inputs.downPaymentPercent) / 100
                : finite(inputs.downPaymentAmount))
        if down < 0 { down = 0 }
        if price > 0, down > price {
            down = price
            if !cash { warnings.append(L10n.t("warn.downCap")) }
        }
        let baseLoan = cash ? 0 : max(0, price - down)
        let ltv = price > 0 ? baseLoan / price : 0
        let minimum = minimumDown(price: price)

        if price <= 0 {
            warnings.append(L10n.t("warn.price0"))
        } else if !cash, down + 0.5 < minimum {
            warnings.append(L10n.t("warn.minDown", cad(down), cad(minimum)))
        }
        if !cash, price >= 1_500_000, down + 0.5 < price * 0.20 {
            warnings.append(L10n.t("warn.priceCap"))
        }
        if !cash, inputs.occupancy == .investment, price > 0, down + 0.5 < price * 0.20 {
            warnings.append(L10n.t("warn.rental"))
        }

        let amortYears = min(40, max(1, inputs.amortYears))
        if !cash, inputs.amortYears != amortYears {
            warnings.append(L10n.t("warn.amort"))
        }
        if !cash, inputs.mortgageRatePercent < 0 || inputs.mortgageRatePercent > 15 {
            warnings.append(L10n.t("warn.rate"))
        }

        let premiumRate = cash ? 0 : (cmhcRate(ltv: ltv, amortYears: amortYears, occupancy: inputs.occupancy, price: price) ?? 0)
        let premium = dollars(baseLoan * premiumRate)
        let salesTaxRate = CityBaselines.premiumSalesTaxRate(provinceCode: property.location.provinceCode)
        let premiumTax = dollars(premium * salesTaxRate)
        let totalLoan = cash ? 0 : (inputs.capitalizePremium ? dollars(baseLoan + premium) : baseLoan)
        if premium > 0, amortYears > 25 {
            warnings.append(L10n.t("warn.amort25"))
        }
        if !cash, inputs.amortYears > 30 {
            warnings.append(L10n.t("warn.amort30"))
        }
        if inputs.indoorSqft <= 0, !inputs.useMonthlyStrata {
            warnings.append(L10n.t("warn.area"))
        }
        if !inputs.useDirectPropertyTax, !inputs.taxRateOfficial {
            warnings.append(L10n.t("warn.tax"))
        }
        if inputs.occupancy == .investment, inputs.marginalTaxPercent <= 0 {
            warnings.append(L10n.t("warn.mtr"))
        }

        let initialRate = finite(inputs.mortgageRatePercent) / 100
        let renewalRate = (inputs.renewalUsesInitialRate ? finite(inputs.mortgageRatePercent) : finite(inputs.renewalRatePercent)) / 100
        let schedule: [Int: LoanSlice] = cash ? [:] : amortize(
            loan: totalLoan,
            initialRate: initialRate,
            amortYears: amortYears,
            startYear: inputs.mortgageStartYear,
            renewalEvery: max(0, inputs.renewalEveryYears),
            renewalRate: renewalRate,
            throughYear: target
        )

        let opportunityBase = cash ? price : (down + premiumTax + (inputs.capitalizePremium ? 0 : premium))
        var years: [YearResult] = []
        if current <= target {
            for year in current...target {
                years.append(makeYear(
                    year: year,
                    current: current,
                    property: property,
                    slice: schedule[year],
                    premium: premium,
                    premiumTax: premiumTax,
                    totalLoan: totalLoan,
                    opportunityBase: opportunityBase,
                    amortYears: amortYears
                ))
            }
        }

        let currentSlice = schedule[current] ?? schedule[inputs.mortgageStartYear]
        let funding = Funding(
            price: price,
            downPayment: dollars(down),
            minimumDown: dollars(minimum),
            baseLoan: dollars(baseLoan),
            premiumRate: premiumRate,
            premium: premium,
            premiumTax: premiumTax,
            totalLoan: dollars(totalLoan),
            ltv: ltv,
            insured: premium > 0,
            monthlyPayment: currentSlice?.monthly ?? 0
        )
        return Projection(funding: funding, years: years, warnings: warnings)
    }

    static func monthlyPayment(principal: Double, annualRate: Double, years: Int) -> Double {
        let months = years * 12
        guard principal > 0, months > 0 else { return 0 }
        let monthlyRate = annualRate / 12
        if monthlyRate <= 0 { return principal / Double(months) }
        let growth = pow(1 + monthlyRate, Double(months))
        return principal * monthlyRate * growth / (growth - 1)
    }

    private static func makeYear(
        year: Int,
        current: Int,
        property: CondoProperty,
        slice: LoanSlice?,
        premium: Double,
        premiumTax: Double,
        totalLoan: Double,
        opportunityBase: Double,
        amortYears: Int
    ) -> YearResult {
        let inputs = property.inputs
        let offset = year - current
        let growth = inputs.projection
        let assessed = grow(finite(inputs.assessedValue), growth.assessmentGrowthPercent, offset)
        let propertyTax: Double
        let taxDetail: String
        if inputs.useDirectPropertyTax {
            propertyTax = grow(grow(finite(inputs.directPropertyTaxAnnual), growth.assessmentGrowthPercent, offset), growth.taxRateGrowthPercent, offset)
            taxDetail = offset == 0
                ? L10n.t("detail.tax.bill", cad(inputs.directPropertyTaxAnnual))
                : L10n.t("detail.tax.bill.grow", offset, percent(growth.assessmentGrowthPercent), percent(growth.taxRateGrowthPercent))
        } else {
            let rate = grow(finite(inputs.propertyTaxPercent) / 100, growth.taxRateGrowthPercent, offset)
            propertyTax = assessed * rate
            taxDetail = L10n.t("detail.tax.rate", cad(assessed), percent(rate * 100, digits: 4))
        }

        let strataBase = inputs.useMonthlyStrata
            ? finite(inputs.strataMonthly) * 12
            : finite(inputs.strataPerSqftMonthly) * finite(inputs.indoorSqft) * 12
        let strata = grow(strataBase, growth.strataInflationPercent, offset)
        let strataDetail = inputs.useMonthlyStrata
            ? L10n.t("detail.strata.month", cad(inputs.strataMonthly), percent(growth.strataInflationPercent), year)
            : L10n.t("detail.strata.psf", formatArea(inputs.indoorSqft), String(format: "%.2f", inputs.strataPerSqftMonthly), percent(growth.strataInflationPercent))

        let insurance = grow(finite(inputs.insuranceAnnual), growth.insuranceInflationPercent, offset)
        let utilityMonthly = finite(inputs.hydroMonthly)
            + finite(inputs.internetMonthly)
            + finite(inputs.otherMonthly)
            + (inputs.hasHeatPump ? finite(inputs.heatPumpMonthly) : 0)
            + (inputs.waterIncludedInStrata ? 0 : finite(inputs.waterMonthly))
        let utilities = grow(utilityMonthly * 12, growth.utilitiesInflationPercent, offset)
        let heat = inputs.hasHeatPump ? L10n.t(inputs.waterIncludedInStrata ? "detail.heat" : "detail.heat.alt") : ""
        let utilityDetail = inputs.waterIncludedInStrata
            ? L10n.t("detail.util.in", heat, percent(growth.utilitiesInflationPercent))
            : L10n.t("detail.util.out", heat, percent(growth.utilitiesInflationPercent))

        let levyRaw: Double
        let levyDetail: String
        switch inputs.levyMode {
        case .percentOfStrata:
            levyRaw = strata * finite(inputs.levyPercent) / 100
            levyDetail = L10n.t("detail.levy.pct", percent(inputs.levyPercent))
        case .fixedAnnual:
            levyRaw = grow(finite(inputs.levyFixedAnnual), growth.strataInflationPercent, offset)
            levyDetail = L10n.t("detail.levy.fixed", percent(growth.strataInflationPercent))
        }
        let floor = grow(finite(inputs.levyFloorAnnual), growth.strataInflationPercent, offset)
        let levy = inputs.levyUsesFloor ? max(levyRaw, floor) : levyRaw
        let levyText = inputs.levyUsesFloor && floor > levyRaw + 0.01
            ? levyDetail + " " + L10n.t("detail.levy.floor", cad(floor))
            : levyDetail + " " + L10n.t("detail.levy.note")

        let withinLoan = slice != nil
        let loanInsurance: Double
        if withinLoan, premium > 0 || premiumTax > 0 {
            let principalShare = inputs.capitalizePremium && totalLoan > 0
                ? (slice?.principal ?? 0) * (premium / totalLoan)
                : premium / Double(amortYears)
            loanInsurance = principalShare + premiumTax / Double(amortYears)
        } else {
            loanInsurance = 0
        }

        let interest = slice?.interest ?? 0
        let loanIndex = slice.map { _ in year - inputs.mortgageStartYear + 1 }
        let interestDetail: String
        if inputs.payInFull {
            interestDetail = L10n.t("detail.interest.cash")
        } else if let slice, let loanIndex {
            interestDetail = L10n.t("detail.interest", loanIndex, percent(slice.rate * 100), cad(slice.monthly), cad(slice.principal), cad(slice.balance))
        } else if year < inputs.mortgageStartYear {
            interestDetail = L10n.t("detail.interest.future", inputs.mortgageStartYear)
        } else {
            interestDetail = L10n.t("detail.interest.done", inputs.mortgageStartYear + amortYears - 1)
        }

        let insuranceDetail: String
        if inputs.capitalizePremium, premium > 0 {
            insuranceDetail = L10n.t("detail.cmhc.in", cad(premium), cad(premiumTax), amortYears)
        } else if premium > 0 {
            insuranceDetail = L10n.t("detail.cmhc.out", cad(premium), cad(premiumTax), amortYears)
        } else {
            insuranceDetail = L10n.t("detail.cmhc.none")
        }

        let riskRate = finite(inputs.riskFreePercent) / 100
        let opportunity = inputs.includeOpportunity ? opportunityBase * riskRate : 0
        let opportunityDetail = inputs.includeOpportunity
            ? L10n.t("detail.opp", cad(opportunityBase), percent(inputs.riskFreePercent))
            : L10n.t("detail.opp.off")

        var cmhcDeduction = 0.0
        if inputs.occupancy == .investment, let loanIndex, loanIndex <= 5, premium + premiumTax > 0 {
            cmhcDeduction = (premium + premiumTax) / 5
        }
        let deductibleBase = interest + propertyTax + strata + insurance + utilities + cmhcDeduction
        let taxSavings = inputs.occupancy == .investment ? deductibleBase * finite(inputs.marginalTaxPercent) / 100 : 0
        let savingsDetail: String
        if inputs.occupancy == .principal {
            savingsDetail = L10n.t("detail.save.pre")
        } else {
            let extra = cmhcDeduction > 0 ? L10n.t("detail.save.cmhc") : ""
            savingsDetail = L10n.t("detail.save.rent", cad(deductibleBase), percent(inputs.marginalTaxPercent), extra)
        }

        var lines: [CostLine] = [
            CostLine(id: "interest", group: .fixed, title: L10n.t("line.interest"), detail: interestDetail, amount: interest),
            CostLine(id: "tax", group: .fixed, title: L10n.t("line.tax"), detail: taxDetail, amount: propertyTax),
            CostLine(id: "strata", group: .fixed, title: L10n.t("line.strata"), detail: strataDetail, amount: strata),
            CostLine(id: "insurance", group: .variable, title: L10n.t("line.insurance"), detail: L10n.t("detail.ins", percent(growth.insuranceInflationPercent)), amount: insurance),
            CostLine(id: "utilities", group: .variable, title: L10n.t("line.utilities"), detail: utilityDetail, amount: utilities),
            CostLine(id: "levy", group: .variable, title: L10n.t("line.levy"), detail: levyText, amount: levy)
        ]
        if premium > 0 || premiumTax > 0 {
            lines.insert(
                CostLine(id: "cmhc", group: .variable, title: L10n.t("line.cmhc"), detail: insuranceDetail, amount: loanInsurance),
                at: 1
            )
        }
        let opportunityTitle = inputs.payInFull ? L10n.t("line.opportunity.cash") : L10n.t("line.opportunity")
        lines.append(CostLine(id: "opportunity", group: .capital, title: opportunityTitle, detail: opportunityDetail, amount: opportunity))
        lines.append(CostLine(id: "tax-savings", group: .capital, title: L10n.t("line.savings"), detail: savingsDetail, amount: -taxSavings))

        let rounded = lines.map { line -> CostLine in
            var copy = line
            copy.amount = dollars(line.amount)
            return copy
        }
        let net = dollars(rounded.reduce(0) { $0 + $1.amount })
        let opportunityRounded = rounded.first { $0.id == "opportunity" }?.amount ?? 0
        return YearResult(
            year: year,
            lines: rounded,
            netAnnual: net,
            cashAnnual: dollars(net - opportunityRounded),
            mortgagePrincipal: dollars(slice?.principal ?? 0),
            mortgagePaymentAnnual: dollars(slice?.paid ?? 0),
            monthlyPayment: dollars(slice?.monthly ?? 0),
            endingBalance: dollars(slice?.balance ?? 0),
            assessedValue: dollars(assessed),
            deductible: dollars(inputs.occupancy == .investment ? deductibleBase : 0),
            ratePercentUsed: (slice?.rate ?? 0) * 100,
            loanYearIndex: loanIndex
        )
    }

    private struct LoanSlice {
        var interest: Double
        var principal: Double
        var paid: Double
        var monthly: Double
        var balance: Double
        var rate: Double
    }

    private static func amortize(
        loan: Double,
        initialRate: Double,
        amortYears: Int,
        startYear: Int,
        renewalEvery: Int,
        renewalRate: Double,
        throughYear: Int
    ) -> [Int: LoanSlice] {
        guard loan > 1, amortYears > 0, startYear <= throughYear else { return [:] }
        var balance = loan
        var rate = initialRate
        var result: [Int: LoanSlice] = [:]
        let lastYear = min(throughYear, startYear + amortYears - 1)
        var index = 0
        while startYear + index <= lastYear, balance > 0.5 {
            if index > 0, renewalEvery > 0, index % renewalEvery == 0 {
                rate = renewalRate
            }
            let yearsLeft = max(1, amortYears - index)
            let monthly = monthlyPayment(principal: balance, annualRate: rate, years: yearsLeft)
            var interest = 0.0
            var principal = 0.0
            var paid = 0.0
            for _ in 0..<12 where balance > 0.01 {
                let monthInterest = balance * rate / 12
                var monthPrincipal = monthly - monthInterest
                if monthPrincipal < 0 { monthPrincipal = 0 }
                if monthPrincipal > balance { monthPrincipal = balance }
                balance -= monthPrincipal
                interest += monthInterest
                principal += monthPrincipal
                paid += monthInterest + monthPrincipal
            }
            if balance < 1 {
                principal += balance
                paid += balance
                balance = 0
            }
            result[startYear + index] = LoanSlice(
                interest: interest,
                principal: principal,
                paid: paid,
                monthly: monthly,
                balance: max(0, balance),
                rate: rate
            )
            index += 1
            if index > 80 { break }
        }
        return result
    }

    static func minimumDown(price: Double) -> Double {
        guard price > 0 else { return 0 }
        if price >= 1_500_000 { return price * 0.20 }
        if price <= 500_000 { return price * 0.05 }
        return 500_000 * 0.05 + (price - 500_000) * 0.10
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

    private static func grow(_ base: Double, _ percent: Double, _ years: Int) -> Double {
        guard years > 0 else { return base }
        return base * pow(1 + finite(percent) / 100, Double(years))
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
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    private static func percent(_ value: Double, digits: Int = 2) -> String {
        String(format: "%.\(digits)f%%", value)
    }

    private static func formatArea(_ sqft: Double) -> String {
        L10n.t("unit.sqft", Int(sqft.rounded()))
    }
}
