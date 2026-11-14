import Foundation

@main
struct Audit {
    static func main() {
        let payment = CostEngine.monthlyPayment(principal: 640_000, annualRate: 0.045, years: 25)
        expect(abs(payment - 3557.33) < 0.02, "月供 \(payment)，应约为 3557.33")

        var plain = CondoProperty()
        plain.inputs.purchasePrice = 800_000
        plain.inputs.assessedValue = 800_000
        plain.inputs.downPaymentPercent = 20
        plain.inputs.downPaymentAmount = 160_000
        plain.inputs.mortgageRatePercent = 4.5
        plain.inputs.amortYears = 25
        plain.inputs.mortgageStartYear = CalendarYear.current
        plain.inputs.includeOpportunity = false
        plain.inputs.useDirectPropertyTax = true
        plain.inputs.directPropertyTaxAnnual = 0
        plain.inputs.useMonthlyStrata = true
        plain.inputs.strataMonthly = 0
        plain.inputs.insuranceAnnual = 0
        plain.inputs.hydroMonthly = 0
        plain.inputs.internetMonthly = 0
        plain.inputs.otherMonthly = 0
        plain.inputs.levyUsesFloor = false
        plain.inputs.levyPercent = 0
        plain.location.provinceCode = "BC"
        let plainResult = CostEngine.project(plain).year(CalendarYear.current)!
        let interest = plainResult.lines.first { $0.id == "interest" }!.amount
        expect(abs(interest - 28509.95) < 0.05, "利息 \(interest)，应约为 28509.95")
        expect(abs(plainResult.mortgagePrincipal - 14177.98) < 0.05, "还本 \(plainResult.mortgagePrincipal)")
        expect(abs(plainResult.netAnnual - interest) < 0.02, "关掉其他项目后，总成本应等于利息")
        expect(plainResult.lines.contains { $0.id == "cmhc" } == false, "两成首付不应出现 CMHC")

        var insured = plain
        insured.inputs.purchasePrice = 500_000
        insured.inputs.assessedValue = 500_000
        insured.inputs.downPaymentPercent = 10
        insured.inputs.downPaymentAmount = 50_000
        insured.location.provinceCode = "ON"
        let insuredProjection = CostEngine.project(insured)
        expect(abs(insuredProjection.funding.premium - 13_950) < 0.01, "10% 首付保费应为 13950，实际 \(insuredProjection.funding.premium)")
        expect(abs(insuredProjection.funding.premiumTax - 1_116) < 0.01, "安省保费税应为 1116，实际 \(insuredProjection.funding.premiumTax)")
        expect(abs(insuredProjection.funding.totalLoan - 463_950) < 0.01, "保费应计入贷款")

        var taxed = plain
        taxed.inputs.useDirectPropertyTax = false
        taxed.inputs.propertyTaxPercent = 0.336394
        taxed.inputs.taxRateOfficial = true
        taxed.inputs.assessedValue = 800_000
        taxed.location.provinceCode = "BC"
        let tax = CostEngine.project(taxed).year(CalendarYear.current)!.lines.first { $0.id == "tax" }!.amount
        expect(abs(tax - 2_691.15) < 0.02, "温哥华地税 \(tax)，应为 2691.15")

        var future = taxed
        future.inputs.projection.targetYear = CalendarYear.current + 1
        future.inputs.projection.assessmentGrowthPercent = 0
        future.inputs.projection.taxRateGrowthPercent = 0
        future.inputs.includeOpportunity = true
        future.inputs.riskFreePercent = 4
        let years = CostEngine.project(future)
        let thisYear = years.year(CalendarYear.current)!
        let nextYear = years.year(CalendarYear.current + 1)!
        let opportunity = thisYear.lines.first { $0.id == "opportunity" }!.amount
        expect(abs(opportunity - 6_400) < 0.02, "机会成本 \(opportunity)，应为 6400")
        expect(nextYear.lines.first { $0.id == "interest" }!.amount < interest, "第二年利息应下降")

        var cash = plain
        cash.inputs.payInFull = true
        cash.inputs.includeOpportunity = true
        cash.inputs.riskFreePercent = 4
        let cashProjection = CostEngine.project(cash)
        let cashYear = cashProjection.year(CalendarYear.current)!
        expect(cashProjection.funding.totalLoan == 0, "全款贷款应为 0，实际 \(cashProjection.funding.totalLoan)")
        expect(cashYear.lines.first { $0.id == "interest" }!.amount == 0, "全款利息应为 0")
        let cashOpportunity = cashYear.lines.first { $0.id == "opportunity" }!.amount
        expect(abs(cashOpportunity - 32_000) < 0.02, "全款机会成本 \(cashOpportunity)，应为 32000")

        var document = PortfolioDocument()
        document.properties = [taxed]
        let data = try! PortfolioDocument.encoder.encode(document)
        let decoded = try! PortfolioDocument.decoder.decode(PortfolioDocument.self, from: data)
        expect(decoded.properties.first?.inputs.propertyTaxPercent == 0.336394, "JSON 应保留税率")

        var detached = HouseEstimate()
        detached.kind = .detached
        detached.purchasePrice = 1_000_000
        detached.downPaymentPercent = 20
        detached.payInFull = false
        detached.mortgageRatePercent = 5
        detached.amortYears = 25
        detached.occupancy = .principal
        detached.assessedValue = 800_000
        detached.propertyTaxPercent = 0.4
        detached.useDirectTax = false
        detached.waterAnnual = 480
        detached.sewerAnnual = 360
        detached.garbageAnnual = 300
        detached.useUtilityBills = true
        detached.hydroMonthly = 150
        detached.gasMonthly = 100
        detached.heating = .gasForcedAir
        detached.useQuotedInsurance = true
        detached.quotedInsuranceAnnual = 2_400
        detached.maintenanceMode = .percentOfValue
        detached.maintenancePercent = 1
        detached.hasStrata = false
        detached.finishedSqft = 2_000
        detached.grossIncomeAnnual = 200_000
        let house = HouseCostEngine.evaluate(detached)
        let housePayment = CostEngine.monthlyPayment(principal: 800_000, annualRate: 0.05, years: 25)
        expect(abs(house.contractPayment - housePayment) < 0.02, "独栋月供 \(house.contractPayment)")
        expect(house.lines.first { $0.id == "tax" }!.amount == 3_200, "独栋地税")
        expect(house.lines.first { $0.id == "muni" }!.amount == 1_140, "市政费用")
        expect(house.lines.first { $0.id == "strata" }!.amount == 0, "独栋没有管理费")
        expect(house.lines.first { $0.id == "insurance" }!.amount == 2_400, "报价保费")
        expect(house.lines.first { $0.id == "energy" }!.amount == 3_000, "账单能源")
        expect(house.lines.first { $0.id == "maint" }!.amount == 10_000, "1% 维护")
        expect(house.lines.first { $0.id == "levy" }!.amount == 0, "没有特别征费")
        let expectedAnnual = house.lines.reduce(0) { $0 + $1.amount }
        expect(abs(house.annual - expectedAnnual) < 0.02, "年度现金流应等于分项之和")
        let roundedPayment = (housePayment * 100).rounded() / 100
        let expectedGDS = roundedPayment + 3_200 / 12 + 1_200 / 12
        let roundedGDS = (expectedGDS * 100).rounded() / 100
        expect(abs(house.gdsHousing - roundedGDS) < 0.05, "GDS 住房成本 \(house.gdsHousing)")
        expect(abs(house.qualifyingRate - 7) < 0.001, "压力测试利率")

        var cashHouse = detached
        cashHouse.payInFull = true
        let cashHouseResult = HouseCostEngine.evaluate(cashHouse)
        expect(cashHouseResult.contractPayment == 0, "全款独栋没有月供")
        expect(cashHouseResult.lines.first { $0.id == "pi" }!.amount == 0, "全款本息为 0")

        var thin = HouseEstimate.make(kind: .townhouse)
        thin.crfRatioPercent = 10
        thin.strataMonthly = 400
        thin.levyPercent = 5
        let thinResult = HouseCostEngine.evaluate(thin)
        expect(thinResult.warnings.contains { $0.contains("10") || $0.contains("10.0") || $0.contains("10,0") }, "储备金偏低应出现提示")
        expect(thinResult.lines.first { $0.id == "levy" }!.amount == 1_200, "偏低储备金时准备金至少按 25%")

        document.houses = [detached]
        let houseData = try! PortfolioDocument.encoder.encode(document)
        let houseDecoded = try! PortfolioDocument.decoder.decode(PortfolioDocument.self, from: houseData)
        expect(houseDecoded.houses.first?.quotedInsuranceAnnual == 2_400, "独栋 JSON 应保留保费")
        expect(houseDecoded.properties.count == 1, "原有公寓记录仍在")

        var located = HouseEstimate.make(kind: .townhouse)
        located.finishedSqft = 1_600
        located.estimatesAreSuggested = true
        located.apply(place: PlaceCandidate(
            id: UUID(),
            title: "123 Main Street",
            subtitle: "Vancouver",
            latitude: 49.28,
            longitude: -123.12,
            city: "Vancouver",
            provinceCode: "BC",
            postalCode: "V6B 1A1",
            address: "123 Main Street, Vancouver, BC, V6B 1A1"
        ))
        expect(abs(located.propertyTaxPercent - 0.336394) < 0.000001, "温哥华税率 \(located.propertyTaxPercent)")
        expect(located.heatingDegreeDays == 2900, "沿海邮编供暖度日")
        expect(located.seismic, "不列颠哥伦比亚应标为地震带")
        expect(located.heating == .gasForcedAir, "不列颠哥伦比亚常见供暖")
        expect(located.strataMonthly > 0, "联排应按面积给出管理费估算")
        expect(located.name == "123 Main Street", "默认名称应换成地址")
        located.estimatesAreSuggested = false
        located.propertyTaxPercent = 0.5
        located.apply(place: PlaceCandidate(
            id: UUID(),
            title: "1 King Street",
            subtitle: "Toronto",
            latitude: 43.65,
            longitude: -79.38,
            city: "Toronto",
            provinceCode: "ON",
            postalCode: "M5H 1A1",
            address: "1 King Street, Toronto, ON"
        ))
        expect(located.propertyTaxPercent == 0.5, "经纪改过的税率不应被下一次定位覆盖")
        expect(located.location.city == "Toronto", "地址仍应更新")

        let torontoHTML = "<td>Residential</td><td>0.605295%</td><td>0.153000%</td><td>0.009016%</td><td>0.767311%</td><td>Multi-Residential</td>"
        expect(ReferenceLibrary.parseToronto(torontoHTML) == 0.767311, "多伦多住宅合计税率")
        let calgaryHTML = ">Residential<\n0.0038906\n0.0027593\n0.0066499\nNon-Residential"
        expect(abs((ReferenceLibrary.parseCalgary(calgaryHTML) ?? 0) - 0.66499) < 0.000001, "卡尔加里合计税率")
        let vancouverHTML = "Total</td><td>$3.36394</td><td>$3.11827</td>"
        expect(abs((ReferenceLibrary.parseVancouver(vancouverHTML) ?? 0) - 0.336394) < 0.000001, "温哥华每千元税率")
        expect(ReferenceLibrary.parseToronto("<td>Residential</td><td>9%</td>") == nil, "对不上的页面不应写成税率")
        print("AUDIT OK")
    }

    static func expect(_ condition: Bool, _ message: String) {
        if !condition {
            fputs("AUDIT FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
