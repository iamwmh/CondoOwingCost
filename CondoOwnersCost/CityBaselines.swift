//
//  CityBaselines.swift
//  CondoOwnersCost
//

import Foundation

nonisolated struct CityBaseline: Identifiable, Equatable, Hashable {
    var id: String
    var nameZH: String
    var nameEN: String
    var provinceCode: String
    var propertyTaxPercent: Double
    var taxYear: Int
    var taxIsOfficial: Bool
    var source: String
    var url: String?
    var strataMonthlyPerSqft: Double
    var insuranceAnnual: Double
    var hydroMonthly: Double
    var internetMonthly: Double
    var notes: String
    var refreshedFromWeb: Bool = false

    var localizedName: String {
        switch L10n.language {
        case .zhHans: nameZH
        case .en: nameEN
        case .frCA:
            switch id {
            case "montreal": "Montréal"
            case "quebec-city": "Québec"
            default: nameEN
            }
        }
    }

    var menuTitle: String {
        taxIsOfficial ? localizedName : L10n.t("city.reference", localizedName)
    }

    func localizedSource() -> String {
        let rate = String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), propertyTaxPercent)
        let key = taxIsOfficial ? "tax.source.official" : "tax.source.estimate"
        var text = L10n.t(key, localizedName, taxYear, rate)
        if refreshedFromWeb { text += " " + L10n.t("tax.checked", CityBaselines.libraryDate) }
        if id == "winnipeg" { text += " " + L10n.t("tax.note.winnipeg") }
        if id.hasPrefix("province-") { text += " " + L10n.t("tax.note.province") }
        return text
    }

    func suggestedStrata(yearBuilt: Int, pool: Bool, concierge: Bool, year: Int) -> Double {
        var rate = strataMonthlyPerSqft
        let age = max(0, year - yearBuilt)
        if age >= 30 { rate += 0.10 }
        else if age >= 20 { rate += 0.06 }
        else if age >= 10 { rate += 0.03 }
        if pool { rate += 0.08 }
        if concierge { rate += 0.10 }
        return min(1.25, max(0.40, (rate * 100).rounded() / 100))
    }
}

