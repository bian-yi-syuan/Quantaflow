import PhotosUI
import SwiftUI
import UIKit

struct QuoteFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: QuoteStore
    @State private var quote: Quote
    @State private var step: Int
    @State private var showingCustomerEditor = false
    @State private var generatedURL: URL?
    @State private var previewItem: ShareItem?
    @State private var shareItem: ShareItem?
    @State private var errorMessage: String?
    @State private var showingEditConfirm = false
    private let isEditing: Bool

    init(initialQuote: Quote, isEditing: Bool = false) {
        _quote = State(initialValue: initialQuote)
        _step = State(initialValue: isEditing ? 2 : 1)
        self.isEditing = isEditing
    }

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(spacing: 0) {
                    FlowHeader(
                        step: step,
                        title: stepTitle,
                        subtitle: stepSubtitle,
                        isEditing: isEditing,
                        onCancel: { dismiss() }
                    )

                    ScrollView(showsIndicators: false) {
                        stepContent
                            .padding(.horizontal, 18)
                            .padding(.top, 20)
                            .padding(.bottom, 24)
                    }

                    FlowFooter(
                        step: step,
                        nextDisabled: nextDisabled,
                        isEditing: isEditing,
                        onBack: goBack,
                        onNext: goNext
                    )
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCustomerEditor) {
            CustomerEditorView(customer: .empty) { customer in
                let savedCustomer = store.addCustomer(customer)
                quote.customer = savedCustomer
            }
        }
        .sheet(item: $previewItem) { item in
            PDFPreviewSheet(url: item.url)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        .alert("PDF生成エラー", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("確定", isPresented: $showingEditConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("確定") {
                store.saveQuote(quote)
                dismiss()
            }
        } message: {
            Text("この内容で見積書を更新します。ホームの今月・今年の集計も再計算されます。")
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 1:
            if isEditing {
                LockedRecipientStepView(quote: quote)
            } else {
                RecipientStepView(quote: $quote, customers: store.customers, onAddCustomer: { showingCustomerEditor = true })
            }
        case 2:
            ItemsStepView(quote: $quote)
        case 3:
            PriceStepView(quote: $quote)
        case 4:
            PreviewStepView(quote: $quote, onPreviewPDF: previewPDF)
        default:
            ExportStepView(
                quote: quote,
                generatedURL: generatedURL,
                onShare: { url in shareItem = ShareItem(url: url) },
                onSave: { _ in },
                onPrint: { url in PrintController.printPDF(url: url) }
            )
        }
    }

    private var stepTitle: String {
        switch step {
        case 1: "宛先"
        case 2: "項目"
        case 3: "価格"
        case 4: "プレビュー"
        default: "書き出し"
        }
    }

    private var stepSubtitle: String {
        switch step {
        case 1: "顧客を選択または追加"
        case 2: "見積項目を入力"
        case 3: "割引、税金、有効期限"
        case 4: "内容、署名、PDF設定を確認"
        default: "共有、保存、メール、印刷"
        }
    }

    private var nextDisabled: Bool {
        switch step {
        case 1:
            quote.customer == nil
        case 2:
            quote.items.isEmpty ||
            quote.items.count > Quote.maxItems ||
            !quote.items.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.quantity > 0 && $0.unitPrice >= 0 }
        case 4:
            !quote.isReadyForPDF
        default:
            false
        }
    }

    private func goBack() {
        if step == 1 {
            dismiss()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                step -= 1
            }
        }
    }

    private func goNext() {
        guard !nextDisabled else { return }

        if step == 4 {
            createPDFAndMoveToExport()
        } else if step == 5 {
            if isEditing {
                showingEditConfirm = true
            } else {
                dismiss()
            }
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                step += 1
            }
        }
    }

    private func previewPDF() {
        do {
            if quote.status == .draft {
                quote.status = .processing
            }
            generatedURL = try store.exportPDF(for: quote)
            if let generatedURL {
                previewItem = ShareItem(url: generatedURL)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createPDFAndMoveToExport() {
        do {
            if quote.status == .draft {
                quote.status = .processing
            }
            generatedURL = try store.exportPDF(for: quote)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                step = 5
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct FlowHeader: View {
    let step: Int
    let title: String
    let subtitle: String
    let isEditing: Bool
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("キャンセル", action: onCancel)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.74), in: Capsule())

                Spacer()

                Text(LocalizedStringKey(isEditing ? "見積書を編集" : "新規見積書"))
                    .font(.title2.weight(.heavy))

                Spacer()

                Text(" ")
                    .font(.headline)
                    .padding(.horizontal, 42)
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? AppTheme.primary : AppTheme.lavender)
                        .frame(height: 6)
                }
            }

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(title))
                        .font(.largeTitle.weight(.heavy))
                    Text(LocalizedStringKey(subtitle))
                        .font(.headline)
                        .foregroundStyle(AppTheme.inkSecondary)
                }
                Spacer()
                (Text("ステップ") + Text(" \(step) / 5"))
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(AppTheme.lavender, in: Capsule())
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .background(.ultraThinMaterial)
    }
}

