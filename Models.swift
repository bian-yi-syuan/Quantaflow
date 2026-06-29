import Foundation
import SwiftUI

enum QuoteStatus: String, Codable, CaseIterable, Identifiable {
    case draft = "下書き"
    case processing = "処理中"
    case sent = "送信済み"
    case accepted = "承認済み"
    case rejected = "却下"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .draft: "doc.text"
        case .processing: "hourglass"
        case .sent: "paperplane.fill"
        case .accepted: "checkmark.seal.fill"
        case .rejected: "xmark.seal.fill"
        }
    }

    var color: Color {
        switch self {
        case .draft: AppTheme.inkSecondary
        case .processing: AppTheme.orange
        case .sent: AppTheme.blue
        case .accepted: AppTheme.green
        case .rejected: AppTheme.red
        }
    }
}

enum TaxMode: String, Codable, CaseIterable, Identifiable {
    case untaxed = "未税"
    case taxIncluded = "含税"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .untaxed: "入力金額に税金を追加"
        case .taxIncluded: "入力金額に税金を含む"
        }
    }
}

enum DiscountMode: String, Codable, CaseIterable, Identifiable {
    case amount = "金額"
    case percent = "％"

    var id: String { rawValue }
}

enum PDFStyle: String, Codable, CaseIterable, Identifiable {
    case simple = "シンプル"
    case soft = "ソフト"
    case compact = "コンパクト"

    var id: String { rawValue }
}

enum SignatureMode: String, Codable, CaseIterable, Identifiable {
    case typed = "入力"
    case drawn = "手書き"

    var id: String { rawValue }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case japanese = "日本語"
    case english = "English"
    case chinese = "繁體中文"

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .japanese: "ja_JP"
        case .english: "en_US"
        case .chinese: "zh_Hant"
        }
    }

    var lprojName: String? {
        switch self {
        case .japanese: nil
        case .english: "en"
        case .chinese: "zh-Hant"
        }
    }

    func localized(_ key: String) -> String {
        guard
            let lprojName,
            let path = Bundle.main.path(forResource: lprojName, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return key
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}

enum CurrencyOption: String, Codable, CaseIterable, Identifiable {
    case jpy = "JPY"
    case usd = "USD"
    case twd = "TWD"
    case cny = "CNY"
    case eur = "EUR"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .jpy: "¥"
        case .usd: "$"
        case .twd: "NT$"
        case .cny: "¥"
        case .eur: "€"
        }
    }

    var displayName: String {
        switch self {
        case .jpy: "日本円（JPY）"
        case .usd: "米ドル（USD）"
        case .twd: "台湾ドル（TWD）"
        case .cny: "人民元（CNY）"
        case .eur: "ユーロ（EUR）"
        }
    }
}

enum SalesReportPeriod: String, Codable, CaseIterable, Identifiable {
    case month = "今月"
    case year = "今年"

    var id: String { rawValue }
}

struct TaxLine: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var rate: Double

    static var blank: TaxLine {
        TaxLine(name: "消費税", rate: 0)
    }
}

struct Customer: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var company: String
    var registrationNumber: String
    var phone: String
    var email: String
    var address: String
    var lastUpdated = Date()

    var displayName: String {
        if !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            company
        } else if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name
        } else {
            "名称未設定"
        }
    }

    var subtitle: String {
        [name, phone, email].filter { !$0.isEmpty }.joined(separator: " ・ ")
    }

    var initials: String {
        let source = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let letters = source.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
        if !letters.isEmpty { return letters.uppercased() }
        return source.first.map { String($0) } ?? "顧"
    }

    static var empty: Customer {
        Customer(name: "", company: "", registrationNumber: "", phone: "", email: "", address: "")
    }
}

struct QuoteItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var detail: String
    var unitPrice: Double
    var quantity: Double
    var unit: String

    var subtotal: Double {
        max(unitPrice, 0) * max(quantity, 0)
    }

    static var blank: QuoteItem {
        QuoteItem(name: "", detail: "", unitPrice: 0, quantity: 1, unit: "個")
    }
}

struct CompanyProfile: Codable, Hashable {
    var name: String
    var ownerName: String
    var phone: String
    var email: String
    var address: String
    var registrationNumber: String
    var website: String = ""
    var logoData: Data?

    static let `default` = CompanyProfile(
        name: "Quantaflow",
        ownerName: "",
        phone: "",
        email: "contact@quantaflow.example",
        address: "",
        registrationNumber: "",
        website: "",
        logoData: nil
    )
}

struct Quote: Identifiable, Codable, Hashable {
    static let maxItems = 20

    var id = UUID()
    var quoteNumber: String
    var issueDate = Date()
    var expiryDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    var customer: Customer?
    var items: [QuoteItem] = []
    var status: QuoteStatus = .draft
    var discountMode: DiscountMode = .amount
    var discountValue: Double = 0
    var taxMode: TaxMode = .untaxed
    var taxLines: [TaxLine] = []
    var note: String = ""
    var showCompanyInfo = true
    var pdfStyle: PDFStyle = .simple
    var currencySymbol = "¥"
    var pdfFileName: String?
    var signatureMode: SignatureMode = .typed
    var typedSignature: String = ""
    var drawnSignatureData: Data?
    var logoData: Data?

    var sequenceNumber: Int {
        quoteNumber.split(separator: "-").last.flatMap { Int($0) } ?? 0
    }

    var subtotal: Double {
        items.reduce(0) { $0 + $1.subtotal }
    }

    var discountAmount: Double {
        switch discountMode {
        case .amount:
            min(max(discountValue, 0), subtotal)
        case .percent:
            subtotal * min(max(discountValue, 0), 100) / 100
        }
    }

    var taxableBase: Double {
        max(subtotal - discountAmount, 0)
    }

    var totalTaxRate: Double {
        taxLines.reduce(0) { $0 + max($1.rate, 0) }
    }

    func amount(for taxLine: TaxLine) -> Double {
        let safeRate = max(taxLine.rate, 0) / 100
        switch taxMode {
        case .untaxed:
            return taxableBase * safeRate
        case .taxIncluded:
            let totalRate = max(totalTaxRate, 0) / 100
            guard totalRate > 0 else { return 0 }
            return taxableBase * safeRate / (1 + totalRate)
        }
    }

    var taxAmount: Double {
        taxLines.reduce(0) { $0 + amount(for: $1) }
    }

    var grandTotal: Double {
        switch taxMode {
        case .taxIncluded:
            return taxableBase
        case .untaxed:
            return taxableBase + taxAmount
        }
    }

    var isReadyForPDF: Bool {
        customer != nil && !items.isEmpty && items.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.quantity > 0 && $0.unitPrice >= 0 }
    }

    static func draft(number: String) -> Quote {
        Quote(quoteNumber: number)
    }
}

func currencyString(_ value: Double, symbol: String = "¥") -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.numberStyle = .currency
    formatter.currencySymbol = symbol
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    return formatter.string(from: NSNumber(value: value)) ?? "\(symbol)\(value)"
}

func dateString(_ date: Date, style: DateFormatter.Style = .medium) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.dateStyle = style
    formatter.timeStyle = .none
    return formatter.string(from: date)
}

extension NumberFormatter {
    static var pdfappDecimal: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }
}