nonisolated enum CityBaselines {
    private static let bundledLibraryDate = "2026-11-05"
    private static let lock = NSLock()
    private static var didLoad = false
    private static var overrides: [String: StoredCityRate] = [:]
    private static var checkedAt: Date?

    static var libraryDate: String {
        ensureLoaded()
        lock.lock()
        let date = checkedAt
        lock.unlock()
        guard let date else { return bundledLibraryDate }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_CA")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func install(_ file: ReferenceLibraryFile) {
        lock.lock()
        overrides = file.rates
        checkedAt = file.checkedAt
        didLoad = true
        lock.unlock()
    }

    private static func ensureLoaded() {
        lock.lock()
        let ready = didLoad
        lock.unlock()
        guard !ready else { return }
        let file = ReferenceLibrary.read()
        lock.lock()
        if !didLoad {
            overrides = file.rates
            checkedAt = file.checkedAt
            didLoad = true
        }
        lock.unlock()
    }

    private static func savedRate(for id: String) -> StoredCityRate? {
        ensureLoaded()
        lock.lock()
        let rate = overrides[id]
        lock.unlock()
        return rate
    }

    static var catalog: [CityBaseline] {
        bundled.map { city in
            guard let saved = savedRate(for: city.id) else { return city }
            var copy = city
            copy.propertyTaxPercent = saved.propertyTaxPercent
            copy.taxYear = saved.taxYear
            copy.taxIsOfficial = true
            copy.refreshedFromWeb = true
            copy.url = saved.sourceURL
            return copy
        }
    }

    static var byID: [String: CityBaseline] {
        Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    }

    private static let bundled: [CityBaseline] = [
        city("vancouver", "温哥华", "Vancouver", "BC", 0.336394, 2026, true,
             "City of Vancouver 住宅合计征费率，每千元应税价值 $3.36394，含市政、学税、TransLink、BC Assessment 与 Metro Vancouver。",
             "https://vancouver.ca/home-property-development/residential.aspx", 0.72, 1050, 55),
        city("surrey", "素里", "Surrey", "BC", 0.3427, 2026, true,
             "2026 住宅合计税率收录值。", nil, 0.58, 900, 55),
        city("burnaby", "本拿比", "Burnaby", "BC", 0.36, 2026, false,
             "未单独写入正式税率，暂用大温参考。请以税单为准。", nil, 0.68, 980, 55,
             "本拿比税率请改成当年税单。"),
        city("richmond", "列治文", "Richmond", "BC", 0.34, 2026, false,
             "未单独写入正式税率，暂用大温参考。", nil, 0.65, 960, 55),
        city("coquitlam", "高贵林", "Coquitlam", "BC", 0.40, 2026, false,
             "未单独写入正式税率，暂用大温参考。", nil, 0.62, 920, 55),
        city("north-vancouver", "北温哥华", "North Vancouver", "BC", 0.32, 2026, false,
             "未单独写入正式税率，暂用北岸参考。", nil, 0.70, 1000, 55),
        city("west-vancouver", "西温哥华", "West Vancouver", "BC", 0.28, 2026, false,
             "未单独写入正式税率，暂用北岸参考。", nil, 0.75, 1100, 55),
        city("victoria", "维多利亚", "Victoria", "BC", 0.50, 2026, false,
             "未单独写入正式税率，暂用温哥华岛参考。", nil, 0.62, 900, 55),

        city("toronto", "多伦多", "Toronto", "ON", 0.767311, 2026, true,
             "City of Toronto 2026 住宅合计税率，含市政税、教育税与 City Building Fund。",
             "https://www.toronto.ca/services-payments/property-taxes-utilities/property-tax/property-tax-rates-and-fees/",
             0.68, 900, 80),
        city("ottawa", "渥太华", "Ottawa", "ON", 1.2271, 2025, true,
             "2025 住宅合计税率。2026 税率未写入本地库。", nil, 0.58, 820, 75),
        city("mississauga", "密西沙加", "Mississauga", "ON", 1.0879, 2026, true,
             "2026 住宅合计税率收录值。", nil, 0.62, 860, 80),
        city("brampton", "宾顿", "Brampton", "ON", 1.2534, 2026, true,
             "2026 住宅合计税率收录值。", nil, 0.60, 840, 80),
        city("hamilton", "汉密尔顿", "Hamilton", "ON", 1.5572, 2026, true,
             "2026 住宅合计税率收录值。", nil, 0.58, 820, 75),
        city("london", "伦敦", "London", "ON", 1.7271, 2026, true,
             "安省伦敦 2026 住宅合计税率收录值。", nil, 0.55, 780, 75),
        city("markham", "万锦", "Markham", "ON", 0.7229, 2026, true,
             "2026 住宅合计税率收录值。", nil, 0.62, 880, 80),
        city("vaughan", "旺市", "Vaughan", "ON", 0.7492, 2026, true,
             "2026 住宅合计税率收录值。", nil, 0.62, 880, 80),
        city("kitchener", "基奇纳", "Kitchener", "ON", 1.4060, 2026, true,
             "2026 住宅合计税率收录值。", nil, 0.55, 780, 75),

        city("calgary", "卡尔加里", "Calgary", "AB", 0.66499, 2026, true,
             "City of Calgary 2026 住宅合计税率，含市政与省教育税。",
             "https://www.calgary.ca/property-owners/taxes/bill-rate-calculation.html",
             0.52, 720, 90),
        city("edmonton", "埃德蒙顿", "Edmonton", "AB", 1.0364, 2026, true,
             "2026 住宅合计税率收录值。", nil, 0.48, 700, 90),

        city("montreal", "蒙特利尔", "Montreal", "QC", 0.6346, 2026, true,
             "2026 住宅合计税率收录值。", nil, 0.55, 780, 45),
        city("quebec-city", "魁北克市", "Quebec City", "QC", 0.8254, 2026, true,
             "2026 住宅合计税率收录值。", nil, 0.52, 740, 45),
        city("laval", "拉瓦尔", "Laval", "QC", 0.6699, 2026, true,
             "2026 住宅合计税率收录值。", nil, 0.52, 740, 45),
        city("gatineau", "加蒂诺", "Gatineau", "QC", 0.8261, 2026, true,
             "2026 住宅合计税率收录值。", nil, 0.50, 720, 45),

        city("winnipeg", "温尼伯", "Winnipeg", "MB", 1.16, 2026, false,
             "市值有效税率估算。温尼伯名义税率作用在分摊后的评估值上，不能直接乘市价。",
             nil, 0.52, 760, 70,
             "请优先改成税单上的全年税额。"),
        city("saskatoon", "萨斯卡通", "Saskatoon", "SK", 1.3083, 2026, true,
             "2026 住宅合计税率收录值。", nil, 0.50, 740, 80),
        city("halifax", "哈利法克斯", "Halifax", "NS", 1.1350, 2026, true,
             "2026 住宅合计税率收录值。", nil, 0.50, 760, 90),

        province("province-bc", "不列颠哥伦比亚", "British Columbia", "BC", 0.45, 0.62, 900, 55),
        province("province-on", "安大略", "Ontario", "ON", 1.05, 0.60, 840, 80),
        province("province-ab", "艾伯塔", "Alberta", "AB", 0.80, 0.50, 720, 90),
        province("province-qc", "魁北克", "Quebec", "QC", 0.75, 0.52, 760, 45),
        province("province-mb", "曼尼托巴", "Manitoba", "MB", 1.15, 0.50, 740, 70),
        province("province-sk", "萨斯喀彻温", "Saskatchewan", "SK", 1.20, 0.50, 740, 80),
        province("province-ns", "新斯科舍", "Nova Scotia", "NS", 1.10, 0.50, 760, 90),
        province("province-nb", "新不伦瑞克", "New Brunswick", "NB", 1.15, 0.50, 740, 85),
        province("province-pe", "爱德华王子岛", "Prince Edward Island", "PE", 1.10, 0.50, 740, 90),
        province("province-nl", "纽芬兰与拉布拉多", "Newfoundland and Labrador", "NL", 0.95, 0.50, 760, 95)
    ]

    static var selectableGroups: [(code: String, name: String, cities: [CityBaseline])] {
        let order = ["BC", "ON", "AB", "QC", "MB", "SK", "NS"]
        return order.compactMap { code in
            let cities = catalog.filter { $0.provinceCode == code && !$0.id.hasPrefix("province-") }
            guard !cities.isEmpty else { return nil }
            return (code, provinceName(code), cities)
        }
    }

    static func match(city: String, province: String) -> CityBaseline? {
        let cityKey = normalize(city).split(separator: ",").first.map(String.init) ?? ""
        let provinceKey = provinceCode(from: province)
        if let provinceKey, let id = aliases["\(cityKey)|\(provinceKey)"], let found = byID[id] {
            return found
        }
        if let id = aliases[cityKey], let found = byID[id] {
            if let provinceKey, found.provinceCode != provinceKey {
                return byID["province-\(provinceKey.lowercased())"]
            }
            return found
        }
        if let provinceKey {
            return byID["province-\(provinceKey.lowercased())"]
        }
        return nil
    }

    static func provinceName(_ code: String) -> String {
        let key = "prov.\(code.uppercased())"
        let name = L10n.t(key)
        return name == key ? code : name
    }

    static func taxNote(for property: CondoProperty) -> String {
        let raw = property.inputs.taxSourceNote
        if raw == "manual" || raw == "手工填写的税率。" {
            return L10n.t("tax.manual")
        }
        if raw == "placeholder" || raw == "尚未套用城市税率，当前是占位值。" {
            return L10n.t("tax.placeholder")
        }
        if let id = property.location.appliedBaselineID, let city = byID[id] {
            return city.localizedSource()
        }
        return raw.isEmpty ? L10n.t("tax.placeholder") : raw
    }

    static func provinceCode(from raw: String) -> String? {
        let key = normalize(raw)
        return provinceAliases[key]
    }

    static func provinceNotes(_ code: String) -> [String] {
        let keys: [String]
        switch code.uppercased() {
        case "BC": keys = ["note.bc.1", "note.bc.2", "note.bc.3"]
        case "ON": keys = ["note.on.1", "note.on.2", "note.on.3"]
        case "AB": keys = ["note.ab.1", "note.ab.2"]
        case "QC": keys = ["note.qc.1", "note.qc.2"]
        case "SK": keys = ["note.sk.1"]
        default: keys = ["note.other.1"]
        }
        return keys.map { L10n.t($0) }
    }

    static func premiumSalesTaxRate(provinceCode: String) -> Double {
        switch provinceCode.uppercased() {
        case "ON": 0.08
        case "QC": 0.09
        case "SK": 0.06
        default: 0
        }
    }

    private static func city(
        _ id: String,
        _ zh: String,
        _ en: String,
        _ province: String,
        _ tax: Double,
        _ year: Int,
        _ official: Bool,
        _ source: String,
        _ url: String?,
        _ strata: Double,
        _ insurance: Double,
        _ hydro: Double,
        _ notes: String = ""
    ) -> CityBaseline {
        CityBaseline(
            id: id,
            nameZH: zh,
            nameEN: en,
            provinceCode: province,
            propertyTaxPercent: tax,
            taxYear: year,
            taxIsOfficial: official,
            source: source,
            url: url,
            strataMonthlyPerSqft: strata,
            insuranceAnnual: insurance,
            hydroMonthly: hydro,
            internetMonthly: 80,
            notes: notes
        )
    }

    private static func province(
        _ id: String,
        _ zh: String,
        _ en: String,
        _ code: String,
        _ tax: Double,
        _ strata: Double,
        _ insurance: Double,
        _ hydro: Double
    ) -> CityBaseline {
        CityBaseline(
            id: id,
            nameZH: zh,
            nameEN: en,
            provinceCode: code,
            propertyTaxPercent: tax,
            taxYear: 2026,
            taxIsOfficial: false,
            source: "未匹配到具体城市，使用全省粗略参考，不能代替税单。",
            url: nil,
            strataMonthlyPerSqft: strata,
            insuranceAnnual: insurance,
            hydroMonthly: hydro,
            internetMonthly: 80,
            notes: "省级参考"
        )
    }

    private static func normalize(_ raw: String) -> String {
        var key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_CA"))
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: ".", with: "")
        while key.contains("  ") {
            key = key.replacingOccurrences(of: "  ", with: " ")
        }
        key = key.replacingOccurrences(of: "-", with: " ")
        for prefix in ["city of ", "ville de ", "the "] where key.hasPrefix(prefix) {
            key.removeFirst(prefix.count)
        }
        return key.trimmingCharacters(in: .whitespaces)
    }

    private static let provinceAliases: [String: String] = [
        "bc": "BC", "british columbia": "BC", "colombie britannique": "BC", "不列颠哥伦比亚": "BC", "不列颠哥伦比亚省": "BC", "卑诗": "BC", "卑诗省": "BC",
        "on": "ON", "ontario": "ON", "安大略": "ON", "安大略省": "ON", "安省": "ON",
        "ab": "AB", "alberta": "AB", "艾伯塔": "AB", "艾伯塔省": "AB", "阿尔伯塔": "AB", "亚省": "AB",
        "qc": "QC", "quebec": "QC", "québec": "QC", "魁北克": "QC", "魁北克省": "QC",
        "mb": "MB", "manitoba": "MB", "曼尼托巴": "MB", "曼尼托巴省": "MB",
        "sk": "SK", "saskatchewan": "SK", "萨斯喀彻温": "SK", "萨省": "SK",
        "ns": "NS", "nova scotia": "NS", "nouvelle ecosse": "NS", "新斯科舍": "NS", "新斯科舍省": "NS",
        "nb": "NB", "new brunswick": "NB", "nouveau brunswick": "NB", "新不伦瑞克": "NB", "新不伦瑞克省": "NB",
        "pe": "PE", "pei": "PE", "prince edward island": "PE", "ile du prince edouard": "PE", "爱德华王子岛": "PE",
        "nl": "NL", "newfoundland and labrador": "NL", "newfoundland": "NL", "terre neuve et labrador": "NL", "纽芬兰与拉布拉多": "NL", "纽芬兰": "NL",
        "yt": "YT", "yukon": "YT", "育空": "YT",
        "nt": "NT", "northwest territories": "NT", "西北地区": "NT",
        "nu": "NU", "nunavut": "NU", "努纳武特": "NU"
    ]

    private static let aliases: [String: String] = [
        "vancouver": "vancouver", "温哥华": "vancouver",
        "surrey": "surrey", "素里": "surrey",
        "burnaby": "burnaby", "本拿比": "burnaby", "本那比": "burnaby",
        "richmond": "richmond", "列治文": "richmond",
        "coquitlam": "coquitlam", "高贵林": "coquitlam",
        "north vancouver": "north-vancouver", "北温哥华": "north-vancouver", "北温": "north-vancouver",
        "west vancouver": "west-vancouver", "西温哥华": "west-vancouver", "西温": "west-vancouver",
        "victoria": "victoria", "维多利亚": "victoria",
        "toronto": "toronto", "多伦多": "toronto",
        "north york": "toronto", "scarborough": "toronto", "etobicoke": "toronto", "east york": "toronto",
        "downtown toronto": "toronto",
        "ottawa": "ottawa", "渥太华": "ottawa",
        "mississauga": "mississauga", "密西沙加": "mississauga",
        "brampton": "brampton", "宾顿": "brampton", "布兰普顿": "brampton",
        "hamilton": "hamilton", "汉密尔顿": "hamilton",
        "london": "london", "伦敦": "london",
        "markham": "markham", "万锦": "markham",
        "vaughan": "vaughan", "旺市": "vaughan",
        "kitchener": "kitchener", "基奇纳": "kitchener",
        "calgary": "calgary", "卡尔加里": "calgary",
        "edmonton": "edmonton", "埃德蒙顿": "edmonton", "爱民顿": "edmonton",
        "montreal": "montreal", "蒙特利尔": "montreal", "满地可": "montreal",
        "quebec city": "quebec-city", "quebec": "quebec-city", "魁北克市": "quebec-city", "魁北克城": "quebec-city",
        "laval": "laval", "拉瓦尔": "laval",
        "gatineau": "gatineau", "加蒂诺": "gatineau",
        "winnipeg": "winnipeg", "温尼伯": "winnipeg",
        "saskatoon": "saskatoon", "萨斯卡通": "saskatoon",
        "halifax": "halifax", "哈利法克斯": "halifax"
    ]
}