struct FlowFooter: View {
    let step: Int
    let nextDisabled: Bool
    let isEditing: Bool
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SecondaryButton(title: step == 1 ? "閉じる" : "戻る", action: onBack)

            PrimaryButton(
                title: nextTitle,
                systemImage: step == 5 ? "checkmark" : "arrow.right",
                disabled: nextDisabled,
                action: onNext
            )
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(.ultraThinMaterial)
    }

    private var nextTitle: String {
        switch step {
        case 4: "確認"
        case 5: isEditing ? "確定" : "完了"
        default: "次へ"
        }
    }
}

struct RecipientStepView: View {
    @Binding var quote: Quote
    let customers: [Customer]
    let onAddCustomer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let customer = quote.customer {
                VStack(alignment: .leading, spacing: 12) {
                    Text("選択中の顧客")
                        .font(.headline)
                        .foregroundStyle(AppTheme.inkSecondary)
                    SelectedCustomerCard(customer: customer)
                }
            } else {
                EmptyStateView(
                    icon: "person.crop.circle",
                    title: "顧客が未選択です",
                    message: "登録済み顧客を選択するか、新しい顧客を追加してください。"
                )
            }

            HStack(spacing: 12) {
                Button(action: onAddCustomer) {
                    Label("新規顧客", systemImage: "plus")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(AppTheme.primary)
                        .background(AppTheme.lavender, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    quote.customer = customers.first
                } label: {
                    Label("顧客から選択", systemImage: "person.crop.circle")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(AppTheme.primary, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(customers.isEmpty)
            }

            if !customers.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(title: "顧客一覧")
                    ForEach(customers) { customer in
                        Button {
                            quote.customer = customer
                        } label: {
                            SelectedCustomerCard(customer: customer, selected: quote.customer?.id == customer.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct LockedRecipientStepView: View {
    let quote: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionLabel(title: "この見積書の宛先")
            if let customer = quote.customer {
                SelectedCustomerCard(customer: customer)
            } else {
                EmptyStateView(
                    icon: "person.crop.circle",
                    title: "顧客が未設定です",
                    message: "この見積書には顧客情報がありません。必要な場合は新規見積書として作成し直してください。"
                )
            }

            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.lavender, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("編集中の見積書に固定されています")
                        .font(.headline.weight(.bold))
                    Text("項目、価格、署名、PDF設定をこのまま編集できます。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.inkSecondary)
                }
            }
            .glassPanel()
        }
    }
}

struct SelectedCustomerCard: View {
    let customer: Customer
    var selected = true

    var body: some View {
        HStack(spacing: 14) {
            Text(customer.initials)
                .font(.headline.weight(.heavy))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 58, height: 58)
                .background(AppTheme.lavender, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(customer.displayName)
                    .font(.title3.weight(.bold))
                if customer.subtitle.isEmpty {
                    Text("連絡先未設定")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.inkSecondary)
                } else {
                    Text(customer.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.inkSecondary)
                }
            }

            Spacer()

            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title2.weight(.bold))
                .foregroundStyle(selected ? AppTheme.primary : AppTheme.inkSecondary)
        }
        .glassPanel()
    }
}

struct ItemsStepView: View {
    @Binding var quote: Quote

    private var canAddItem: Bool {
        quote.items.count < Quote.maxItems
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if quote.items.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.rectangle",
                    title: "項目がありません",
                    message: "下のボタンから最初の見積項目を追加してください。",
                    buttonTitle: "項目を追加",
                    action: addItem
                )
            }

            ForEach($quote.items) { $item in
                let itemID = item.id
                QuoteItemEditorCard(item: $item, currencySymbol: quote.currencySymbol) {
                    quote.items.removeAll { $0.id == itemID }
                }
            }

