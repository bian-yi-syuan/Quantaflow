import PDFKit
import MessageUI
import SwiftUI
import UIKit

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DocumentExportSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        controller.shouldShowFileExtensions = true
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

struct MailComposeSheet: UIViewControllerRepresentable {
    @EnvironmentObject private var store: QuoteStore
    let quote: Quote
    let url: URL

    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator {
            dismiss()
        }
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        if let email = quote.customer?.email.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            controller.setToRecipients([email])
        }
        controller.setSubject("\(quote.quoteNumber) \(store.appLanguage.localized("見積書"))")
        controller.setMessageBody(store.appLanguage.localized("見積書を添付いたします。\nご確認ください。"), isHTML: false)
        if let data = try? Data(contentsOf: url) {
            controller.addAttachmentData(data, mimeType: "application/pdf", fileName: url.lastPathComponent)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) {
                self.onDismiss()
            }
        }
    }
}

struct PDFPreviewSheet: View {
    let url: URL

    var body: some View {
        NavigationStack {
            PDFKitView(url: url)
                .navigationTitle(url.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .systemGroupedBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
    }
}

enum PrintController {
    static func printPDF(url: URL) {
        let controller = UIPrintInteractionController.shared
        controller.printingItem = url
        controller.present(animated: true)
    }
}

enum QuotePDFRenderer {
    static func render(quote: Quote, company: CompanyProfile, language: AppLanguage, to url: URL) throws {
        try? FileManager.default.removeItem(at: url)

        let page = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: pdfFormat(for: quote))

        try renderer.writePDF(to: url) { context in
            let palette = PDFPalette(style: quote.pdfStyle, language: language)
            context.beginPage()
            drawPageBackground(page: page, palette: palette)
            drawWatermark(page: page, palette: palette)

            var y = drawHeader(quote: quote, company: company, page: page, palette: palette)
            drawCustomer(quote: quote, page: page, y: &y, palette: palette)
            drawItems(quote: quote, page: page, context: context, y: &y, palette: palette)

            if y > 600 {
                drawFooter(page: page, palette: palette)
                context.beginPage()
                drawPageBackground(page: page, palette: palette)
                drawWatermark(page: page, palette: palette)
                y = 76
            }

            drawTotals(quote: quote, page: page, y: &y, palette: palette)
            drawSignature(quote: quote, page: page, y: &y, palette: palette)
            drawNotes(quote: quote, page: page, y: &y, palette: palette)
            drawFooter(page: page, palette: palette)
        }
    }

    private static func pdfFormat(for quote: Quote) -> UIGraphicsPDFRendererFormat {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: quote.quoteNumber,
            kCGPDFContextCreator as String: AppTheme.brandName,
            kCGPDFContextAuthor as String: AppTheme.brandName
        ]
        return format
    }

    private static func drawPageBackground(page: CGRect, palette: PDFPalette) {
        fill(page, color: palette.background)
        if palette.style == .simple {
            fill(CGRect(x: 0, y: 0, width: page.width, height: 6), color: palette.accent)
        } else if palette.style == .soft {
            fillRounded(CGRect(x: 36, y: 36, width: page.width - 72, height: page.height - 72), radius: 18, color: .white.withAlphaComponent(0.86))
            fillRounded(CGRect(x: page.width - 160, y: 48, width: 96, height: 96), radius: 48, color: palette.accent.withAlphaComponent(0.08))
        } else {
            fill(CGRect(x: 0, y: 70, width: page.width, height: 1), color: palette.border)
        }
    }

