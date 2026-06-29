import Foundation
import UserNotifications

@MainActor
final class QuoteStore: ObservableObject {
    @Published var customers: [Customer] = [] {
        didSet { save(customers, key: customersKey) }
    }

    @Published var quotes: [Quote] = [] {
        didSet { save(quotes, key: quotesKey) }
    }

    @Published var company: CompanyProfile = .default {
        didSet { save(company, key: companyKey) }
    }

    @Published var dueReminderEnabled = false {
        didSet { UserDefaults.standard.set(dueReminderEnabled, forKey: reminderKey) }
    }

    @Published var appLockEnabled = false {
        didSet { UserDefaults.standard.set(appLockEnabled, forKey: appLockKey) }
    }

    @Published var isDarkMode = false {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: darkModeKey) }
    }

    @Published var appLanguage: AppLanguage = .japanese {
        didSet { save(appLanguage, key: languageKey) }
    }

    @Published var currency: CurrencyOption = .jpy {
        didSet { save(currency, key: currencyKey) }
    }

    private let customersKey = "pdfapp.customers"
    private let quotesKey = "pdfapp.quotes"
    private let companyKey = "pdfapp.company"
    private let reminderKey = "pdfapp.reminder"
    private let appLockKey = "pdfapp.lock"
    private let darkModeKey = "quantaflow.darkMode"
    private let languageKey = "quantaflow.language"
    private let currencyKey = "quantaflow.currency"
    private let legacyDemoCleanupKey = "quantaflow.legacyDemoCleanup.v2"

    init(seedDemo: Bool = false) {
        if seedDemo {
            resetDemoData()
        } else {
            loadState()
        }
    }

    func makeDraft() -> Quote {
        var quote = Quote.draft(number: nextQuoteNumber())
        quote.currencySymbol = currency.symbol
        quote.logoData = company.logoData
        return quote
    }

    @discardableResult
    func addCustomer(_ customer: Customer) -> Customer {
        var saved = customer
        if customers.contains(where: { $0.id == saved.id }) {
            saved.id = UUID()
        }
        saved.lastUpdated = Date()
        customers.insert(saved, at: 0)
        return saved
    }

    @discardableResult
    func saveCustomer(_ customer: Customer) -> Customer {
        var saved = customer
        saved.lastUpdated = Date()
        if let index = customers.firstIndex(where: { $0.id == saved.id }) {
            customers[index] = saved
        } else {
            if customers.contains(where: { $0.id == saved.id }) {
                saved.id = UUID()
            }
            customers.insert(saved, at: 0)
        }
        for index in quotes.indices where quotes[index].customer?.id == saved.id {
            quotes[index].customer = saved
        }
        return saved
    }

    func deleteCustomer(_ customer: Customer) {
        customers.removeAll { $0.id == customer.id }
        for index in quotes.indices where quotes[index].customer?.id == customer.id {
            quotes[index].customer = nil
        }
    }

    func saveQuote(_ quote: Quote) {
        var saved = quoteWithUniqueNumber(quote)
        if saved.currencySymbol.isEmpty {
            saved.currencySymbol = currency.symbol
        }
        if let index = quotes.firstIndex(where: { $0.id == saved.id }) {
            quotes[index] = saved
        } else {
            quotes.insert(saved, at: 0)
        }
        sortQuotesBySystemNumber()
    }

    func deleteQuote(_ quote: Quote) {
        if let url = urlForSavedPDF(quote) {
            try? FileManager.default.removeItem(at: url)
        }
        quotes.removeAll { $0.id == quote.id }
    }

    func updateStatus(for quoteID: Quote.ID, to status: QuoteStatus) {
        guard let index = quotes.firstIndex(where: { $0.id == quoteID }) else { return }
        quotes[index].status = status
    }

    func exportPDF(for quote: Quote) throws -> URL {
        var exported = quoteWithUniqueNumber(quote)
        exported.pdfStyle = .simple
        exported.issueDate = quote.issueDate
        if exported.status == .draft {
            exported.status = .processing
        }
        if exported.logoData == nil {
            exported.logoData = company.logoData
        }
        let fileName = "\(quote.quoteNumber.replacingOccurrences(of: "/", with: "-")).pdf"
        let url = documentsDirectory().appendingPathComponent(fileName)
        try QuotePDFRenderer.render(quote: exported, company: company, language: appLanguage, to: url)
        exported.pdfFileName = fileName
        saveQuote(exported)
        return url
    }

    func exportSalesReport(period: SalesReportPeriod) throws -> URL {
        let now = Date()
        let calendar = Calendar.current
        let filtered = quotes.filter { quote in
            switch period {
            case .month:
                return calendar.isDate(quote.issueDate, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(quote.issueDate, equalTo: now, toGranularity: .year)
            }
        }
        .sorted { lhs, rhs in
            if lhs.sequenceNumber == rhs.sequenceNumber {
                return lhs.issueDate > rhs.issueDate
            }
            return lhs.sequenceNumber > rhs.sequenceNumber
        }
        let fileName = "Quantaflow_\(appLanguage.localized(period.rawValue))_\(appLanguage.localized("業績")).xlsx"
        let url = documentsDirectory().appendingPathComponent(fileName)
        let data = ExcelReportRenderer.render(period: period, quotes: filtered, language: appLanguage)
        try data.write(to: url, options: .atomic)
        return url
    }

    func urlForSavedPDF(_ quote: Quote) -> URL? {
        guard let fileName = quote.pdfFileName else { return nil }
        let url = documentsDirectory().appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func resetDemoData() {
        customers = []
        quotes = []
        company = .default
        currency = .jpy
    }

    func setDueReminderEnabled(_ enabled: Bool) {
        dueReminderEnabled = enabled
        if enabled {
            scheduleReminder()
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["quantaflow.dueReminder"])
        }
    }

    private func nextQuoteNumber() -> String {
        let year = Calendar.current.component(.year, from: Date())
        let usedNumbers = quotes.compactMap { quote -> Int? in
            quote.quoteNumber.split(separator: "-").last.flatMap { Int($0) }
        }
        let next = (usedNumbers.max() ?? 0) + 1
        return String(format: "Q-%d-%06d", year, next)
    }

    private func quoteWithUniqueNumber(_ quote: Quote) -> Quote {
        var saved = quote
        if quotes.contains(where: { $0.id != saved.id && $0.quoteNumber == saved.quoteNumber }) {
            saved.quoteNumber = nextQuoteNumber()
        }
        return saved
    }

    private func sortQuotesBySystemNumber() {
        quotes.sort { lhs, rhs in
            if lhs.sequenceNumber == rhs.sequenceNumber {
                return lhs.issueDate > rhs.issueDate
            }
            return lhs.sequenceNumber > rhs.sequenceNumber
        }
    }

    private func repairDuplicateQuoteNumbers() {
        var usedNumbers: Set<String> = []
        var nextSequence = (quotes.map(\.sequenceNumber).max() ?? 0) + 1
        let year = Calendar.current.component(.year, from: Date())

        for index in quotes.indices.sorted(by: { quotes[$0].issueDate < quotes[$1].issueDate }) {
            let number = quotes[index].quoteNumber
            if usedNumbers.contains(number) {
                var repairedNumber = String(format: "Q-%d-%06d", year, nextSequence)
                while usedNumbers.contains(repairedNumber) {
                    nextSequence += 1
                    repairedNumber = String(format: "Q-%d-%06d", year, nextSequence)
                }
                quotes[index].quoteNumber = repairedNumber
                usedNumbers.insert(repairedNumber)
                nextSequence += 1
            } else {
                usedNumbers.insert(number)
            }
        }
    }

    private func repairCustomerRecords() {
        var usedIDs: Set<UUID> = []
        var usedFingerprints: Set<String> = []
        var fixedCustomers: [Customer] = []
        var fixedIDByFingerprint: [String: UUID] = [:]

        for var customer in customers {
            let fingerprint = customerFingerprint(customer)
            if usedFingerprints.contains(fingerprint) {
                continue
            }

            if usedIDs.contains(customer.id) {
                customer.id = UUID()
            }

            usedIDs.insert(customer.id)
            usedFingerprints.insert(fingerprint)
            fixedIDByFingerprint[fingerprint] = customer.id
            fixedCustomers.append(customer)
        }

        customers = fixedCustomers

        for index in quotes.indices {
            guard var customer = quotes[index].customer else { continue }
            let fingerprint = customerFingerprint(customer)
            guard let fixedID = fixedIDByFingerprint[fingerprint], fixedID != customer.id else { continue }
            customer.id = fixedID
            quotes[index].customer = customer
        }
    }

    private func customerFingerprint(_ customer: Customer) -> String {
        [
            customer.name,
            customer.company,
            customer.registrationNumber,
            customer.phone,
            customer.email,
            customer.address
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .joined(separator: "||")
    }

    private func loadState() {
        customers = load([Customer].self, key: customersKey) ?? []
        quotes = load([Quote].self, key: quotesKey) ?? []
        company = load(CompanyProfile.self, key: companyKey) ?? .default
        dueReminderEnabled = UserDefaults.standard.bool(forKey: reminderKey)
        appLockEnabled = UserDefaults.standard.bool(forKey: appLockKey)
        isDarkMode = UserDefaults.standard.bool(forKey: darkModeKey)
        appLanguage = loadLanguage()
        currency = load(CurrencyOption.self, key: currencyKey) ?? .jpy
        purgeLegacyDemoDataIfNeeded()
        repairCustomerRecords()
        repairDuplicateQuoteNumbers()
        sortQuotesBySystemNumber()
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func loadLanguage() -> AppLanguage {
        if let language = load(AppLanguage.self, key: languageKey) {
            return language
        }
        guard
            let data = UserDefaults.standard.data(forKey: languageKey),
            let legacyRawValue = try? JSONDecoder().decode(String.self, from: data),
            legacyRawValue == "中文"
        else {
            return .japanese
        }
        return .chinese
    }

    private func purgeLegacyDemoDataIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: legacyDemoCleanupKey) else { return }
        customers.removeAll { customer in
            customer.company == "Wew Design" &&
            customer.email == "hello@example.com" &&
            customer.phone == "090-0000-0000"
        }
        quotes.removeAll { quote in
            quote.quoteNumber == "Q-2026-000002" &&
            quote.customer?.company == "Wew Design"
        }
        UserDefaults.standard.set(true, forKey: legacyDemoCleanupKey)
    }

    private func scheduleReminder() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Quantaflow"
            content.body = "期限が近い見積書を確認してください。"
            content.sound = .default
            var date = DateComponents()
            date.hour = 9
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(identifier: "quantaflow.dueReminder", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }
}