            Button(action: addItem) {
                Label {
                    Text(LocalizedStringKey(canAddItem ? "項目を追加" : "項目は20件まで"))
                } icon: {
                    Image(systemName: canAddItem ? "plus" : "checkmark.circle")
                }
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 22)
                    .background(canAddItem ? AppTheme.primary : AppTheme.inkSecondary.opacity(0.42), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canAddItem)
            .frame(maxWidth: .infinity, alignment: .trailing)

            TotalSummaryCard(quote: quote)
        }
    }

    private func addItem() {
        guard canAddItem else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            quote.items.append(.blank)
        }
    }
}

struct QuoteItemEditorCard: View {
    @Binding var item: QuoteItem
    let currencySymbol: String
    let onDelete: () -> Void

    private let units = ["個", "式", "場", "件"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack(alignment: .leading) {
                    if item.name.isEmpty {
                        Text("項目名（必須）")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.red.opacity(0.82))
                    }
                    TextField("", text: $item.name)
                        .font(.title3.weight(.bold))
                        .tint(AppTheme.primary)
                }
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.red)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.red.opacity(0.12), in: Circle())
                }
            }

            TextField("説明（任意）", text: $item.detail, axis: .vertical)
                .font(.subheadline)

            HStack(spacing: 10) {
                InputBox(title: "単価") {
                    TextField("0", value: $item.unitPrice, formatter: NumberFormatter.pdfappDecimal)
                        .keyboardType(.decimalPad)
                }
                InputBox(title: "数量") {
                    TextField("1", value: $item.quantity, formatter: NumberFormatter.pdfappDecimal)
                        .keyboardType(.decimalPad)
                }
                InputBox(title: "単位") {
                    Picker("単位", selection: $item.unit) {
                        ForEach(units, id: \.self) { unit in
                            Text(LocalizedStringKey(unit)).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            HStack {
                Text("小計")
                    .font(.headline)
                    .foregroundStyle(AppTheme.inkSecondary)
                Spacer()
                Text(currencyString(item.subtotal, symbol: currencySymbol))
                    .font(.title3.weight(.heavy))
                .foregroundStyle(AppTheme.primary)
            }
        }
        .glassPanel()
        .onAppear {
            if !units.contains(item.unit) {
                item.unit = "個"
            }
        }
    }
}

struct InputBox<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.inkSecondary)
            content
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(hex: 0x111827))
                .tint(AppTheme.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        }
    }
}

struct PriceStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: QuoteStore
    @Binding var quote: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "割引")
                Picker("割引タイプ", selection: $quote.discountMode) {
                    ForEach(DiscountMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.rawValue)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text(quote.discountMode == .amount ? quote.currencySymbol : "%")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color(hex: 0x6B7280))
                TextField("0", value: $quote.discountValue, formatter: NumberFormatter.pdfappDecimal)
                        .font(.title3.weight(.bold))
                        .keyboardType(.decimalPad)
                }
                .padding()
                .foregroundStyle(Color(hex: 0x111827))
                .tint(AppTheme.primary)
                .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onChange(of: quote.discountMode) { _, _ in
                    quote.discountValue = min(max(quote.discountValue, 0), quote.discountMode == .percent ? 100 : quote.subtotal)
                }
                .onChange(of: quote.discountValue) { _, newValue in
                    quote.discountValue = min(max(newValue, 0), quote.discountMode == .percent ? 100 : quote.subtotal)
                }
            }
            .glassPanel()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    SectionLabel(title: "税務設定")
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            quote.taxLines.append(TaxLine(name: store.appLanguage.localized("消費税"), rate: 0))
                        }
                    } label: {
                        Label {
                            Text("税を追加")
                        } icon: {
                            Image(systemName: "plus.circle.fill")
                        }
                            .font(.subheadline.weight(.bold))
                    }
                    .buttonStyle(.plain)
                }

                Picker("税タイプ", selection: $quote.taxMode) {
                    ForEach(TaxMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.rawValue)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(LocalizedStringKey(quote.taxMode.description))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.inkSecondary)

                if quote.taxLines.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "percent")
                            .foregroundStyle(AppTheme.primary)
                        Text("税率は0%です。必要な場合だけ「税を追加」を押してください。")
                            .font(.subheadline)
                            .foregroundStyle(colorScheme == .dark ? Color(hex: 0x111827) : AppTheme.inkSecondary)
                    }
                    .padding()
                    .background(Color.white.opacity(colorScheme == .dark ? 0.90 : 0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    ForEach($quote.taxLines) { $tax in
                        TaxLineEditor(tax: $tax, amount: quote.amount(for: tax), currencySymbol: quote.currencySymbol) {
                            quote.taxLines.removeAll { $0.id == tax.id }
                        }
                    }
                }
            }
            .glassPanel()

            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "日付と備考")
                DatePicker("有効期限", selection: $quote.expiryDate, displayedComponents: .date)
                    .font(.headline)
                Divider()
                TextField("備考", text: $quote.note, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                    .padding()
                    .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .glassPanel()

            TotalSummaryCard(quote: quote)
        }
    }
}

