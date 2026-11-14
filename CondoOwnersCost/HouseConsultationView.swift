//
//  HouseConsultationView.swift
//  CondoOwnersCost
//

import SwiftUI

struct HouseChrome: ViewModifier {
    var title: String
    var enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            content
        }
    }
}

struct HouseConsultationView: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(LanguageSettings.self) private var lang
    let houseID: UUID
    var onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let book = ConsultationLayout.book(proxy.size)
            Group {
                if book {
                    HStack(spacing: 0) {
                        agentPane
                        foldGap(vertical: false)
                        clientPane
                    }
                } else {
                    VStack(spacing: 0) {
                        clientPane
                        foldGap(vertical: true)
                        agentPane
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Theme.paper)
        .navigationTitle(store.house(houseID)?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onClose) {
                    Label(lang.t("nav.title"), systemImage: "chevron.backward")
                }
            }
            if store.house(houseID) != nil {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: shareText) {
                        Label(lang.t("house.share"), systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private var shareText: String {
        guard let house = store.house(houseID) else { return "" }
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

    private var agentPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(lang.t("duo.agent"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            HouseWorkspaceView(houseID: houseID, role: .agent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
    }

    private var clientPane: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lang.t("duo.client"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16)
            Text(lang.t("duo.client.note.house"))
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
            HouseClientPane(houseID: houseID)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.card)
    }

    private func foldGap(vertical: Bool) -> some View {
        Rectangle()
            .fill(Theme.line)
            .frame(width: vertical ? nil : 28, height: vertical ? 28 : nil)
    }
}

struct HouseClientPane: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(LanguageSettings.self) private var lang
    var houseID: UUID

    var body: some View {
        let _ = lang.language
        Group {
            if let house = store.house(houseID) {
                ScrollView {
                    HouseResultCard(result: HouseCostEngine.evaluate(house), prominent: true)
                        .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.card)
    }
}

struct HouseResultCard: View {
    @Environment(LanguageSettings.self) private var lang
    var result: HouseResult
    var prominent: Bool

    var body: some View {
        let _ = lang.language
        SectionCard(title: lang.t("house.nav"), subtitle: lang.t("house.method")) {
            VStack(alignment: .leading, spacing: prominent ? 14 : 10) {
                figure(lang.t("house.summary.tco"), Money.whole(result.annual), headline: true)
                figure(lang.t("house.summary.month"), Money.whole(result.monthlyCash), headline: true)
                figure(lang.t("house.summary.pay"), Money.whole(result.contractPayment), headline: false)
                figure(lang.t("house.summary.stress"), Money.whole(result.qualifyingPayment), headline: false)
                figure(lang.t("house.summary.gds"), Money.whole(result.gdsHousing), headline: false)
                if let ratio = result.gdsRatio {
                    figure(lang.t("house.summary.gdsRatio"), ratioText(ratio), headline: false)
                }
                if let ratio = result.qualifyingGdsRatio {
                    figure(lang.t("house.summary.stressGds"), ratioText(ratio), headline: false)
                }
                if let ratio = result.tdsRatio {
                    figure(lang.t("house.summary.tds"), ratioText(ratio), headline: false)
                }
                ForEach(result.lines) { line in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(line.title)
                            Spacer()
                            Text(Money.whole(line.amount))
                                .monospacedDigit()
                        }
                        .font(prominent ? .body : .subheadline)
                        Text(line.detail)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
                ForEach(result.warnings, id: \.self) { warning in
                    Text(warning)
                        .font(.footnote)
                        .foregroundStyle(Theme.copper)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func figure(_ title: String, _ value: String, headline: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(prominent && headline ? .title3 : .body)
                .foregroundStyle(Theme.muted)
            Spacer()
            Text(value)
                .font((prominent && headline ? Font.largeTitle : Font.title3).weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.teal)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    private func ratioText(_ value: Double) -> String {
        String(format: "%.1f%%", locale: lang.language.locale, value)
    }
}
