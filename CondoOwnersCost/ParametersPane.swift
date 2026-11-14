//
//  ParametersPane.swift
//  CondoOwnersCost
//

import SwiftUI

struct ParametersPane: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(LanguageSettings.self) private var lang
    let propertyID: UUID

    private var property: CondoProperty? { store.property(propertyID) }

    var body: some View {
        if let property {
            let projection = CostEngine.project(property)
            ScrollView {
                VStack(spacing: 14) {
                    identity(property)
                    LocationSection(propertyID: propertyID)
                    purchase(property)
                    building(property)
                    financing(property, projection: projection)
                    operating(property)
                    capital(property)
                    SectionCard(title: lang.t("notes.title")) {
                        TextField(lang.t("notes.placeholder"), text: store.bind(propertyID, \.notes, fallback: property.notes), axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func identity(_ property: CondoProperty) -> some View {
        SectionCard(title: lang.t("property.section")) {
            TextField(lang.t("property.name"), text: store.bind(propertyID, \.name, fallback: property.name))
        }
    }

    private func purchase(_ property: CondoProperty) -> some View {
        SectionCard(title: lang.t("buy.title"), subtitle: lang.t("buy.subtitle")) {
            MoneyField(title: lang.t("buy.price"), value: Binding(
                get: { store.property(propertyID)?.inputs.purchasePrice ?? property.inputs.purchasePrice },
                set: { value in store.mutate(propertyID) { $0.setPurchasePrice(value) } }
            ))
            Toggle(lang.t("buy.follow"), isOn: Binding(
                get: { !(store.property(propertyID)?.inputs.assessedLocked ?? property.inputs.assessedLocked) },
                set: { follow in
                    store.mutate(propertyID) {
                        $0.inputs.assessedLocked = !follow
                        if follow { $0.inputs.assessedValue = $0.inputs.purchasePrice }
                    }
                }
            ))
            .tint(Theme.teal)
            if property.inputs.assessedLocked {
                MoneyField(title: lang.t("buy.assessed"), value: Binding(
                    get: { store.property(propertyID)?.inputs.assessedValue ?? property.inputs.assessedValue },
                    set: { value in store.mutate(propertyID) { $0.setAssessedValue(value) } }
                ))
            }
            Toggle(lang.t("buy.billToggle"), isOn: store.bind(propertyID, \.inputs.useDirectPropertyTax, fallback: property.inputs.useDirectPropertyTax))
                .tint(Theme.teal)
            if property.inputs.useDirectPropertyTax {
                MoneyField(title: lang.t("buy.bill"), value: store.bind(propertyID, \.inputs.directPropertyTaxAnnual, fallback: property.inputs.directPropertyTaxAnnual))
                Footnote(text: lang.t("buy.bill.note"))
            } else {
                PercentField(
                    title: lang.t("buy.rate"),
                    value: Binding(
                        get: { store.property(propertyID)?.inputs.propertyTaxPercent ?? property.inputs.propertyTaxPercent },
                        set: { value in store.mutate(propertyID) { $0.setTaxPercent(value) } }
                    ),
                    range: 0...3,
                    digits: 4,
                    step: 0.01
                )
                Footnote(text: CityBaselines.taxNote(for: property))
            }
        }
    }

    private func building(_ property: CondoProperty) -> some View {
        SectionCard(title: lang.t("bld.title"), subtitle: lang.t("bld.subtitle")) {
            Picker(lang.t("bld.unit"), selection: store.bind(propertyID, \.inputs.areaUnit, fallback: property.inputs.areaUnit)) {
                ForEach(AreaUnit.allCases, id: \.self) { unit in
                    Text(unit.title).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            MoneyField(title: lang.t("bld.area"), value: areaBinding(property), digits: 1)
            Footnote(text: lang.t("bld.area.note", Int(property.inputs.indoorSqft.rounded()), String(format: "%.1f", property.inputs.indoorSqft * 0.09290304)))
            Stepper(value: store.bind(propertyID, \.inputs.yearBuilt, fallback: property.inputs.yearBuilt), in: 1950...CalendarYear.current) {
                Text(lang.t("bld.year", property.inputs.yearBuilt))
            }
            Toggle(lang.t("bld.pool"), isOn: store.bind(propertyID, \.inputs.hasPool, fallback: property.inputs.hasPool)).tint(Theme.teal)
            Toggle(lang.t("bld.desk"), isOn: store.bind(propertyID, \.inputs.hasConcierge, fallback: property.inputs.hasConcierge)).tint(Theme.teal)
            if let baseline = CityBaselines.match(city: property.location.city, province: property.location.provinceCode)
                ?? CityBaselines.byID[property.location.appliedBaselineID ?? ""] {
                let suggested = baseline.suggestedStrata(
                    yearBuilt: property.inputs.yearBuilt,
                    pool: property.inputs.hasPool,
                    concierge: property.inputs.hasConcierge,
                    year: CalendarYear.current
                )
                Footnote(text: lang.t("bld.suggest", baseline.localizedName, String(format: "%.2f", suggested)))
                Button(lang.t("bld.applyFee")) {
                    store.mutate(propertyID) {
                        $0.inputs.strataPerSqftMonthly = suggested
                        $0.inputs.useMonthlyStrata = false
                        $0.inputs.usesPlaceholderCosts = false
                    }
                }
            }
        }
    }

    private func financing(_ property: CondoProperty, projection: Projection) -> some View {
        let funding = projection.funding
        return SectionCard(title: lang.t("fin.title"), subtitle: lang.t("fin.subtitle")) {
            Toggle(lang.t("fin.cash"), isOn: Binding(
                get: { store.property(propertyID)?.inputs.payInFull ?? property.inputs.payInFull },
                set: { on in store.mutate(propertyID) { $0.setPayInFull(on) } }
            ))
            .tint(Theme.teal)
            if property.inputs.payInFull {
                Footnote(text: lang.t("fin.cash.note"))
            } else {
                Picker(lang.t("fin.down"), selection: store.bind(propertyID, \.inputs.downPaymentMode, fallback: property.inputs.downPaymentMode)) {
                    ForEach(DownPaymentMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                if property.inputs.downPaymentMode == .percent {
                    PercentField(
                        title: lang.t("fin.downPct"),
                        value: Binding(
                            get: { store.property(propertyID)?.inputs.downPaymentPercent ?? property.inputs.downPaymentPercent },
                            set: { value in store.mutate(propertyID) { $0.setDownPercent(value) } }
                        ),
                        range: 0...100,
                        step: 0.5
                    )
                } else {
                    MoneyField(title: lang.t("fin.downAmt"), value: Binding(
                        get: { store.property(propertyID)?.inputs.downPaymentAmount ?? property.inputs.downPaymentAmount },
                        set: { value in store.mutate(propertyID) { $0.setDownAmount(value) } }
                    ))
                }
                Footnote(text: lang.t("fin.summary", Money.precise(funding.downPayment), Money.precise(funding.baseLoan), Money.precise(funding.minimumDown)))
                Stepper(value: store.bind(propertyID, \.inputs.amortYears, fallback: property.inputs.amortYears), in: 5...40) {
                    Text(lang.t("fin.amort", property.inputs.amortYears))
                }
                Stepper(value: store.bind(propertyID, \.inputs.mortgageStartYear, fallback: property.inputs.mortgageStartYear), in: 1990...CalendarYear.current + 5) {
                    Text(lang.t("fin.start", property.inputs.mortgageStartYear))
                }
                PercentField(title: lang.t("fin.rate"), value: Binding(
                    get: { store.property(propertyID)?.inputs.mortgageRatePercent ?? property.inputs.mortgageRatePercent },
                    set: { value in store.mutate(propertyID) { $0.setMortgageRate(value) } }
                ), range: 0...12)
                Toggle(lang.t("fin.follow"), isOn: Binding(
                    get: { store.property(propertyID)?.inputs.followBankRate ?? property.inputs.followBankRate },
                    set: { on in
                        let snapshot = store.document.snapshot
                        store.mutate(propertyID) {
                            $0.inputs.followBankRate = on
                            if on {
                                let seedInflation = $0.inputs.ratesAreSuggested
                                $0.applyMarket(snapshot, choice: .discounted, includeInflation: seedInflation)
                                $0.inputs.followBankRate = true
                            }
                        }
                    }
                ))
                .tint(Theme.teal)
                Toggle(lang.t("fin.renewSame"), isOn: store.bind(propertyID, \.inputs.renewalUsesInitialRate, fallback: property.inputs.renewalUsesInitialRate))
                    .tint(Theme.teal)
                if !property.inputs.renewalUsesInitialRate {
                    PercentField(title: lang.t("fin.renewRate"), value: Binding(
                        get: { store.property(propertyID)?.inputs.renewalRatePercent ?? property.inputs.renewalRatePercent },
                        set: { value in store.mutate(propertyID) { $0.setRenewalRate(value) } }
                    ), range: 0...12)
                }
                Stepper(value: store.bind(propertyID, \.inputs.renewalEveryYears, fallback: property.inputs.renewalEveryYears), in: 1...10) {
                    Text(lang.t("fin.renewEvery", property.inputs.renewalEveryYears))
                }
                if funding.insured {
                    Text(lang.t("fin.cmhc", String(format: "%.2f", funding.premiumRate * 100), Money.precise(funding.premium), Money.precise(funding.premiumTax)))
                        .font(.footnote.monospacedDigit())
                    Toggle(lang.t("fin.capitalize"), isOn: store.bind(propertyID, \.inputs.capitalizePremium, fallback: property.inputs.capitalizePremium))
                        .tint(Theme.teal)
                    Footnote(text: lang.t("fin.pst"))
                } else {
                    Footnote(text: lang.t("fin.noCmhc"))
                }
                Footnote(text: lang.t("fin.payment", Money.precise(funding.monthlyPayment)))
            }
        }
    }

    private func operating(_ property: CondoProperty) -> some View {
        SectionCard(title: lang.t("op.title"), subtitle: lang.t("op.subtitle")) {
            Toggle(lang.t("op.monthlyToggle"), isOn: store.bind(propertyID, \.inputs.useMonthlyStrata, fallback: property.inputs.useMonthlyStrata))
                .tint(Theme.teal)
            if property.inputs.useMonthlyStrata {
                MoneyField(title: lang.t("op.monthly"), value: store.bind(propertyID, \.inputs.strataMonthly, fallback: property.inputs.strataMonthly), digits: 2)
            } else {
                MoneyField(
                    title: lang.t("op.psf"),
                    value: store.bind(propertyID, \.inputs.strataPerSqftMonthly, fallback: property.inputs.strataPerSqftMonthly),
                    digits: 2
                )
                Slider(
                    value: store.bind(propertyID, \.inputs.strataPerSqftMonthly, fallback: property.inputs.strataPerSqftMonthly),
                    in: 0.3...1.5,
                    step: 0.01
                )
                .tint(Theme.teal)
                Footnote(text: lang.t("op.psf.note", Money.precise(property.inputs.strataPerSqftMonthly * property.inputs.indoorSqft), Money.precise(property.inputs.strataPerSqftMonthly * property.inputs.indoorSqft * 12)))
            }
            MoneyField(title: lang.t("op.ins"), value: store.bind(propertyID, \.inputs.insuranceAnnual, fallback: property.inputs.insuranceAnnual))
            Footnote(text: lang.t("op.ins.note"))
            MoneyField(title: lang.t("op.hydro"), value: store.bind(propertyID, \.inputs.hydroMonthly, fallback: property.inputs.hydroMonthly))
            MoneyField(title: lang.t("op.net"), value: store.bind(propertyID, \.inputs.internetMonthly, fallback: property.inputs.internetMonthly))
            Toggle(lang.t("op.waterIn"), isOn: store.bind(propertyID, \.inputs.waterIncludedInStrata, fallback: property.inputs.waterIncludedInStrata))
                .tint(Theme.teal)
            if !property.inputs.waterIncludedInStrata {
                MoneyField(title: lang.t("op.water"), value: store.bind(propertyID, \.inputs.waterMonthly, fallback: property.inputs.waterMonthly))
            }
            Toggle(lang.t("op.heat"), isOn: Binding(
                get: { store.property(propertyID)?.inputs.hasHeatPump ?? property.inputs.hasHeatPump },
                set: { on in
                    store.mutate(propertyID) {
                        $0.inputs.hasHeatPump = on
                        if on, $0.inputs.heatPumpMonthly == 0 { $0.inputs.heatPumpMonthly = 35 }
                    }
                }
            ))
            .tint(Theme.teal)
            if property.inputs.hasHeatPump {
                MoneyField(title: lang.t("op.heatAmt"), value: store.bind(propertyID, \.inputs.heatPumpMonthly, fallback: property.inputs.heatPumpMonthly))
            }
            Picker(lang.t("op.levy"), selection: store.bind(propertyID, \.inputs.levyMode, fallback: property.inputs.levyMode)) {
                ForEach(LevyMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            if property.inputs.levyMode == .percentOfStrata {
                PercentField(title: lang.t("op.levyPct"), value: store.bind(propertyID, \.inputs.levyPercent, fallback: property.inputs.levyPercent), range: 0...40, step: 1)
            } else {
                MoneyField(title: lang.t("op.levyFixed"), value: store.bind(propertyID, \.inputs.levyFixedAnnual, fallback: property.inputs.levyFixedAnnual))
            }
            Toggle(lang.t("op.floor"), isOn: store.bind(propertyID, \.inputs.levyUsesFloor, fallback: property.inputs.levyUsesFloor))
                .tint(Theme.teal)
            if property.inputs.levyUsesFloor {
                MoneyField(title: lang.t("op.floorAmt"), value: store.bind(propertyID, \.inputs.levyFloorAnnual, fallback: property.inputs.levyFloorAnnual))
            }
        }
    }

    private func capital(_ property: CondoProperty) -> some View {
        SectionCard(title: lang.t("cap.title"), subtitle: lang.t("cap.subtitle")) {
            Picker(lang.t("cap.use"), selection: store.bind(propertyID, \.inputs.occupancy, fallback: property.inputs.occupancy)) {
                ForEach(Occupancy.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            Toggle(lang.t("cap.opp"), isOn: store.bind(propertyID, \.inputs.includeOpportunity, fallback: property.inputs.includeOpportunity))
                .tint(Theme.teal)
            if property.inputs.includeOpportunity {
                PercentField(title: lang.t("cap.risk"), value: Binding(
                    get: { store.property(propertyID)?.inputs.riskFreePercent ?? property.inputs.riskFreePercent },
                    set: { value in store.mutate(propertyID) { $0.setRiskFree(value) } }
                ), range: 0...8)
                Footnote(text: lang.t("cap.risk.note"))
            }
            if property.inputs.occupancy == .investment {
                PercentField(title: lang.t("cap.mtr"), value: store.bind(propertyID, \.inputs.marginalTaxPercent, fallback: property.inputs.marginalTaxPercent), range: 0...54, step: 0.5)
                MoneyField(title: lang.t("cap.rent"), value: store.bind(propertyID, \.inputs.annualRent, fallback: property.inputs.annualRent))
                Footnote(text: lang.t("cap.rent.note"))
            } else {
                Footnote(text: lang.t("cap.pre"))
            }
        }
    }

    private func areaBinding(_ property: CondoProperty) -> Binding<Double> {
        Binding(
            get: {
                let inputs = store.property(propertyID)?.inputs ?? property.inputs
                return inputs.areaUnit == .sqft ? inputs.indoorSqft : inputs.indoorSqft * 0.09290304
            },
            set: { newValue in
                store.mutate(propertyID) {
                    $0.inputs.indoorSqft = $0.inputs.areaUnit == .sqft ? newValue : newValue / 0.09290304
                }
            }
        )
    }
}
