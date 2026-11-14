//
//  ResultsPane.swift
//  CondoOwnersCost
//

import SwiftUI

struct ResultsPane: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(LanguageSettings.self) private var lang
    let propertyID: UUID
    @Binding var selectedYear: Int

    var body: some View {
        if let property = store.property(propertyID) {
            let _ = lang.language
            let projection = CostEngine.project(property)
            let current = CalendarYear.current
            let target = max(current, property.inputs.projection.targetYear)
            let shown = projection.year(min(max(selectedYear, current), target)) ?? projection.years.first
            ScrollView {
                VStack(spacing: 14) {
                    if let shown {
                        header(property, shown: shown, current: projection.year(current), targetYear: target)
                        ForEach(CostGroup.allCases, id: \.self) { group in
                            let lines = shown.lines.filter { $0.group == group }
                            if !lines.isEmpty {
                                groupCard(group, lines: lines, total: shown.netAnnual)
                            }
                        }
                        mortgageCard(shown)
                        if property.inputs.occupancy == .investment, property.inputs.annualRent > 0 {
                            rentCard(rent: property.inputs.annualRent, year: shown)
                        }
                    }
                    if !projection.warnings.isEmpty {
                        SectionCard(title: lang.t("res.warn")) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(projection.warnings, id: \.self) { warning in
                                    Label(warning, systemImage: "exclamationmark.triangle")
                                        .font(.footnote)
                                        .foregroundStyle(Theme.copper)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    let notes = CityBaselines.provinceNotes(property.location.provinceCode)
                    if !notes.isEmpty {
                        SectionCard(title: lang.t("res.province")) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(notes, id: \.self) { note in
                                    Text(note)
                                        .font(.footnote)
                                        .foregroundStyle(Theme.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    Footnote(text: lang.t("res.formula"))
                        .padding(.horizontal, 4)
                }
                .padding(16)
            }
        }
    }

    private func header(_ property: CondoProperty, shown: YearResult, current: YearResult?, targetYear: Int) -> some View {
        SectionCard(title: String(shown.year), subtitle: property.location.placeLine) {
            yearControls(targetYear: targetYear)
            Text(lang.t("res.economic"))
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            Text(Money.precise(shown.netAnnual))
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Text(lang.t("res.monthlyCash", Money.precise(shown.netAnnual / 12), Money.precise(shown.cashAnnual)))
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            if property.inputs.purchasePrice > 0 {
                Text(lang.t("res.ofPrice", String(format: "%.2f", shown.netAnnual / property.inputs.purchasePrice * 100)))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.teal)
            }
            if let current, shown.year != current.year {
                let delta = shown.netAnnual - current.netAnnual
                Text(lang.t(delta >= 0 ? "res.delta.more" : "res.delta.less", Money.precise(abs(delta)), current.year))
                    .font(.footnote)
                    .foregroundStyle(Theme.ink)
            }
        }
    }

    private func yearControls(targetYear: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { selectedYear = max(CalendarYear.current, selectedYear - 1) } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(String(selectedYear))
                    .font(.headline.monospacedDigit())
                Spacer()
                Button { selectedYear = min(targetYear, selectedYear + 1) } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.bordered)
            if targetYear > CalendarYear.current {
                Slider(
                    value: Binding(
                        get: { Double(selectedYear) },
                        set: { selectedYear = Int($0.rounded()) }
                    ),
                    in: Double(CalendarYear.current)...Double(targetYear),
                    step: 1
                )
                .tint(Theme.teal)
            }
            Stepper(value: store.bind(propertyID, \.inputs.projection.targetYear, fallback: targetYear), in: CalendarYear.current...CalendarYear.current + 40) {
                Text(lang.t("res.predictTo", targetYear))
            }
        }
    }

    private func groupCard(_ group: CostGroup, lines: [CostLine], total: Double) -> some View {
        SectionCard(title: group.title) {
            VStack(spacing: 12) {
                ForEach(lines) { line in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(line.title)
                                .font(.subheadline.weight(.medium))
                            Spacer(minLength: 8)
                            Text(Money.precise(line.amount))
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(line.amount < 0 ? Theme.good : Theme.ink)
                        }
                        Text(line.detail)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        GeometryReader { geo in
                            Capsule()
                                .fill(line.amount < 0 ? Theme.good.opacity(0.8) : Theme.teal.opacity(0.85))
                                .frame(width: max(4, geo.size.width * share(line.amount, of: total)))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }

    private func mortgageCard(_ year: YearResult) -> some View {
        let cash = store.property(propertyID)?.inputs.payInFull == true
        return SectionCard(title: cash ? lang.t("res.cash.title") : lang.t("res.principalTitle")) {
            if cash {
                Footnote(text: lang.t("res.cash.note"))
            } else {
                LabeledContent(lang.t("res.payment")) { Text(Money.precise(year.monthlyPayment)).monospacedDigit() }
                LabeledContent(lang.t("res.principal")) { Text(Money.precise(year.mortgagePrincipal)).monospacedDigit() }
                LabeledContent(lang.t("res.balance")) { Text(Money.precise(year.endingBalance)).monospacedDigit() }
                Footnote(text: lang.t("res.principal.note"))
            }
        }
    }

    private func rentCard(rent: Double, year: YearResult) -> some View {
        let gap = rent - year.cashAnnual
        return SectionCard(title: lang.t("res.rent.title")) {
            LabeledContent(lang.t("res.rent.annual")) { Text(Money.precise(rent)).monospacedDigit() }
            LabeledContent(lang.t("res.rent.cash")) { Text(Money.precise(year.cashAnnual)).monospacedDigit() }
            Text(lang.t(gap >= 0 ? "res.rent.cover" : "res.rent.short", Money.precise(abs(gap))))
                .font(.footnote)
                .foregroundStyle(gap >= 0 ? Theme.good : Theme.copper)
            Footnote(text: lang.t("res.rent.note"))
        }
    }

    private func share(_ amount: Double, of total: Double) -> Double {
        let base = max(abs(total), 1)
        return min(1, abs(amount) / base)
    }
}