    private static func drawHeader(quote: Quote, company: CompanyProfile, page: CGRect, palette: PDFPalette) -> CGFloat {
        switch palette.style {
        case .simple:
            fillRounded(CGRect(x: 42, y: 44, width: page.width - 84, height: 94), radius: 14, color: palette.headerBackground)
        case .soft:
            fillRounded(CGRect(x: 42, y: 44, width: page.width - 84, height: 104), radius: 24, color: palette.headerBackground)
        case .compact:
            fill(CGRect(x: 0, y: 0, width: page.width, height: 70), color: palette.headerBackground)
        }

        let logoRect = CGRect(x: 58, y: 62, width: 56, height: 56)
        drawLogo(data: quote.logoData ?? company.logoData, fallback: AppTheme.brandName, in: logoRect, palette: palette)

        draw(
            palette.label("見積書"),
            in: CGRect(x: 128, y: palette.style == .compact ? 24 : 60, width: 190, height: 34),
            font: .systemFont(ofSize: palette.style == .compact ? 22 : 30, weight: .bold),
            color: palette.titleText
        )
        draw(
            palette.label(quote.pdfStyle.rawValue),
            in: CGRect(x: 130, y: palette.style == .compact ? 48 : 98, width: 160, height: 18),
            font: .systemFont(ofSize: 9, weight: .semibold),
            color: palette.muted
        )

        let metaLabelX: CGFloat = page.width - 244
        let metaValueX: CGFloat = metaLabelX + 64
        let metaValueWidth: CGFloat = page.width - 58 - metaValueX
        draw(palette.label("見積番号"), in: CGRect(x: metaLabelX, y: 62, width: 58, height: 16), font: .systemFont(ofSize: 9, weight: .semibold), color: palette.muted)
        drawFitted(quote.quoteNumber, in: CGRect(x: metaValueX, y: 59, width: metaValueWidth, height: 20), maxSize: 11.5, minSize: 7.5, weight: .bold, color: palette.titleText, alignment: .right)
        draw(palette.label("発行日"), in: CGRect(x: metaLabelX, y: 84, width: 58, height: 16), font: .systemFont(ofSize: 9, weight: .semibold), color: palette.muted)
        drawFitted(slashDate(quote.issueDate, language: palette.language), in: CGRect(x: metaValueX, y: 82, width: metaValueWidth, height: 20), maxSize: 10.5, minSize: 7.5, weight: .semibold, color: palette.text, alignment: .right)
        draw(palette.label("有効期限"), in: CGRect(x: metaLabelX, y: 106, width: 58, height: 16), font: .systemFont(ofSize: 9, weight: .semibold), color: palette.muted)
        drawFitted(slashDate(quote.expiryDate, language: palette.language), in: CGRect(x: metaValueX, y: 104, width: metaValueWidth, height: 20), maxSize: 10.5, minSize: 7.5, weight: .semibold, color: palette.text, alignment: .right)

        if quote.showCompanyInfo {
            let y: CGFloat = palette.style == .compact ? 84 : 158
            drawFitted(company.name.isEmpty ? AppTheme.brandName : company.name, in: CGRect(x: 50, y: y, width: 230, height: 18), maxSize: 11, minSize: 8, weight: .bold, color: palette.text)
            drawFitted([company.ownerName, company.email, company.phone].filter { !$0.isEmpty }.joined(separator: " / "), in: CGRect(x: 50, y: y + 18, width: 360, height: 16), maxSize: 8.5, minSize: 6.5, color: palette.muted)
            draw(company.address, in: CGRect(x: 50, y: y + 34, width: 360, height: 16), font: .systemFont(ofSize: 8.5), color: palette.muted)
            return y + 68
        }

        return palette.style == .compact ? 96 : 164
    }

    private static func drawCustomer(quote: Quote, page: CGRect, y: inout CGFloat, palette: PDFPalette) {
        let height: CGFloat = palette.style == .compact ? 58 : 76
        fillRounded(CGRect(x: 50, y: y, width: page.width - 100, height: height), radius: 12, color: palette.cardBackground)
        draw(palette.label("宛先"), in: CGRect(x: 68, y: y + 14, width: 120, height: 16), font: .systemFont(ofSize: 9, weight: .semibold), color: palette.muted)
        drawFitted(quote.customer?.displayName ?? palette.label("未設定"), in: CGRect(x: 68, y: y + 32, width: 250, height: 24), maxSize: 16, minSize: 10, weight: .bold, color: palette.text)
        if let customer = quote.customer {
            drawFitted([customer.name, customer.email, customer.phone].filter { !$0.isEmpty }.joined(separator: " / "), in: CGRect(x: 326, y: y + 22, width: 198, height: 16), maxSize: 8.5, minSize: 6, color: palette.muted, alignment: .right)
            drawFitted(customer.address, in: CGRect(x: 326, y: y + 40, width: 198, height: 16), maxSize: 8.5, minSize: 6, color: palette.muted, alignment: .right)
        }
        y += height + 26
    }

