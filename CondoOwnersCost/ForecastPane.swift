//
//  ForecastPane.swift
//  CondoOwnersCost
//

import Charts
import SwiftUI

struct ForecastPane: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(LanguageSettings.self) private var lang
    let propertyID: UUID
    @Binding var selectedYear: Int
    @State private var refreshing = false

    var body: some View {
        if let property = store.property(propertyID) {
            let _ = lang.language
            let projection = CostEngine.project(property)
            let snapshot = store.document.snapshot
            ScrollView {
                VStack(spacing: 14) {
                    market(property, snapshot: snapshot)
                    assumptions(property)
                    chart(projection)
                    comparison(property, projection: projection)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func market(_ property: CondoProperty, snapshot: MarketSnapshot) -> some View {
        SectionCard(title: lang.t("mkt.title"), subtitle: lang.t("mkt.subtitle")) {
            if snapshot.policyRate == nil && snapshot.fiveYearBond == nil {
                Text(snapshot.statusMessage.isEmpty ? lang.t("mkt.pending") : snapshot.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink)
            } else {
                rateRow(lang.t("mkt.policy"), snapshot.policyRate, snapshot.policyAsOf)
                rateRow(lang.t("mkt.prime"), snapshot.primeRate, snapshot.primeAsOf)
                rateRow(lang.t("mkt.bond"), snapshot.fiveYearBond, snapshot.bondAsOf)
                rateRow(lang.t("mkt.posted"), snapshot.postedFiveYearMortgage, snapshot.mortgageAsOf)
                rateRow(lang.t("mkt.discountRate"), snapshot.discountedMortgage, snapshot.bondAsOf)
                rateRow(lang.t("mkt.cpi"), snapshot.cpiYoY, nil)
            }
            if let date = snapshot.fetchedAt {
                Text(lang.t("mkt.sync", date.formatted(date: .abbreviated, time: .shortened)))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            if let error = snapshot.fetchError, !error.isEmpty {
                Footnote(text: lang.t("mkt.offline", error))
            }
            Button {
                Task {
                    refreshing = true
                    await store.refreshMarket(force: true)
                    refreshing = false
                }
            } label: {
                if refreshing { ProgressView() } else { Text(lang.t("mkt.resync")) }
            }
            .disabled(refreshing)
            HStack {
                Button(lang.t("mkt.discount")) {
                    store.mutate(propertyID) {
                        let seed = $0.inputs.ratesAreSuggested
                        $0.applyMarket(snapshot, choice: .discounted, includeInflation: seed)
                        $0.inputs.followBankRate = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.teal)
                Button(lang.t("mkt.postedBtn")) {
                    store.mutate(propertyID) { $0.applyMarket(snapshot, choice: .posted, includeInflation: false) }
                }
                .buttonStyle(.bordered)
            }
            Footnote(text: lang.t("mkt.posted.note"))
        }
    }

    private func assumptions(_ property: CondoProperty) -> some View {
        SectionCard(title: lang.t("grow.title"), subtitle: lang.t("grow.subtitle")) {
            Stepper(value: store.bind(propertyID, \.inputs.projection.targetYear, fallback: property.inputs.projection.targetYear), in: CalendarYear.current...CalendarYear.current + 40) {
                Text(lang.t("grow.target", property.inputs.projection.targetYear))
            }
            PercentField(title: lang.t("grow.assess"), value: store.bind(propertyID, \.inputs.projection.assessmentGrowthPercent, fallback: property.inputs.projection.assessmentGrowthPercent), range: -5...15)
            PercentField(title: lang.t("grow.tax"), value: store.bind(propertyID, \.inputs.projection.taxRateGrowthPercent, fallback: property.inputs.projection.taxRateGrowthPercent), range: -2...10)
            PercentField(title: lang.t("grow.strata"), value: store.bind(propertyID, \.inputs.projection.strataInflationPercent, fallback: property.inputs.projection.strataInflationPercent), range: 0...12)
            PercentField(title: lang.t("grow.ins"), value: store.bind(propertyID, \.inputs.projection.insuranceInflationPercent, fallback: property.inputs.projection.insuranceInflationPercent), range: 0...15)
            PercentField(title: lang.t("grow.util"), value: store.bind(propertyID, \.inputs.projection.utilitiesInflationPercent, fallback: property.inputs.projection.utilitiesInflationPercent), range: -2...12)
            Footnote(text: lang.t("grow.note"))
        }
    }

    private func chart(_ projection: Projection) -> some View {
        SectionCard(title: lang.t("chart.title"), subtitle: lang.t("chart.subtitle")) {
            if projection.years.count < 2 {
                Footnote(text: lang.t("chart.need"))
            }
            let economic = lang.t("chart.economic")
            let cash = lang.t("chart.cash")
            let yearLabel = lang.t("chart.year")
            let scaleLabel = lang.t("chart.k")
            Chart(projection.years) { year in
                LineMark(
                    x: .value(yearLabel, year.year),
                    y: .value(scaleLabel, year.netAnnual / 1000)
                )
                .foregroundStyle(by: .value(economic, economic))
                PointMark(
                    x: .value(yearLabel, year.year),
                    y: .value(scaleLabel, year.netAnnual / 1000)
                )
                .foregroundStyle(by: .value(economic, economic))
                LineMark(
                    x: .value(yearLabel, year.year),
                    y: .value(scaleLabel, year.cashAnnual / 1000)
                )
                .foregroundStyle(by: .value(cash, cash))
            }
            .chartForegroundStyleScale([
                economic: Theme.teal,
                cash: Theme.copper
            ])
            .frame(height: 240)
        }
    }

    private func comparison(_ property: CondoProperty, projection: Projection) -> some View {
        let currentYear = CalendarYear.current
        let targetYear = max(currentYear, property.inputs.projection.targetYear)
        return SectionCard(title: "\(currentYear) – \(targetYear)") {
            if let now = projection.year(currentYear), let later = projection.year(targetYear) {
                comparisonRow(lang.t("cmp.item"), now: lang.t("cmp.now"), later: "\(later.year)", emphasize: true)
                ForEach(now.lines) { line in
                    let future = later.lines.first { $0.id == line.id }?.amount ?? 0
                    comparisonRow(line.title, now: Money.whole(line.amount), later: Money.whole(future))
                }
                comparisonRow(lang.t("res.economic"), now: Money.whole(now.netAnnual), later: Money.whole(later.netAnnual), emphasize: true)
                comparisonRow(lang.t("chart.cash"), now: Money.whole(now.cashAnnual), later: Money.whole(later.cashAnnual))
                comparisonRow(lang.t("res.principal"), now: Money.whole(now.mortgagePrincipal), later: Money.whole(later.mortgagePrincipal))
            }
        }
    }

    private func comparisonRow(_ title: String, now: String, later: String, emphasize: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(emphasize ? .subheadline.weight(.semibold) : .caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(now)
                .font(.caption.monospacedDigit())
                .frame(width: 88, alignment: .trailing)
            Text(later)
                .font(.caption.monospacedDigit())
                .frame(width: 88, alignment: .trailing)
        }
        .foregroundStyle(emphasize ? Theme.ink : Theme.muted)
    }

    private func rateRow(_ title: String, _ value: Double?, _ asOf: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value.map { String(format: "%.2f%%", $0) } ?? "—")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                if let asOf, !asOf.isEmpty {
                    Text(lang.t("mkt.asof", asOf))
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .foregroundStyle(Theme.ink)
    }
}
