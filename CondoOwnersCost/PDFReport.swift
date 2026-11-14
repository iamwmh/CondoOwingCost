//
//  PDFReport.swift
//  CondoOwnersCost
//

import UIKit

enum PDFReport {
    static func make(property: CondoProperty, projection: Projection, snapshot: MarketSnapshot) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            var y: CGFloat = margin
            var pageNumber = 1
            context.beginPage()

            func finishPage() {
                let footer = L10n.t("pdf.footer", pageNumber)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                footer.draw(at: CGPoint(x: margin, y: page.height - 26), withAttributes: attributes)
            }

            func ensure(_ height: CGFloat) {
                if y + height > page.height - 46 {
                    finishPage()
                    context.beginPage()
                    pageNumber += 1
                    y = margin
                }
            }

            @discardableResult
            func draw(_ text: String, font: UIFont, color: UIColor = .label, gap: CGFloat = 6) -> CGFloat {
                let width = page.width - margin * 2
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 2
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: style
                ]
                let height = ceil((text as NSString).boundingRect(
                    with: CGSize(width: width, height: 2000),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                ).height)
                ensure(height + gap)
                (text as NSString).draw(
                    in: CGRect(x: margin, y: y, width: width, height: height),
                    withAttributes: attributes
                )
                y += height + gap
                return height
            }

            let ink = UIColor(red: 0.12, green: 0.10, blue: 0.08, alpha: 1)
            let muted = UIColor.secondaryLabel
            let titleFont = UIFont.systemFont(ofSize: 22, weight: .semibold)
            let headFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: 10)
            let smallFont = UIFont.systemFont(ofSize: 9)

            draw(L10n.t("pdf.title"), font: titleFont, color: ink, gap: 4)
            let formatter = DateFormatter()
            formatter.locale = L10n.language.locale
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            draw(L10n.t("pdf.generated", formatter.string(from: .now)), font: smallFont, color: muted, gap: 10)

            draw(property.name, font: headFont, color: ink, gap: 2)
            let location = property.location
            var place = location.singleLine
            if place.isEmpty { place = location.placeLine }
            if let lat = location.latitude, let lon = location.longitude {
                place += "\n" + L10n.t("pdf.coord", String(format: "%.6f", lat), String(format: "%.6f", lon))
            }
            draw(place, font: bodyFont, color: muted, gap: 8)

            let currentYear = CalendarYear.current
            let targetYear = max(currentYear, property.inputs.projection.targetYear)
            if let current = projection.year(currentYear) {
                let target = projection.year(targetYear) ?? current
                draw(
                    L10n.t("pdf.current", currentYear, Money.precise(current.netAnnual), Money.precise(current.netAnnual / 12), Money.precise(current.cashAnnual)),
                    font: bodyFont,
                    color: ink
                )
                if target.year != current.year {
                    let delta = target.netAnnual - current.netAnnual
                    draw(
                        L10n.t(delta >= 0 ? "pdf.future.up" : "pdf.future.down", target.year, Money.precise(target.netAnnual), current.year, Money.precise(abs(delta))),
                        font: bodyFont,
                        color: ink
                    )
                }
            }

            draw(L10n.t("pdf.formula"), font: smallFont, color: muted, gap: 10)

            let funding = projection.funding
            draw(L10n.t("pdf.funding"), font: headFont, color: ink, gap: 3)
            if property.inputs.payInFull {
                draw(L10n.t("pdf.cash"), font: bodyFont)
            } else {
                let downPct = String(format: "%.1f", funding.price > 0 ? funding.downPayment / funding.price * 100 : 0)
                draw(
                    L10n.t("pdf.funding.body", Money.precise(funding.price), Money.precise(funding.downPayment), downPct, Money.precise(funding.baseLoan)),
                    font: bodyFont
                )
            }
            if funding.insured {
                let included = property.inputs.capitalizePremium ? L10n.t("pdf.cmhc.in") : L10n.t("pdf.cmhc.out")
                draw(
                    L10n.t("pdf.cmhc", String(format: "%.2f", funding.premiumRate * 100), Money.precise(funding.premium), included, Money.precise(funding.premiumTax), Money.precise(funding.totalLoan)),
                    font: bodyFont
                )
            } else if !property.inputs.payInFull {
                draw(L10n.t("pdf.noCmhc"), font: bodyFont)
            }
            if !property.inputs.payInFull {
                draw(L10n.t("pdf.payment", Money.precise(funding.monthlyPayment)), font: bodyFont, gap: 10)
            }

            if let current = projection.year(currentYear) {
                draw(L10n.t("pdf.yearItems", current.year), font: headFont, color: ink, gap: 4)
                for line in current.lines {
                    draw("\(line.title)    \(Money.precise(line.amount))", font: bodyFont, color: ink, gap: 1)
                    draw(line.detail, font: smallFont, color: muted, gap: 5)
                }
                draw(L10n.t("pdf.total", Money.precise(current.netAnnual)), font: headFont, color: ink, gap: 8)
                if !property.inputs.payInFull {
                    draw(
                        L10n.t("pdf.principal", Money.precise(current.mortgagePrincipal), Money.precise(current.monthlyPayment), Money.precise(current.endingBalance)),
                        font: bodyFont,
                        gap: 10
                    )
                }
            }

            draw(L10n.t("pdf.until", targetYear), font: headFont, color: ink, gap: 4)
            draw(L10n.t("pdf.table"), font: smallFont, color: muted, gap: 2)
            for year in projection.years {
                let interest = year.lines.first { $0.id == "interest" }?.amount ?? 0
                let tax = year.lines.first { $0.id == "tax" }?.amount ?? 0
                let strata = year.lines.first { $0.id == "strata" }?.amount ?? 0
                draw(
                    "\(year.year)    \(Money.whole(year.netAnnual))    \(Money.whole(year.cashAnnual))    \(Money.whole(interest))    \(Money.whole(tax))    \(Money.whole(strata))    \(Money.whole(year.endingBalance))",
                    font: smallFont,
                    gap: 2
                )
            }
            y += 8

            draw(L10n.t("pdf.assume"), font: headFont, color: ink, gap: 3)
            let growth = property.inputs.projection
            draw(
                L10n.t(
                    "pdf.assume.body",
                    percentText(growth.assessmentGrowthPercent),
                    percentText(growth.taxRateGrowthPercent),
                    percentText(growth.strataInflationPercent),
                    percentText(growth.insuranceInflationPercent),
                    percentText(growth.utilitiesInflationPercent)
                ),
                font: bodyFont
            )
            draw(L10n.t("grow.note"), font: bodyFont, gap: 8)

            draw(L10n.t("pdf.sources"), font: headFont, color: ink, gap: 3)
            draw(CityBaselines.taxNote(for: property), font: bodyFont)
            draw(L10n.t("pdf.library", CityBaselines.libraryDate), font: bodyFont)
            if let policy = snapshot.policyRate {
                let asOf = snapshot.policyAsOf.map { L10n.t("mkt.asof", $0) } ?? ""
                draw("\(L10n.t("mkt.policy")) \(String(format: "%.2f", policy))% \(asOf)", font: bodyFont)
            }
            draw(L10n.t("pdf.valet"), font: smallFont, color: muted, gap: 8)

            let notes = CityBaselines.provinceNotes(property.location.provinceCode)
            if !notes.isEmpty {
                draw(L10n.t("pdf.province"), font: headFont, color: ink, gap: 3)
                for note in notes {
                    draw("• \(note)", font: bodyFont)
                }
            }
            if !property.notes.isEmpty {
                draw(L10n.t("pdf.notes"), font: headFont, color: ink, gap: 3)
                draw(property.notes, font: bodyFont)
            }
            if !projection.warnings.isEmpty {
                draw(L10n.t("pdf.check"), font: headFont, color: ink, gap: 3)
                for warning in projection.warnings {
                    draw("• \(warning)", font: bodyFont)
                }
            }

            y += 6
            draw(L10n.t("pdf.disclaimer"), font: smallFont, color: muted, gap: 2)
            finishPage()
        }
    }
}