    private static func drawItems(quote: Quote, page: CGRect, context: UIGraphicsPDFRendererContext, y: inout CGFloat, palette: PDFPalette) {
        drawTableHeader(page: page, y: y, palette: palette)
        y += palette.rowHeight

        for (index, item) in quote.items.enumerated() {
            if y + palette.rowHeight > 620 {
                drawFooter(page: page, palette: palette)
                context.beginPage()
                drawPageBackground(page: page, palette: palette)
                drawWatermark(page: page, palette: palette)
                y = 76
                drawTableHeader(page: page, y: y, palette: palette)
                y += palette.rowHeight
            }

            let rowY = y
            let rowRect = CGRect(x: 50, y: rowY, width: page.width - 100, height: palette.rowHeight)
            fillRounded(rowRect, radius: palette.style == .compact ? 2 : 8, color: index.isMultiple(of: 2) ? palette.rowAlt : palette.rowBackground)
            draw("\(index + 1)", in: CGRect(x: 60, y: rowY + 8, width: 24, height: 16), font: .systemFont(ofSize: 9, weight: .semibold), color: palette.muted)
            drawFitted(item.name, in: CGRect(x: 88, y: rowY + 7, width: 186, height: 17), maxSize: palette.style == .compact ? 9.5 : 10.5, minSize: 7.5, weight: .bold, color: palette.text)
            if palette.style != .compact, !item.detail.isEmpty {
                draw(item.detail, in: CGRect(x: 88, y: rowY + 25, width: 220, height: 14), font: .systemFont(ofSize: 8), color: palette.muted)
            }
            drawFitted(currencyString(item.unitPrice, symbol: quote.currencySymbol), in: CGRect(x: 292, y: rowY + 8, width: 84, height: 16), maxSize: 9.5, minSize: 6.5, color: palette.text, alignment: .right)
            drawFitted("\(compactNumber(item.quantity)) \(palette.label(item.unit))", in: CGRect(x: 386, y: rowY + 8, width: 58, height: 16), maxSize: 9.5, minSize: 6.5, color: palette.text, alignment: .center)
            drawFitted(currencyString(item.subtotal, symbol: quote.currencySymbol), in: CGRect(x: 444, y: rowY + 8, width: 100, height: 16), maxSize: 10, minSize: 6.8, weight: .bold, color: palette.accent, alignment: .right)
            y += palette.rowHeight + 4
        }
        y += 22
    }

    private static func drawTableHeader(page: CGRect, y: CGFloat, palette: PDFPalette) {
        fillRounded(CGRect(x: 50, y: y, width: page.width - 100, height: palette.rowHeight), radius: palette.style == .compact ? 2 : 8, color: palette.tableHeader)
        draw("#", in: CGRect(x: 60, y: y + 8, width: 24, height: 14), font: .systemFont(ofSize: 9, weight: .bold), color: palette.text)
        draw(palette.label("項目"), in: CGRect(x: 88, y: y + 8, width: 190, height: 14), font: .systemFont(ofSize: 9, weight: .bold), color: palette.text)
        draw(palette.label("単価"), in: CGRect(x: 292, y: y + 8, width: 84, height: 14), font: .systemFont(ofSize: 9, weight: .bold), color: palette.text, alignment: .right)
        draw(palette.label("数量"), in: CGRect(x: 386, y: y + 8, width: 58, height: 14), font: .systemFont(ofSize: 9, weight: .bold), color: palette.text, alignment: .center)
        draw(palette.label("金額"), in: CGRect(x: 444, y: y + 8, width: 100, height: 14), font: .systemFont(ofSize: 9, weight: .bold), color: palette.text, alignment: .right)
    }