extension QuoteStore {
    static var preview: QuoteStore {
        QuoteStore(seedDemo: true)
    }
}

enum ExcelReportRenderer {
    private struct SheetCell {
        let column: Int
        let value: String
        let style: Int
    }

    private struct SheetRow {
        let index: Int
        let cells: [SheetCell]
    }

    fileprivate struct ZipEntry {
        let path: String
        let data: Data
    }

    static func render(period: SalesReportPeriod, quotes: [Quote], language: AppLanguage) -> Data {
        let totalsByCurrency = Dictionary(grouping: quotes, by: \.currencySymbol)
            .mapValues { $0.reduce(0) { $0 + $1.grandTotal } }
            .sorted { $0.key < $1.key }

        let headers = [
            "A. 見積番号", "B. 発行日", "C. 有効期限", "D. 宛先（顧客名）", "E. 項目",
            "F. 単価", "G. 数量", "H. 金額（税抜）", "I. 割引($)", "J. 割引(%)",
            "K. 消費税（%）", "L. 消費税（$）", "M. 合計（税込）"
        ]
        let title = "Quantaflow - \(language.localized(period.rawValue)) \(language.localized("業績"))"
        var rows: [SheetRow] = [
            SheetRow(index: 1, cells: [SheetCell(column: 1, value: title, style: 1)]),
            SheetRow(index: 2, cells: headers.enumerated().map { SheetCell(column: $0.offset + 1, value: language.localized($0.element), style: 2) })
        ]

        if quotes.isEmpty {
            rows.append(SheetRow(index: 3, cells: [SheetCell(column: 1, value: language.localized("対象期間の見積書はありません。"), style: 6)]))
        } else {
            for (offset, quote) in quotes.enumerated() {
                let itemText = quote.items.map { item in
                    let detail = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                    return detail.isEmpty ? item.name : "\(item.name) (\(detail))"
                }.joined(separator: " / ")
                let unitPrice = quote.items.count == 1 ? currencyString(quote.items[0].unitPrice, symbol: quote.currencySymbol) : "-"
                let quantity = quote.items.count == 1 ? compactNumber(quote.items[0].quantity) : "\(quote.items.count) \(language.localized("項目"))"
                let discountRate = quote.discountMode == .percent ? "\(compactPercent(quote.discountValue))%" : "0%"
                let taxRate = quote.taxLines.isEmpty ? "0%" : quote.taxLines.map { "\(compactPercent($0.rate))%" }.joined(separator: " + ")
                let rowIndex = offset + 3
                rows.append(SheetRow(index: rowIndex, cells: [
                    SheetCell(column: 1, value: quote.quoteNumber, style: 0),
                    SheetCell(column: 2, value: slashDate(quote.issueDate, language: language), style: 0),
                    SheetCell(column: 3, value: slashDate(quote.expiryDate, language: language), style: 0),
                    SheetCell(column: 4, value: quote.customer?.displayName ?? language.localized("未設定"), style: 0),
                    SheetCell(column: 5, value: itemText.isEmpty ? language.localized("項目未設定") : itemText, style: 0),
                    SheetCell(column: 6, value: unitPrice, style: 3),
                    SheetCell(column: 7, value: quantity, style: 4),
                    SheetCell(column: 8, value: currencyString(quote.subtotal, symbol: quote.currencySymbol), style: 3),
                    SheetCell(column: 9, value: currencyString(quote.discountAmount, symbol: quote.currencySymbol), style: 3),
                    SheetCell(column: 10, value: discountRate, style: 4),
                    SheetCell(column: 11, value: taxRate, style: 4),
                    SheetCell(column: 12, value: currencyString(quote.taxAmount, symbol: quote.currencySymbol), style: 3),
                    SheetCell(column: 13, value: currencyString(quote.grandTotal, symbol: quote.currencySymbol), style: 5)
                ]))
            }
        }

        let firstTotalRow = (rows.map(\.index).max() ?? 2) + 1
        if totalsByCurrency.isEmpty {
            rows.append(SheetRow(index: firstTotalRow, cells: [
                SheetCell(column: 12, value: language.localized("合計"), style: 7),
                SheetCell(column: 13, value: currencyString(0, symbol: "¥"), style: 8)
            ]))
        } else {
            for (offset, total) in totalsByCurrency.enumerated() {
                rows.append(SheetRow(index: firstTotalRow + offset, cells: [
                    SheetCell(column: 12, value: "\(total.key) \(language.localized("合計"))", style: 7),
                    SheetCell(column: 13, value: currencyString(total.value, symbol: total.key), style: 8)
                ]))
            }
        }

        let sheetName = language.localized(period.rawValue)
        let entries = [
            ZipEntry(path: "[Content_Types].xml", data: contentTypesXML().utf8Data),
            ZipEntry(path: "_rels/.rels", data: rootRelsXML().utf8Data),
            ZipEntry(path: "docProps/core.xml", data: coreXML().utf8Data),
            ZipEntry(path: "docProps/app.xml", data: appXML().utf8Data),
            ZipEntry(path: "xl/workbook.xml", data: workbookXML(sheetName: sheetName).utf8Data),
            ZipEntry(path: "xl/_rels/workbook.xml.rels", data: workbookRelsXML().utf8Data),
            ZipEntry(path: "xl/styles.xml", data: stylesXML().utf8Data),
            ZipEntry(path: "xl/worksheets/sheet1.xml", data: worksheetXML(rows: rows).utf8Data)
        ]
        return SimpleXLSXZip.archive(entries: entries)
    }