struct TaxLineEditor: View {
    @Binding var tax: TaxLine
    let amount: Double
    let currencySymbol: String
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("税名", text: $tax.name)
                    .font(.headline.weight(.bold))
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.red)
                }
            }

            HStack(spacing: 12) {
                InputBox(title: "税率") {
                    HStack {
                        TextField("0", value: $tax.rate, formatter: NumberFormatter.pdfappDecimal)
                            .keyboardType(.decimalPad)
                        Text("%")
                    }
                }
                InputBox(title: "税額") {
                    Text(currencyString(amount, symbol: currencySymbol))
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.primary.opacity(0.18), lineWidth: 1)
        }
    }
}

struct TotalSummaryCard: View {
    @EnvironmentObject private var store: QuoteStore
    let quote: Quote

    private var discountTitle: String {
        switch quote.discountMode {
        case .amount:
            return "\(store.appLanguage.localized("割引")) (\(store.appLanguage.localized("金額")))"
        case .percent:
            return "\(store.appLanguage.localized("割引")) (\(compactPercent(quote.discountValue))%)"
        }
    }

    private func taxTitle(for tax: TaxLine) -> String {
        let rawName = tax.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = rawName.isEmpty || rawName == "消費税" ? store.appLanguage.localized("税額") : rawName
        return "\(name) (\(compactPercent(tax.rate))%)"
    }

    var body: some View {
        VStack(spacing: 10) {
            SummaryLine(title: store.appLanguage.localized("小計"), value: currencyString(quote.subtotal, symbol: quote.currencySymbol))
            SummaryLine(
                title: discountTitle,
                value: quote.discountAmount > 0 ? "-\(currencyString(quote.discountAmount, symbol: quote.currencySymbol))" : currencyString(0, symbol: quote.currencySymbol),
                valueColor: AppTheme.red
            )
            if quote.taxLines.isEmpty {
                SummaryLine(title: "\(store.appLanguage.localized("税額")) (0%)", value: currencyString(0, symbol: quote.currencySymbol))
            } else {
                ForEach(quote.taxLines) { tax in
                    SummaryLine(title: taxTitle(for: tax), value: currencyString(quote.amount(for: tax), symbol: quote.currencySymbol))
                }
            }
            Divider()
            SummaryLine(title: store.appLanguage.localized("合計"), value: currencyString(quote.grandTotal, symbol: quote.currencySymbol), emphasized: true)
        }
        .glassPanel()
    }
}

struct SummaryLine: View {
    let title: String
    let value: String
    var emphasized = false
    var valueColor: Color?

    var body: some View {
        HStack {
            Text(title)
                .font(emphasized ? .title3.weight(.heavy) : .headline)
            Spacer()
            Text(value)
                .font(emphasized ? .title.weight(.heavy) : .headline.weight(.semibold))
                .foregroundStyle(valueColor ?? (emphasized ? AppTheme.primary : AppTheme.ink))
        }
    }
}