    private static func drawTotals(quote: Quote, page: CGRect, y: inout CGFloat, palette: PDFPalette) {
        let boxWidth: CGFloat = 276
        let startX = page.width - boxWidth - 50
        let rowHeight: CGFloat = 22
        let taxRows = max(1, quote.taxLines.count)
        let boxHeight = CGFloat(4 + taxRows) * rowHeight + 34

        fillRounded(CGRect(x: startX - 16, y: y - 12, width: boxWidth + 16, height: boxHeight), radius: 14, color: palette.totalBackground)
        drawTotalLine(palette.label("小計"), currencyString(quote.subtotal, symbol: quote.currencySymbol), x: startX, y: y, width: boxWidth, palette: palette)
        y += rowHeight
        drawTotalLine(
            discountTitle(for: quote, palette: palette),
            quote.discountAmount > 0 ? "-\(currencyString(quote.discountAmount, symbol: quote.currencySymbol))" : currencyString(0, symbol: quote.currencySymbol),
            x: startX,
            y: y,
            width: boxWidth,
            palette: palette,
            valueColor: UIColor(hex: 0xEF4444)
        )
        y += rowHeight

        if quote.taxLines.isEmpty {
            drawTotalLine("\(palette.label("税額")) (0%)", currencyString(0, symbol: quote.currencySymbol), x: startX, y: y, width: boxWidth, palette: palette)
            y += rowHeight
        } else {
            for tax in quote.taxLines {
                let rawName = tax.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = rawName.isEmpty || rawName == "消費税" ? palette.label("税額") : rawName
                drawTotalLine("\(name) (\(compactPercent(tax.rate))%)", currencyString(quote.amount(for: tax), symbol: quote.currencySymbol), x: startX, y: y, width: boxWidth, palette: palette)
                y += rowHeight
            }
        }

        line(x: startX, y: y + 4, width: boxWidth - 2, color: palette.border)
        y += 14
        draw(palette.label("合計"), in: CGRect(x: startX, y: y, width: 76, height: 26), font: .systemFont(ofSize: 15, weight: .bold), color: palette.text)
        drawFitted(currencyString(quote.grandTotal, symbol: quote.currencySymbol), in: CGRect(x: startX + 76, y: y - 4, width: boxWidth - 78, height: 32), maxSize: 19, minSize: 10, weight: .bold, color: palette.accent, alignment: .right)
        y += 48
    }

    private static func drawTotalLine(_ title: String, _ value: String, x: CGFloat, y: CGFloat, width: CGFloat, palette: PDFPalette, valueColor: UIColor? = nil) {
        drawFitted(title, in: CGRect(x: x, y: y, width: 126, height: 18), maxSize: 10, minSize: 7, weight: .semibold, color: palette.muted)
        drawFitted(value, in: CGRect(x: x + 126, y: y, width: width - 126, height: 18), maxSize: 10.5, minSize: 7, weight: .semibold, color: valueColor ?? palette.text, alignment: .right)
    }

    private static func discountTitle(for quote: Quote, palette: PDFPalette) -> String {
        switch quote.discountMode {
        case .amount:
            return "\(palette.label("割引")) (\(palette.label("金額")))"
        case .percent:
            return "\(palette.label("割引")) (\(compactPercent(quote.discountValue))%)"
        }
    }

