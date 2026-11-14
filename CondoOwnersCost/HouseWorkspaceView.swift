//
//  HouseWorkspaceView.swift
//  CondoOwnersCost
//

import SwiftUI
import UIKit

struct HouseWorkspaceView: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(LanguageSettings.self) private var lang
    var houseID: UUID
    var role: WorkspaceRole = .standalone
    var onClose: (() -> Void)? = nil

    private var house: HouseEstimate? { store.house(houseID) }

    var body: some View {
        let _ = lang.language
        Group {
            if let house {
                editor(house)
                    .background(Theme.paper)
                    .safeAreaInset(edge: .bottom) {
                        if role == .agent {
                            agentBar(HouseCostEngine.evaluate(house))
                        }
                    }
                    .modifier(HouseChrome(title: house.name, enabled: role == .standalone))
            } else {
                ContentUnavailableView(lang.t("house.missing"), systemImage: "house", description: Text(""))
                    .background(Theme.paper)
            }
        }
        .toolbar { toolbar }
    }

    private func editor(_ house: HouseEstimate) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if ScreenshotLaunch.mode == "house-cost" {
                    HouseResultCard(result: HouseCostEngine.evaluate(house), prominent: true)
                }
                HouseLocationSection(houseID: houseID)
                if role == .standalone, ScreenshotLaunch.mode != "house-cost" {
                    HouseResultCard(result: HouseCostEngine.evaluate(house), prominent: false)
                }
                identity(house)
                purchase
                taxes
                building
                energy
                if house.kind == .townhouse || house.hasStrata {
                    strata
                }
                insurance
                upkeep
                income
            }
            .padding(16)
        }
    }

    private func agentBar(_ result: HouseResult) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("house.summary.month"))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Text(Money.whole(result.monthlyCash))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.teal)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(lang.t("house.summary.gds"))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Text(Money.whole(result.gdsHousing))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.card)
        .overlay(alignment: .top) { Theme.line.frame(height: 1) }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if role == .standalone, let onClose {
            ToolbarItem(placement: .topBarLeading) {
                Button(lang.t("nav.done"), action: onClose)
            }
        }
        if role == .standalone, house != nil {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: shareText) {
                    Label(lang.t("house.share"), systemImage: "square.and.arrow.up")
                }
            }
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button(lang.t("nav.done")) {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }

    private var shareText: String {
        guard let house else { return "" }
        let result = HouseCostEngine.evaluate(house)
        var lines = [
            house.name,
            lang.t(house.kind.titleKey),
            "\(lang.t("house.summary.tco")): \(Money.whole(result.annual))",
            "\(lang.t("house.summary.month")): \(Money.whole(result.monthlyCash))",
            "\(lang.t("house.summary.gds")): \(Money.whole(result.gdsHousing))"
        ]
        lines += result.lines.map { "\($0.title): \(Money.whole($0.amount))" }
        if !result.warnings.isEmpty {
            lines.append("")
            lines += result.warnings
        }
        return lines.joined(separator: "\n")
    }

    private func identity(_ house: HouseEstimate) -> some View {
        SectionCard(title: lang.t("house.section.home"), subtitle: nil) {
            VStack(alignment: .leading, spacing: 12) {
                TextField(lang.t("house.name"), text: field(\.name, ""))
                Picker(lang.t("house.kind.detached"), selection: field(\.kind, house.kind)) {
                    ForEach(HouseKind.allCases, id: \.self) { kind in
                        Text(lang.t(kind.titleKey)).tag(kind)
                    }
                }
                .onChange(of: house.kind) { _, kind in
                    if kind == .townhouse {
                        store.mutateHouse(houseID) { $0.hasStrata = true }
                    }
                }
                TextField(lang.t("house.notes"), text: field(\.notes, ""), axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var purchase: some View {
        SectionCard(title: lang.t("house.section.purchase"), subtitle: nil) {
            VStack(alignment: .leading, spacing: 12) {
                MoneyField(title: lang.t("house.price"), value: field(\.purchasePrice, 0))
                PercentField(title: lang.t("house.down"), value: field(\.downPaymentPercent, 20), range: 0...100, digits: 1, step: 1)
                PercentField(title: lang.t("house.rate"), value: field(\.mortgageRatePercent, 4.5), range: 0...15, digits: 2, step: 0.05)
                Button(lang.t("house.useRate")) {
                    guard let rate = store.document.snapshot.discountedMortgage else { return }
                    store.mutateHouse(houseID) { $0.mortgageRatePercent = rate }
                }
                .disabled(store.document.snapshot.discountedMortgage == nil)
                Stepper(value: field(\.amortYears, 25), in: 5...40) {
                    labeled(lang.t("house.amort"), "\(house?.amortYears ?? 25)")
                }
                Picker(lang.t("occ.principal"), selection: field(\.occupancy, .principal)) {
                    Text(lang.t("occ.principal")).tag(Occupancy.principal)
                    Text(lang.t("occ.investment")).tag(Occupancy.investment)
                }
                Toggle(lang.t("fin.cash"), isOn: field(\.payInFull, false))
            }
        }
    }

    private var taxes: some View {
        SectionCard(title: lang.t("house.section.tax"), subtitle: nil) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(lang.t("house.taxBill"), isOn: matched(\.useDirectTax, false))
                if house?.useDirectTax == true {
                    MoneyField(title: lang.t("house.taxAmount"), value: field(\.directTaxAnnual, 0))
                } else {
                    MoneyField(title: lang.t("house.assessed"), value: field(\.assessedValue, 0))
                    PercentField(title: lang.t("house.taxRate"), value: matched(\.propertyTaxPercent, 0.35), range: 0...3, digits: 3, step: 0.01)
                }
                Picker(lang.t("house.waterMode"), selection: matched(\.waterBilling, .metered)) {
                    ForEach(WaterBilling.allCases, id: \.self) { mode in
                        Text(lang.t(mode.titleKey)).tag(mode)
                    }
                }
                MoneyField(title: lang.t("house.water"), value: field(\.waterAnnual, 0))
                MoneyField(title: lang.t("house.sewer"), value: field(\.sewerAnnual, 0))
                MoneyField(title: lang.t("house.garbage"), value: field(\.garbageAnnual, 0))
            }
        }
    }

    private var building: some View {
        SectionCard(title: lang.t("house.section.building"), subtitle: nil) {
            VStack(alignment: .leading, spacing: 12) {
                MoneyField(title: lang.t("house.sqft"), value: field(\.finishedSqft, 0))
                MoneyField(title: lang.t("house.lot"), value: field(\.lotSqft, 0))
                Stepper(value: field(\.yearBuilt, 1990), in: 1850...2035) {
                    labeled(lang.t("house.built"), "\(house?.yearBuilt ?? 1990)")
                }
                Stepper(value: field(\.yearRenovated, 1990), in: 1850...2035) {
                    labeled(lang.t("house.reno"), "\(house?.yearRenovated ?? 1990)")
                }
                Picker(lang.t("house.roof"), selection: field(\.roof, .asphalt)) {
                    ForEach(RoofMaterial.allCases, id: \.self) { roof in
                        Text(lang.t(roof.titleKey)).tag(roof)
                    }
                }
                Picker(lang.t("house.heat"), selection: matched(\.heating, .gasForcedAir)) {
                    ForEach(HeatingSystem.allCases, id: \.self) { system in
                        Text(lang.t(system.titleKey)).tag(system)
                    }
                }
            }
        }
    }

    private var energy: some View {
        SectionCard(title: lang.t("house.section.energy"), subtitle: nil) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(lang.t("house.bills"), isOn: field(\.useUtilityBills, false))
                if house?.useUtilityBills == true {
                    MoneyField(title: lang.t("house.hydro"), value: field(\.hydroMonthly, 0), digits: 2)
                    MoneyField(title: lang.t("house.gas"), value: field(\.gasMonthly, 0), digits: 2)
                } else {
                    MoneyField(title: lang.t("house.hdd"), value: matched(\.heatingDegreeDays, 2800))
                    Toggle(lang.t("house.useEner"), isOn: field(\.useEnerGuide, false))
                    if house?.useEnerGuide == true {
                        MoneyField(title: lang.t("house.energuide"), value: field(\.enerGuideGJ, 0))
                    }
                }
                Toggle(lang.t("house.pool"), isOn: field(\.pool, false))
                Toggle(lang.t("house.tub"), isOn: field(\.hotTub, false))
                Toggle(lang.t("house.ac"), isOn: field(\.centralAC, false))
                Toggle(lang.t("house.ev"), isOn: field(\.evCharger, false))
            }
        }
    }

    private var strata: some View {
        SectionCard(title: lang.t("house.section.strata"), subtitle: nil) {
            VStack(alignment: .leading, spacing: 12) {
                if house?.kind == .detached {
                    Toggle(lang.t("house.strataToggle"), isOn: field(\.hasStrata, false))
                }
                MoneyField(title: lang.t("house.strataFee"), value: matched(\.strataMonthly, 0))
                Toggle(lang.t("house.inc.heat"), isOn: field(\.strataIncludesHeat, false))
                Toggle(lang.t("house.inc.hw"), isOn: field(\.strataIncludesHotWater, false))
                Toggle(lang.t("house.inc.gas"), isOn: field(\.strataIncludesGas, false))
                Toggle(lang.t("house.inc.water"), isOn: field(\.strataIncludesWater, false))
                Toggle(lang.t("house.inc.garden"), isOn: field(\.strataIncludesGardening, false))
                PercentField(title: lang.t("house.crf"), value: field(\.crfRatioPercent, 50), range: 0...200, digits: 0, step: 1)
                Stepper(value: field(\.complexUnits, 1), in: 1...800) {
                    labeled(lang.t("house.units"), "\(house?.complexUnits ?? 1)")
                }
                PercentField(title: lang.t("house.levy"), value: field(\.levyPercent, 15), range: 0...100, digits: 0, step: 1)
            }
        }
    }

    private var insurance: some View {
        SectionCard(title: lang.t("house.section.insurance"), subtitle: nil) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(lang.t("house.quoteToggle"), isOn: field(\.useQuotedInsurance, false))
                if house?.useQuotedInsurance == true {
                    MoneyField(title: lang.t("house.premium"), value: field(\.quotedInsuranceAnnual, 0))
                }
                Toggle(lang.t("house.fire"), isOn: field(\.distantFireProtection, false))
                Toggle(lang.t("house.flood"), isOn: field(\.floodplain, false))
                Toggle(lang.t("house.wildfire"), isOn: field(\.wildfire, false))
                Toggle(lang.t("house.seismic"), isOn: matched(\.seismic, false))
                Toggle(lang.t("house.alum"), isOn: field(\.aluminumWiring, false))
                Toggle(lang.t("house.polyb"), isOn: field(\.polyB, false))
                Toggle(lang.t("house.lead"), isOn: field(\.leadPlumbing, false))
            }
        }
    }

    private var upkeep: some View {
        SectionCard(title: lang.t("house.section.upkeep"), subtitle: nil) {
            VStack(alignment: .leading, spacing: 12) {
                Picker(lang.t("house.maint.mode"), selection: field(\.maintenanceMode, .percentOfValue)) {
                    ForEach(MaintenanceMode.allCases, id: \.self) { mode in
                        Text(lang.t(mode.titleKey)).tag(mode)
                    }
                }
                if house?.maintenanceMode == .perSqft {
                    MoneyField(title: lang.t("house.maint.psf"), value: field(\.maintenancePerSqft, 1.5), digits: 2)
                } else {
                    PercentField(title: lang.t("house.maint.pct"), value: field(\.maintenancePercent, 1), range: 0...5, digits: 2, step: 0.05)
                }
            }
        }
    }

    private var income: some View {
        SectionCard(title: lang.t("house.section.income"), subtitle: lang.t("house.income.note")) {
            VStack(alignment: .leading, spacing: 12) {
                MoneyField(title: lang.t("house.income"), value: field(\.grossIncomeAnnual, 0))
                MoneyField(title: lang.t("house.debt"), value: field(\.otherDebtMonthly, 0))
            }
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
        }
    }

    private func field<T>(_ path: WritableKeyPath<HouseEstimate, T>, _ fallback: T) -> Binding<T> {
        store.bindHouse(houseID, path, fallback: fallback)
    }

    private func matched<T: Equatable>(_ path: WritableKeyPath<HouseEstimate, T>, _ fallback: T) -> Binding<T> {
        Binding(
            get: { store.house(houseID)?[keyPath: path] ?? fallback },
            set: { newValue in
                store.mutateHouse(houseID) {
                    guard $0[keyPath: path] != newValue else { return }
                    $0[keyPath: path] = newValue
                    $0.estimatesAreSuggested = false
                }
            }
        )
    }
}