    private static func worksheetXML(rows: [SheetRow]) -> String {
        let rowXML = rows.map { row in
            let cells = row.cells.map { cell in
                let reference = "\(columnName(cell.column))\(row.index)"
                return """
                <c r="\(reference)" t="inlineStr" s="\(cell.style)"><is><t>\(escape(cell.value))</t></is></c>
                """
            }.joined()
            return "<row r=\"\(row.index)\">\(cells)</row>"
        }.joined()
        let maxRow = rows.map(\.index).max() ?? 1
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <dimension ref="A1:M\(maxRow)"/>
          <sheetViews><sheetView workbookViewId="0"/></sheetViews>
          <sheetFormatPr defaultRowHeight="20"/>
          <cols>
            <col min="1" max="1" width="17" customWidth="1"/>
            <col min="2" max="3" width="13" customWidth="1"/>
            <col min="4" max="4" width="24" customWidth="1"/>
            <col min="5" max="5" width="28" customWidth="1"/>
            <col min="6" max="6" width="14" customWidth="1"/>
            <col min="7" max="7" width="11" customWidth="1"/>
            <col min="8" max="9" width="15" customWidth="1"/>
            <col min="10" max="11" width="13" customWidth="1"/>
            <col min="12" max="13" width="15" customWidth="1"/>
          </cols>
          <sheetData>\(rowXML)</sheetData>
          <mergeCells count="1"><mergeCell ref="A1:M1"/></mergeCells>
        </worksheet>
        """
    }

    private static func workbookXML(sheetName: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets><sheet name="\(escape(sheetName))" sheetId="1" r:id="rId1"/></sheets>
        </workbook>
        """
    }