struct PreviewStepView: View {
    @EnvironmentObject private var store: QuoteStore
    @Binding var quote: Quote
    let onPreviewPDF: () -> Void
    @State private var logoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("合計")
                            .font(.headline.weight(.bold))
                        Text(currencyString(quote.grandTotal, symbol: quote.currencySymbol))
                            .font(.system(size: 44, weight: .heavy))
                        (Text("税額") + Text(" \(currencyString(quote.taxAmount, symbol: quote.currencySymbol))"))
                            .font(.headline)
                    }
                    Spacer()
                    Text(LocalizedStringKey(quote.status.rawValue))
                        .font(.subheadline.weight(.heavy))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(.white.opacity(0.22), in: Capsule())
                }
            }
            .foregroundStyle(.white)
            .padding(22)
            .background(LinearGradient(colors: [AppTheme.primary, Color(hex: 0xA08CFF), Color(hex: 0x95E8D7)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "顧客")
                if let customer = quote.customer {
                    SelectedCustomerCard(customer: customer)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "項目")
                ForEach(quote.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.headline.weight(.bold))
                            Text("\(NumberFormatter.pdfappDecimal.string(from: NSNumber(value: item.quantity)) ?? "0") \(store.appLanguage.localized(item.unit)) × \(currencyString(item.unitPrice, symbol: quote.currencySymbol))")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.inkSecondary)
                        }
                        Spacer()
                        Text(currencyString(item.subtotal, symbol: quote.currencySymbol))
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(AppTheme.primary)
                    }
                    .glassPanel()
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "PDF設計スタイル")
                PDFStyleCard(style: .simple, selected: true)
                    .onAppear {
                        quote.pdfStyle = .simple
                    }

                Toggle(isOn: $quote.showCompanyInfo) {
                    Label {
                        Text("PDFに会社情報を表示")
                    } icon: {
                        Image(systemName: "building.2.fill")
                    }
                        .font(.headline.weight(.semibold))
                }

                LogoPickerRow(logoData: quote.logoData, item: $logoItem)
                    .onChange(of: logoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                quote.logoData = data
                            }
                        }
                    }
            }
            .glassPanel()

            SignatureSection(quote: $quote)

            Button(action: onPreviewPDF) {
                Label {
                    Text("PDFプレビュー")
                } icon: {
                    Image(systemName: "eye.fill")
                }
                    .font(.headline.weight(.heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(AppTheme.primary)
                    .background(AppTheme.lavender, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

struct PDFStyleCard: View {
    let style: PDFStyle
    let selected: Bool

    private var detail: String {
        switch style {
        case .simple: "余白を広く取り、読みやすさを優先する標準レイアウト。"
        case .soft: "淡い色面と角丸のブロックで、やわらかい印象に整えるレイアウト。"
        case .compact: "情報密度を高め、項目数が多い見積書に向いた省スペースレイアウト。"
        }
    }

    private var icon: String {
        switch style {
        case .simple: "doc.text"
        case .soft: "sparkles.rectangle.stack"
        case .compact: "list.bullet.rectangle"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 44, height: 44)
                .background(AppTheme.lavender, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(style.rawValue))
                    .font(.headline.weight(.bold))
                Text(LocalizedStringKey(detail))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.inkSecondary)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? AppTheme.primary : AppTheme.inkSecondary)
        }
        .padding(12)
        .background(selected ? AppTheme.primary.opacity(0.08) : Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(selected ? AppTheme.primary.opacity(0.45) : AppTheme.stroke, lineWidth: 1)
        }
    }
}

struct SignatureSection: View {
    @Binding var quote: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(title: "顧客署名")
            Picker("署名方法", selection: $quote.signatureMode) {
                ForEach(SignatureMode.allCases) { mode in
                    Text(LocalizedStringKey(mode.rawValue)).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if quote.signatureMode == .typed {
                TextField("署名者名", text: $quote.typedSignature)
                    .font(.title3.weight(.semibold))
                    .padding()
                    .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                SignaturePadView(imageData: $quote.drawnSignatureData)
            }

            Text("署名はPDFの合計金額の下に表示されます。")
                .font(.footnote)
                .foregroundStyle(AppTheme.inkSecondary)
        }
        .glassPanel()
    }
}

struct SignaturePadView: View {
    @Binding var imageData: Data?
    @State private var strokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.88))
                    Canvas { context, _ in
                        for stroke in strokes + (currentStroke.isEmpty ? [] : [currentStroke]) {
                            var path = Path()
                            if let first = stroke.first {
                                path.move(to: first)
                                for point in stroke.dropFirst() {
                                    path.addLine(to: point)
                                }
                            }
                            context.stroke(path, with: .color(.black), lineWidth: 3)
                        }
                    }
                    Rectangle()
                        .fill(AppTheme.inkSecondary.opacity(0.24))
                        .frame(height: 1)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            currentStroke.append(value.location)
                        }
                        .onEnded { _ in
                            strokes.append(currentStroke)
                            currentStroke.removeAll()
                            renderSignature(size: proxy.size)
                        }
                )
            }
            .frame(height: 150)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            }

            Button {
                strokes.removeAll()
                currentStroke.removeAll()
                imageData = nil
            } label: {
                Label("クリア", systemImage: "trash")
                    .font(.subheadline.weight(.bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.red)
        }
    }

    private func renderSignature(size: CGSize) {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            UIColor.clear.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            UIColor.black.setStroke()
            for stroke in strokes {
                guard let first = stroke.first else { continue }
                let path = UIBezierPath()
                path.move(to: first)
                for point in stroke.dropFirst() {
                    path.addLine(to: point)
                }
                path.lineWidth = 3
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }
        }
        imageData = image.pngData()
    }
}