    private static func drawSignature(quote: Quote, page: CGRect, y: inout CGFloat, palette: PDFPalette) {
        let rect = CGRect(x: 50, y: y, width: page.width - 100, height: 86)
        fillRounded(rect, radius: 14, color: palette.cardBackground)
        draw(palette.label("顧客署名"), in: CGRect(x: rect.minX + 18, y: rect.minY + 14, width: 120, height: 18), font: .systemFont(ofSize: 10, weight: .bold), color: palette.muted)
        line(x: rect.minX + 18, y: rect.maxY - 24, width: rect.width - 36, color: palette.border)

        if quote.signatureMode == .drawn, let data = quote.drawnSignatureData, let image = UIImage(data: data) {
            image.draw(in: aspectFitRect(image: image, in: CGRect(x: rect.minX + 170, y: rect.minY + 16, width: 260, height: 48)))
        } else if !quote.typedSignature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draw(quote.typedSignature, in: CGRect(x: rect.minX + 170, y: rect.minY + 24, width: 260, height: 34), font: .italicSystemFont(ofSize: 24), color: palette.text, alignment: .center)
        } else {
            draw(palette.label("署名欄"), in: CGRect(x: rect.minX + 170, y: rect.minY + 28, width: 260, height: 22), font: .systemFont(ofSize: 10, weight: .semibold), color: palette.muted, alignment: .center)
        }
        y += 112
    }

    private static func drawNotes(quote: Quote, page: CGRect, y: inout CGFloat, palette: PDFPalette) {
        let noteText = quote.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !noteText.isEmpty else { return }
        fillRounded(CGRect(x: 50, y: y, width: page.width - 100, height: 68), radius: 12, color: palette.cardBackground)
        draw(palette.label("備考"), in: CGRect(x: 68, y: y + 12, width: 120, height: 18), font: .systemFont(ofSize: 10, weight: .bold), color: palette.muted)
        draw(noteText, in: CGRect(x: 68, y: y + 32, width: page.width - 136, height: 26), font: .systemFont(ofSize: 9.5), color: palette.text, lineBreak: .byWordWrapping)
        y += 86
    }

    private static func drawWatermark(page: CGRect, palette: PDFPalette) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        cg.saveGState()
        cg.translateBy(x: page.midX, y: page.midY + 72)
        cg.rotate(by: -CGFloat.pi / 4)
        draw(
            AppTheme.brandName,
            in: CGRect(x: -250, y: -34, width: 500, height: 68),
            font: .systemFont(ofSize: 50, weight: .heavy),
            color: palette.accent.withAlphaComponent(0.055),
            alignment: .center
        )
        cg.restoreGState()
    }

    private static func drawFooter(page: CGRect, palette: PDFPalette) {
        line(x: 50, y: page.height - 52, width: page.width - 100, color: palette.border)
        draw("Powered by \(AppTheme.brandName)", in: CGRect(x: 50, y: page.height - 40, width: page.width - 100, height: 18), font: .systemFont(ofSize: 8), color: palette.muted, alignment: .center)
        draw(slashDateTime(Date(), language: palette.language), in: CGRect(x: page.width - 190, y: page.height - 40, width: 140, height: 18), font: .systemFont(ofSize: 8), color: palette.muted, alignment: .right)
    }

    private static func drawLogo(data: Data?, fallback: String, in rect: CGRect, palette: PDFPalette) {
        fillRounded(rect, radius: 12, color: .white.withAlphaComponent(0.78))
        if let data, let image = UIImage(data: data) {
            image.draw(in: aspectFitRect(image: image, in: rect.insetBy(dx: 8, dy: 8)))
        } else {
            let letter = fallback.first.map(String.init) ?? "Q"
            draw(letter, in: rect.insetBy(dx: 4, dy: 8), font: .systemFont(ofSize: 24, weight: .heavy), color: palette.accent, alignment: .center)
        }
    }

    private static func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment = .left, lineBreak: NSLineBreakMode = .byTruncatingTail) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = lineBreak
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])
    }

    private static func drawFitted(_ text: String, in rect: CGRect, maxSize: CGFloat, minSize: CGFloat = 7, weight: UIFont.Weight = .regular, color: UIColor, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        var size = maxSize
        while size > minSize {
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            let bounds = (text as NSString).boundingRect(
                with: CGSize(width: rect.width, height: rect.height),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .paragraphStyle: paragraph],
                context: nil
            )
            if bounds.width <= rect.width && bounds.height <= rect.height {
                draw(text, in: rect, font: font, color: color, alignment: alignment)
                return
            }
            size -= 0.5
        }
        draw(text, in: rect, font: .systemFont(ofSize: minSize, weight: weight), color: color, alignment: alignment)
    }

    private static func line(x: CGFloat, y: CGFloat, width: CGFloat, color: UIColor) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        cg.saveGState()
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(0.75)
        cg.move(to: CGPoint(x: x, y: y))
        cg.addLine(to: CGPoint(x: x + width, y: y))
        cg.strokePath()
        cg.restoreGState()
    }

    private static func fill(_ rect: CGRect, color: UIColor) {
        guard let cg = UIGraphicsGetCurrentContext() else { return }
        cg.saveGState()
        cg.setFillColor(color.cgColor)
        cg.fill(rect)
        cg.restoreGState()
    }

    private static func fillRounded(_ rect: CGRect, radius: CGFloat, color: UIColor) {
        color.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: radius).fill()
    }

    private static func slashDate(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    private static func slashDateTime(_ date: Date, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
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

    private static func aspectFitRect(image: UIImage, in rect: CGRect) -> CGRect {
        let scale = min(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
    }
}

private struct PDFPalette {
    let style: PDFStyle
    let language: AppLanguage
    let accent: UIColor
    let background: UIColor
    let headerBackground: UIColor
    let tableHeader: UIColor
    let rowBackground: UIColor
    let rowAlt: UIColor
    let cardBackground: UIColor
    let totalBackground: UIColor
    let text: UIColor
    let titleText: UIColor
    let muted: UIColor
    let border: UIColor
    let rowHeight: CGFloat

    init(style: PDFStyle, language: AppLanguage) {
        self.style = style
        self.language = language
        switch style {
        case .simple:
            accent = UIColor(hex: 0x5145F6)
            background = .white
            headerBackground = UIColor(hex: 0xF3F5FF)
            tableHeader = UIColor(hex: 0xEEF1FF)
            rowBackground = .white
            rowAlt = UIColor(hex: 0xF8FAFC)
            cardBackground = UIColor(hex: 0xF8FAFC)
            totalBackground = UIColor(hex: 0xF3F5FF)
            text = UIColor(hex: 0x111827)
            titleText = UIColor(hex: 0x111827)
            muted = UIColor(hex: 0x6B7280)
            border = UIColor(hex: 0xD9DDE8)
            rowHeight = 38
        case .soft:
            accent = UIColor(hex: 0x6C5CE7)
            background = UIColor(hex: 0xF7F4FF)
            headerBackground = UIColor(hex: 0xE8E4FF)
            tableHeader = UIColor(hex: 0xDFF8EE)
            rowBackground = UIColor(hex: 0xFFFFFF)
            rowAlt = UIColor(hex: 0xFBFAFF)
            cardBackground = UIColor(hex: 0xFFFFFF).withAlphaComponent(0.86)
            totalBackground = UIColor(hex: 0xF0ECFF)
            text = UIColor(hex: 0x202033)
            titleText = UIColor(hex: 0x202033)
            muted = UIColor(hex: 0x78758C)
            border = UIColor(hex: 0xD8D2FA)
            rowHeight = 42
        case .compact:
            accent = UIColor(hex: 0x2563EB)
            background = .white
            headerBackground = UIColor(hex: 0xE7F5F0)
            tableHeader = UIColor(hex: 0xEEF2F7)
            rowBackground = .white
            rowAlt = UIColor(hex: 0xF7F9FB)
            cardBackground = UIColor(hex: 0xFBFCFD)
            totalBackground = UIColor(hex: 0xF7F9FB)
            text = UIColor(hex: 0x111827)
            titleText = UIColor(hex: 0x111827)
            muted = UIColor(hex: 0x64748B)
            border = UIColor(hex: 0xD4DAE3)
            rowHeight = 24
        }
    }

    func label(_ key: String) -> String {
        language.localized(key)
    }
}

private extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