    private static func workbookRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """
    }

    private static func rootRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
        """
    }

    private static func contentTypesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
          <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
          <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
        </Types>
        """
    }

    private static func stylesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <fonts count="4">
            <font><sz val="11"/><name val="Aptos"/></font>
            <font><b/><sz val="16"/><color rgb="FF111827"/><name val="Aptos"/></font>
            <font><b/><sz val="11"/><color rgb="FF111827"/><name val="Aptos"/></font>
            <font><b/><sz val="12"/><color rgb="FF5145F6"/><name val="Aptos"/></font>
          </fonts>
          <fills count="5">
            <fill><patternFill patternType="none"/></fill>
            <fill><patternFill patternType="gray125"/></fill>
            <fill><patternFill patternType="solid"><fgColor rgb="FFEEF1FF"/><bgColor indexed="64"/></patternFill></fill>
            <fill><patternFill patternType="solid"><fgColor rgb="FFF8FAFC"/><bgColor indexed="64"/></patternFill></fill>
            <fill><patternFill patternType="solid"><fgColor rgb="FFDCE8FF"/><bgColor indexed="64"/></patternFill></fill>
          </fills>
          <borders count="2">
            <border><left/><right/><top/><bottom/><diagonal/></border>
            <border><left style="thin"><color rgb="FFD9DDE8"/></left><right style="thin"><color rgb="FFD9DDE8"/></right><top style="thin"><color rgb="FFD9DDE8"/></top><bottom style="thin"><color rgb="FFD9DDE8"/></bottom><diagonal/></border>
          </borders>
          <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
          <cellXfs count="9">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>
            <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
            <xf numFmtId="0" fontId="2" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
            <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"><alignment horizontal="right"/></xf>
            <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"><alignment horizontal="right"/></xf>
            <xf numFmtId="0" fontId="3" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1"><alignment horizontal="right"/></xf>
            <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>
            <xf numFmtId="0" fontId="2" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"><alignment horizontal="right"/></xf>
            <xf numFmtId="0" fontId="3" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"><alignment horizontal="right"/></xf>
          </cellXfs>
          <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
        </styleSheet>
        """
    }

    private static func coreXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <dc:creator>Quantaflow</dc:creator>
          <cp:lastModifiedBy>Quantaflow</cp:lastModifiedBy>
          <dcterms:created xsi:type="dcterms:W3CDTF">\(isoDate(Date()))</dcterms:created>
          <dcterms:modified xsi:type="dcterms:W3CDTF">\(isoDate(Date()))</dcterms:modified>
        </cp:coreProperties>
        """
    }

    private static func appXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
          <Application>Quantaflow</Application>
        </Properties>
        """
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func columnName(_ column: Int) -> String {
        var value = column
        var name = ""
        while value > 0 {
            let remainder = (value - 1) % 26
            name = String(UnicodeScalar(65 + remainder)!) + name
            value = (value - 1) / 26
        }
        return name
    }

    private static func isoDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func slashDate(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    private static func compactNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return NumberFormatter.pdfappDecimal.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func compactPercent(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return NumberFormatter.pdfappDecimal.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private enum SimpleXLSXZip {
    static func archive(entries: [ExcelReportRenderer.ZipEntry]) -> Data {
        var archive = Data()
        var centralDirectory = Data()

        for entry in entries {
            let nameData = entry.path.data(using: .utf8) ?? Data()
            let offset = UInt32(archive.count)
            let crc = CRC32.checksum(entry.data)
            let size = UInt32(entry.data.count)
            let nameLength = UInt16(nameData.count)

            archive.appendUInt32(0x04034B50)
            archive.appendUInt16(20)
            archive.appendUInt16(0x0800)
            archive.appendUInt16(0)
            archive.appendUInt16(0)
            archive.appendUInt16(0)
            archive.appendUInt32(crc)
            archive.appendUInt32(size)
            archive.appendUInt32(size)
            archive.appendUInt16(nameLength)
            archive.appendUInt16(0)
            archive.append(nameData)
            archive.append(entry.data)

            centralDirectory.appendUInt32(0x02014B50)
            centralDirectory.appendUInt16(20)
            centralDirectory.appendUInt16(20)
            centralDirectory.appendUInt16(0x0800)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt32(crc)
            centralDirectory.appendUInt32(size)
            centralDirectory.appendUInt32(size)
            centralDirectory.appendUInt16(nameLength)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt32(0)
            centralDirectory.appendUInt32(offset)
            centralDirectory.append(nameData)
        }

        let centralOffset = UInt32(archive.count)
        let centralSize = UInt32(centralDirectory.count)
        archive.append(centralDirectory)
        archive.appendUInt32(0x06054B50)
        archive.appendUInt16(0)
        archive.appendUInt16(0)
        archive.appendUInt16(UInt16(entries.count))
        archive.appendUInt16(UInt16(entries.count))
        archive.appendUInt32(centralSize)
        archive.appendUInt32(centralOffset)
        archive.appendUInt16(0)
        return archive
    }
}

private enum CRC32 {
    static let table: [UInt32] = (0..<256).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 {
            crc = (crc & 1) == 1 ? (0xEDB88320 ^ (crc >> 1)) : (crc >> 1)
        }
        return crc
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension String {
    var utf8Data: Data {
        data(using: .utf8) ?? Data()
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