struct ExportStepView: View {
    let quote: Quote
    let generatedURL: URL?
    let onShare: (URL) -> Void
    let onSave: (URL) -> Void
    let onPrint: (URL) -> Void
    @State private var saveItem: ShareItem?
    @State private var emailItem: ShareItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 54, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 110, height: 110)
                    .background(AppTheme.primary, in: Circle())
                    .shadow(color: AppTheme.primary.opacity(0.24), radius: 20, y: 10)

                Text("見積書を作成しました")
                    .font(.title.weight(.heavy))
                Text("共有、保存、メール、印刷を選べます。")
                    .font(.headline)
                    .foregroundStyle(AppTheme.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "PDFを共有")
                HStack(spacing: 14) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.primary)
                        .frame(width: 56, height: 56)
                        .background(AppTheme.lavender, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(quote.pdfFileName ?? "\(quote.quoteNumber).pdf")
                        .font(.headline.weight(.bold))
                        HStack(spacing: 0) {
                            Text(LocalizedStringKey(PDFStyle.simple.rawValue))
                            Text(" ・ A4 (210 × 297 mm)")
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.inkSecondary)
                    }
                    Spacer()
                }

                if let generatedURL {
                    HStack(spacing: 10) {
                        ExportActionButton(icon: "square.and.arrow.up", title: "共有", tint: AppTheme.primary) { onShare(generatedURL) }
                        ExportActionButton(icon: "tray.and.arrow.down", title: "保存", tint: AppTheme.green) {
                            saveItem = ShareItem(url: generatedURL)
                            onSave(generatedURL)
                        }
                        ExportActionButton(icon: "envelope", title: "Email", tint: AppTheme.blue) {
                            if MailComposeSheet.canSendMail {
                                emailItem = ShareItem(url: generatedURL)
                            } else {
                                onShare(generatedURL)
                            }
                        }
                        ExportActionButton(icon: "printer", title: "印刷", tint: AppTheme.primaryDeep) { onPrint(generatedURL) }
                    }
                } else {
                    Text("PDFファイルを準備中です。")
                        .font(.headline)
                        .foregroundStyle(AppTheme.inkSecondary)
                }
            }
            .glassPanel()
        }
        .sheet(item: $saveItem) { item in
            DocumentExportSheet(url: item.url)
        }
        .sheet(item: $emailItem) { item in
            MailComposeSheet(quote: quote, url: item.url)
        }
    }
}

struct ExportActionButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2.weight(.bold))
                Text(LocalizedStringKey(title))
                    .font(.subheadline.weight(.heavy))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(colorScheme == .dark ? Color.white : tint)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: colorScheme == .dark
                                    ? [tint.opacity(0.50), tint.opacity(0.28), Color.white.opacity(0.12)]
                                    : [tint.opacity(0.22), Color.white.opacity(0.46)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.28) : tint.opacity(0.32), lineWidth: 1)
            }
            .shadow(color: tint.opacity(colorScheme == .dark ? 0.20 : 0.10), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }
}

struct StatusButton: View {
    let status: QuoteStatus
    let title: String
    let subtitle: String
    let action: (QuoteStatus) -> Void

    var body: some View {
        Button { action(status) } label: {
            HStack(spacing: 14) {
                Image(systemName: status.iconName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(status.color)
                    .frame(width: 48, height: 48)
                    .background(status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(title))
                        .font(.headline.weight(.bold))
                    Text(LocalizedStringKey(subtitle))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.inkSecondary)
            }
            .glassPanel()
        }
        .buttonStyle(.plain)
    }
}

private func compactPercent(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }
    return NumberFormatter.pdfappDecimal.string(from: NSNumber(value: value)) ?? "\(value)"
}
