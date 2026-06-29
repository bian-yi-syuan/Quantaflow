import PhotosUI
import SwiftUI
import UIKit

enum AppTab: String, CaseIterable, Identifiable {
    case home = "ホーム"
    case quotes = "見積書"
    case customers = "顧客"
    case settings = "設定"

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        LocalizedStringKey(rawValue)
    }

    var iconName: String {
        switch self {
        case .home: "square.grid.2x2.fill"
        case .quotes: "doc.text.fill"
        case .customers: "person.2.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct AppRootView: View {
    @AppStorage("pdfapp.hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showingSplash = true

    var body: some View {
        Group {
            if showingSplash {
                SplashView()
                    .task {
                        try? await Task.sleep(nanoseconds: 900_000_000)
                        withAnimation(.easeOut(duration: 0.35)) {
                            showingSplash = false
                        }
                    }
            } else if !hasSeenOnboarding {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            } else {
                MainTabView()
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        AppBackground {
            VStack(spacing: 18) {
                Image("QuantaflowLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 124, height: 124)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: AppTheme.primary.opacity(0.25), radius: 24, y: 12)

                Text(AppTheme.brandName)
                    .font(.largeTitle.weight(.heavy))
                Text("見積書と顧客データをすばやく整理")
                    .font(.headline)
                    .foregroundStyle(AppTheme.inkSecondary)
            }
        }
    }
}

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var page = 0

    private let pages = [
        ("doc.badge.plus", "見積書をすばやく作成", "顧客、項目、税率、署名まで一画面ずつ整理できます。", AppTheme.lavender),
        ("rectangle.stack.badge.plus", "データベースを育てる", "見積書を作るたびに、顧客と売上の記録が自動でまとまります。", AppTheme.mint),
        ("square.and.arrow.up", "共有まで一気に", "PDF、Excel、メール、AirDrop、保存、印刷までそのまま進めます。", AppTheme.peach)
    ]

    var body: some View {
        AppBackground {
            VStack(spacing: 24) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 24) {
                            Image(systemName: item.0)
                                .font(.system(size: 58, weight: .bold))
                                .foregroundStyle(AppTheme.primary)
                                .frame(width: 120, height: 120)
                                .background(item.3, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                            VStack(spacing: 12) {
                                Text(LocalizedStringKey(item.1))
                                    .font(.largeTitle.weight(.heavy))
                                    .multilineTextAlignment(.center)
                                Text(LocalizedStringKey(item.2))
                                    .font(.title3)
                                    .foregroundStyle(AppTheme.inkSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal, 24)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                VStack(spacing: 12) {
                    PrimaryButton(title: page == pages.count - 1 ? "はじめる" : "次へ") {
                        if page == pages.count - 1 {
                            hasSeenOnboarding = true
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                page += 1
                            }
                        }
                    }

                    Button("あとで設定する") {
                        hasSeenOnboarding = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.inkSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var store: QuoteStore
    @State private var selectedTab: AppTab = .home
    @State private var draftQuote: Quote?

    var body: some View {
        AppBackground {
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case .home:
                        HomeView(onNewQuote: { draftQuote = store.makeDraft() }, selectTab: { selectedTab = $0 })
                    case .quotes:
                        QuotesListView(onNewQuote: { draftQuote = store.makeDraft() })
                    case .customers:
                        CustomersView()
                    case .settings:
                        SettingsView()
                    }
                }
                .padding(.bottom, 86)

                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
            }
        }
        .sheet(item: $draftQuote) { quote in
            QuoteFlowView(initialQuote: quote)
                .environmentObject(store)
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 22, weight: .bold))
                        Text(tab.titleKey)
                            .font(.caption.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selectedTab == tab ? AppTheme.primary : AppTheme.inkSecondary)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.90) : Color.white.opacity(0.86))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        }
        .clipShape(Capsule())
        .shadow(color: AppTheme.primaryDeep.opacity(0.12), radius: 18, y: 10)
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: QuoteStore
    let onNewQuote: () -> Void
    let selectTab: (AppTab) -> Void
    @State private var selectedPeriod: SalesReportPeriod = .month
    @State private var reportItem: ShareItem?
    @State private var exportError: String?
    @State private var filterSheet: QuoteFilterSheet?
    @State private var selectedQuoteAction: Quote?
    @State private var editingQuote: Quote?
    @State private var deleteCandidate: Quote?
    @State private var previewItem: ShareItem?

    private var periodQuotes: [Quote] {
        let calendar = Calendar.current
        let now = Date()
        return store.quotes.filter { quote in
            switch selectedPeriod {
            case .month:
                return calendar.isDate(quote.issueDate, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(quote.issueDate, equalTo: now, toGranularity: .year)
            }
        }
    }

    private var acceptedQuotes: [Quote] {
        periodQuotes.filter { $0.status == .accepted }
    }

    private var processingQuotes: [Quote] {
        periodQuotes.filter { [.draft, .processing, .sent].contains($0.status) }
    }

    private var acceptedTotalsByCurrency: [(symbol: String, total: Double)] {
        Dictionary(grouping: acceptedQuotes, by: \.currencySymbol)
            .map { (symbol: $0.key, total: $0.value.reduce(0) { $0 + $1.grandTotal }) }
            .sorted { $0.total > $1.total }
            .prefix(5)
            .map { $0 }
    }

    private var recentCompletedQuotes: [Quote] {
        Array(store.quotes.filter { $0.pdfFileName != nil || $0.status == .accepted || $0.status == .sent }.prefix(5))
    }

    private var recentCustomers: [Customer] {
        Array(store.customers.sorted { $0.lastUpdated > $1.lastUpdated }.prefix(5))
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: store.appLanguage.localeIdentifier)
        switch store.appLanguage {
        case .english:
            formatter.dateFormat = "MMM d, EEEE"
        default:
            formatter.dateFormat = "M月d日 EEEE"
        }
        return formatter.string(from: Date())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    (Text("こんにちは") + Text(" ・ \(dateText)"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.inkSecondary)
                    Text("今日は誰に見積もりますか？")
                        .font(.largeTitle.weight(.heavy))
                }
                .padding(.top, 18)

                NewQuoteHero(action: onNewQuote)

                SalesOverviewCard(
                    selectedPeriod: $selectedPeriod,
                    acceptedTotalsByCurrency: acceptedTotalsByCurrency,
                    acceptedCount: acceptedQuotes.count,
                    processingCount: processingQuotes.count,
                    quoteCount: periodQuotes.count,
                    onAccepted: { showFilter(title: filterTitle(period: selectedPeriod, suffix: "承認済み"), quotes: acceptedQuotes) },
                    onProcessing: { showFilter(title: filterTitle(period: selectedPeriod, suffix: "処理中"), quotes: processingQuotes) },
                    onAll: { showFilter(title: filterTitle(period: selectedPeriod, suffix: "件数"), quotes: periodQuotes) },
                    onExport: exportReport
                )

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(title: "最近成立した見積書", actionTitle: "すべて表示") {
                        selectTab(.quotes)
                    }

                    if recentCompletedQuotes.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "tray")
                            Text("成立済みの見積書はまだありません。")
                            Spacer()
                        }
                        .font(.headline)
                        .foregroundStyle(AppTheme.inkSecondary)
                        .glassPanel()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(recentCompletedQuotes) { quote in
                                Button {
                                    selectedQuoteAction = quote
                                } label: {
                                    RecentQuoteShortcut(quote: quote)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel(title: "最近の顧客", actionTitle: "管理") {
                        selectTab(.customers)
                    }
                    if recentCustomers.isEmpty {
                        HStack(spacing: 12) {
                            EmptyStateView(
                                icon: "person.crop.circle.badge.plus",
                                title: "顧客資料を追加",
                                message: "まだ顧客は登録されていません。顧客を追加すると、見積書作成時にすぐ選択できます。",
                                buttonTitle: "顧客を管理",
                                buttonIcon: "person.2.fill"
                            ) {
                                selectTab(.customers)
                            }
                        }
                    } else {
                        VStack(spacing: 10) {
                            ForEach(recentCustomers) { customer in
                                CustomerMiniRow(customer: customer)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .sheet(item: $reportItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        .sheet(item: $filterSheet) { sheet in
            QuoteFilterSheetView(sheet: sheet) { quote in
                filterSheet = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    selectedQuoteAction = quote
                }
            }
        }
        .sheet(item: $selectedQuoteAction) { quote in
            QuoteQuickActionSheet(
                quote: quote,
                onEdit: {
                    selectedQuoteAction = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        editingQuote = quote
                    }
                },
                onShare: {
                    shareQuote(quote)
                },
                onPreview: {
                    previewQuote(quote)
                },
                onAccept: {
                    store.updateStatus(for: quote.id, to: .accepted)
                    selectedQuoteAction = nil
                },
                onDelete: {
                    selectedQuoteAction = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        deleteCandidate = quote
                    }
                }
            )
            .environmentObject(store)
        }
        .sheet(item: $editingQuote) { quote in
            QuoteFlowView(initialQuote: quote, isEditing: true)
                .environmentObject(store)
        }
        .sheet(item: $previewItem) { item in
            PDFPreviewSheet(url: item.url)
        }
        .alert("見積書を削除しますか？", isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } })) {
            Button("キャンセル", role: .cancel) { deleteCandidate = nil }
            Button("削除", role: .destructive) {
                if let deleteCandidate {
                    store.deleteQuote(deleteCandidate)
                }
                deleteCandidate = nil
            }
        } message: {
            Text("削除するとホームの今月・今年の集計も更新されます。")
        }
        .alert("Excel出力エラー", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private func exportReport() {
        do {
            let url = try store.exportSalesReport(period: selectedPeriod)
            reportItem = ShareItem(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func shareQuote(_ quote: Quote) {
        do {
            let url = try store.exportPDF(for: quote)
            selectedQuoteAction = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                reportItem = ShareItem(url: url)
            }
        } catch {
            selectedQuoteAction = nil
            exportError = error.localizedDescription
        }
    }

    private func previewQuote(_ quote: Quote) {
        do {
            let url = try store.exportPDF(for: quote)
            selectedQuoteAction = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                previewItem = ShareItem(url: url)
            }
        } catch {
            selectedQuoteAction = nil
            exportError = error.localizedDescription
        }
    }

    private func showFilter(title: String, quotes: [Quote]) {
        filterSheet = QuoteFilterSheet(title: title, quotes: quotes.sorted { lhs, rhs in
            if lhs.sequenceNumber == rhs.sequenceNumber {
                return lhs.issueDate > rhs.issueDate
            }
            return lhs.sequenceNumber > rhs.sequenceNumber
        })
    }

    private func filterTitle(period: SalesReportPeriod, suffix: String) -> String {
        "\(period.rawValue)・\(suffix)"
    }
}

struct SalesOverviewCard: View {
    @Binding var selectedPeriod: SalesReportPeriod
    let acceptedTotalsByCurrency: [(symbol: String, total: Double)]
    let acceptedCount: Int
    let processingCount: Int
    let quoteCount: Int
    let onAccepted: () -> Void
    let onProcessing: () -> Void
    let onAll: () -> Void
    let onExport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(title: "業績概要")

            VStack(alignment: .leading, spacing: 14) {
                Picker("期間", selection: $selectedPeriod) {
                    ForEach(SalesReportPeriod.allCases) { period in
                        Text(LocalizedStringKey(period.rawValue)).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 6) {
                    if acceptedTotalsByCurrency.isEmpty {
                        Text(currencyString(0, symbol: "¥"))
                            .font(.system(size: 42, weight: .heavy))
                    } else {
                        ForEach(Array(acceptedTotalsByCurrency.enumerated()), id: \.offset) { index, item in
                            Text(currencyString(item.total, symbol: item.symbol))
                                .font(.system(size: index == 0 ? 42 : 27, weight: .heavy))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }
                }
                Text(LocalizedStringKey("\(selectedPeriod.rawValue)の承認済み見積合計"))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.inkSecondary)

                HStack(spacing: 12) {
                    Button(action: onAccepted) {
                        MetricTile(icon: "checkmark.seal.fill", title: "承認済み", value: "\(acceptedCount)", tint: AppTheme.green)
                    }
                    .buttonStyle(.plain)
                    Button(action: onProcessing) {
                        MetricTile(icon: "hourglass", title: "処理中", value: "\(processingCount)", tint: AppTheme.orange)
                    }
                    .buttonStyle(.plain)
                    Button(action: onAll) {
                        MetricTile(icon: "doc.text.fill", title: "件数", value: "\(quoteCount)", tint: AppTheme.primary)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onExport) {
                    Label {
                        Text("Excel出力・共有")
                    } icon: {
                        Image(systemName: "tablecells.fill")
                    }
                        .font(.headline.weight(.heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(AppTheme.primary, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .glassPanel()
        }
    }
}

struct QuoteFilterSheet: Identifiable {
    let id = UUID()
    let title: String
    let quotes: [Quote]
}

struct QuoteFilterSheetView: View {
    let sheet: QuoteFilterSheet
    let onSelect: (Quote) -> Void

    var body: some View {
        NavigationStack {
            AppBackground {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if sheet.quotes.isEmpty {
                            EmptyStateView(
                                icon: "tray",
                                title: "対象の見積書はありません",
                                message: "この期間と状態に該当する見積書はまだありません。"
                            )
                            .padding(.top, 24)
                        } else {
                            ForEach(sheet.quotes) { quote in
                                Button {
                                    onSelect(quote)
                                } label: {
                                    QuoteRow(quote: quote)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle(LocalizedStringKey(sheet.title))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct QuoteQuickActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let quote: Quote
    let onEdit: () -> Void
    let onShare: () -> Void
    let onPreview: () -> Void
    let onAccept: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            AppBackground {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(quote.quoteNumber)
                                    .font(.title2.weight(.heavy))
                                if let customer = quote.customer {
                                    Text(customer.displayName)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.inkSecondary)
                                } else {
                                    Text("顧客未設定")
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.inkSecondary)
                                }
                            }
                            Spacer()
                            Text(LocalizedStringKey(quote.status.rawValue))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(quote.status.color)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(quote.status.color.opacity(0.12), in: Capsule())
                        }

                        Divider()

                        HStack {
                            Text("合計")
                                .font(.headline)
                                .foregroundStyle(AppTheme.inkSecondary)
                            Spacer()
                            Text(currencyString(quote.grandTotal, symbol: quote.currencySymbol))
                                .font(.title.weight(.heavy))
                                .foregroundStyle(AppTheme.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .glassPanel()

                    VStack(spacing: 12) {
                        PrimaryButton(title: "この見積書を編集", systemImage: "pencil") {
                            dismiss()
                            onEdit()
                        }

                        Button {
                            dismiss()
                            onShare()
                        } label: {
                            Label {
                                Text("この見積書を共有")
                            } icon: {
                                Image(systemName: "square.and.arrow.up")
                            }
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundStyle(AppTheme.primary)
                                .background(AppTheme.lavender.opacity(0.82), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            dismiss()
                            onPreview()
                        } label: {
                            Label {
                                Text("この見積書をプレビュー")
                            } icon: {
                                Image(systemName: "eye.fill")
                            }
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundStyle(AppTheme.blue)
                                .background(AppTheme.blue.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            dismiss()
                            onAccept()
                        } label: {
                            Label {
                                Text(LocalizedStringKey(quote.status == .accepted ? "承認済みです" : "承認済みに切り替え"))
                            } icon: {
                                Image(systemName: "checkmark.seal.fill")
                            }
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundStyle(.white)
                                .background(quote.status == .accepted ? AppTheme.inkSecondary.opacity(0.35) : AppTheme.green, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(quote.status == .accepted)

                        Button(role: .destructive) {
                            dismiss()
                            onDelete()
                        } label: {
                            Label {
                                Text("削除")
                            } icon: {
                                Image(systemName: "trash.fill")
                            }
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundStyle(AppTheme.red)
                                .background(AppTheme.red.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(18)
            }
            .navigationTitle(LocalizedStringKey("見積書の操作"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

struct NewQuoteHero: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Label(AppTheme.brandName, systemImage: "sparkles")
                    .font(.headline.weight(.heavy))
                Spacer()
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(.white.opacity(0.62))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("新規見積書")
                    .font(.largeTitle.weight(.heavy))
                Text("顧客・商品・金額をきれいに整理")
                    .font(.title3.weight(.medium))
            }

            Button(action: action) {
                Label("今すぐ作成", systemImage: "arrow.right.circle.fill")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.vertical, 13)
                    .padding(.horizontal, 20)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [AppTheme.primary, Color(hex: 0x9B8BFF), Color(hex: 0x8EE8D8)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .shadow(color: AppTheme.primary.opacity(0.18), radius: 20, y: 12)
    }
}

struct RecentQuoteShortcut: View {
    let quote: Quote

    var body: some View {
        QuoteRow(quote: quote)
    }
}

struct QuoteRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let quote: Quote

    private var displayStatus: QuoteStatus {
        quote.status == .accepted ? .accepted : .processing
    }

    private var statusTitle: LocalizedStringKey {
        displayStatus == .accepted ? "承認済み" : "処理中"
    }

    private var statusColor: Color {
        displayStatus == .accepted ? AppTheme.green : AppTheme.red
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: displayStatus.iconName)
                .font(.title2.weight(.bold))
                .foregroundStyle(displayStatus.color)
                .frame(width: 54, height: 54)
                .background(displayStatus.color.opacity(colorScheme == .dark ? 0.20 : 0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(quote.quoteNumber)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(AppTheme.ink)
                if let customer = quote.customer {
                    Text(customer.displayName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.inkSecondary)
                } else {
                    Text("顧客未設定")
                        .font(.headline)
                        .foregroundStyle(AppTheme.inkSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(currencyString(quote.grandTotal, symbol: quote.currencySymbol))
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(colorScheme == .dark ? Color(hex: 0x9DBBFF) : Color(hex: 0x334766))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(statusTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(statusColor)
            }
        }
        .padding(16)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.82))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.20 : 0.78), lineWidth: 1)
        }
        .shadow(color: AppTheme.primaryDeep.opacity(0.07), radius: 14, y: 7)
    }
}

struct CustomerMiniRow: View {
    let customer: Customer

    var body: some View {
        HStack(spacing: 14) {
            Text(customer.initials)
                .font(.headline.weight(.heavy))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 48, height: 48)
                .background(AppTheme.lavender, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(customer.displayName)
                    .font(.headline.weight(.bold))
                if !customer.subtitle.isEmpty {
                    Text(customer.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.inkSecondary)
                }
            }
            Spacer()
        }
        .glassPanel()
    }
}

struct QuotesListView: View {
    @EnvironmentObject private var store: QuoteStore
    let onNewQuote: () -> Void
    @State private var searchText = ""
    @State private var selectedQuoteAction: Quote?
    @State private var editingQuote: Quote?
    @State private var deleteCandidate: Quote?
    @State private var shareItem: ShareItem?
    @State private var previewItem: ShareItem?
    @State private var shareError: String?

    private var filteredQuotes: [Quote] {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return store.quotes }
        return store.quotes.filter {
            $0.quoteNumber.localizedCaseInsensitiveContains(text) ||
            ($0.customer?.displayName.localizedCaseInsensitiveContains(text) ?? false) ||
            $0.items.contains { $0.name.localizedCaseInsensitiveContains(text) }
        }
    }

    private var processingCount: Int {
        store.quotes.filter { [.draft, .processing, .sent].contains($0.status) }.count
    }

    private var acceptedCount: Int {
        store.quotes.filter { $0.status == .accepted }.count
    }

    private var acceptedTotalsByCurrency: [(symbol: String, total: Double)] {
        Dictionary(grouping: store.quotes.filter { $0.status == .accepted }, by: \.currencySymbol)
            .map { (symbol: $0.key, total: $0.value.reduce(0) { $0 + $1.grandTotal }) }
            .sorted { $0.total > $1.total }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    Text("見積書")
                        .font(.largeTitle.weight(.heavy))
                    Spacer()
                    Button(action: onNewQuote) {
                        Image(systemName: "plus")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 50, height: 42)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 18)

                SearchField(placeholder: "番号、顧客、項目を検索", text: $searchText)

                HStack(spacing: 10) {
                    MetricTile(icon: "checkmark.seal.fill", title: "承認済み", value: "\(acceptedCount)", tint: AppTheme.green)
                    MetricTile(icon: "hourglass", title: "処理中", value: "\(processingCount)", tint: AppTheme.orange)
                    MetricTile(icon: "doc.text.fill", title: "件数", value: "\(store.quotes.count)", tint: AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("承認済み総額")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.inkSecondary)
                    if acceptedTotalsByCurrency.isEmpty {
                        Text(currencyString(0, symbol: "¥"))
                            .font(.largeTitle.weight(.heavy))
                            .foregroundStyle(AppTheme.primary)
                    } else {
                        ForEach(Array(acceptedTotalsByCurrency.enumerated()), id: \.offset) { index, item in
                            Text(currencyString(item.total, symbol: item.symbol))
                                .font(index == 0 ? .largeTitle.weight(.heavy) : .title2.weight(.heavy))
                                .foregroundStyle(AppTheme.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(padding: 22)

                if filteredQuotes.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "見積書はまだありません",
                        message: "右上の＋、またはホームから最初の見積書を作成できます。",
                        buttonTitle: "見積書を作成",
                        action: onNewQuote
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(filteredQuotes) { quote in
                            SwipeableQuoteRow(
                                quote: quote,
                                onOpen: {
                                    selectedQuoteAction = quote
                                },
                                onEdit: {
                                    editingQuote = quote
                                },
                                onDelete: {
                                    deleteCandidate = quote
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .sheet(item: $selectedQuoteAction) { quote in
            QuoteQuickActionSheet(
                quote: quote,
                onEdit: {
                    selectedQuoteAction = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        editingQuote = quote
                    }
                },
                onShare: {
                    shareQuote(quote)
                },
                onPreview: {
                    previewQuote(quote)
                },
                onAccept: {
                    store.updateStatus(for: quote.id, to: .accepted)
                    selectedQuoteAction = nil
                },
                onDelete: {
                    selectedQuoteAction = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        deleteCandidate = quote
                    }
                }
            )
            .environmentObject(store)
        }
        .sheet(item: $editingQuote) { quote in
            QuoteFlowView(initialQuote: quote, isEditing: true)
                .environmentObject(store)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        .sheet(item: $previewItem) { item in
            PDFPreviewSheet(url: item.url)
        }
        .alert("見積書を削除しますか？", isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } })) {
            Button("キャンセル", role: .cancel) { deleteCandidate = nil }
            Button("削除", role: .destructive) {
                if let deleteCandidate {
                    store.deleteQuote(deleteCandidate)
                }
                deleteCandidate = nil
            }
        } message: {
            Text("削除するとホームの今月・今年の集計も更新されます。")
        }
        .alert("共有エラー", isPresented: Binding(get: { shareError != nil }, set: { if !$0 { shareError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareError ?? "")
        }
    }

    private func shareQuote(_ quote: Quote) {
        do {
            let url = try store.exportPDF(for: quote)
            selectedQuoteAction = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                shareItem = ShareItem(url: url)
            }
        } catch {
            selectedQuoteAction = nil
            shareError = error.localizedDescription
        }
    }

    private func previewQuote(_ quote: Quote) {
        do {
            let url = try store.exportPDF(for: quote)
            selectedQuoteAction = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                previewItem = ShareItem(url: url)
            }
        } catch {
            selectedQuoteAction = nil
            shareError = error.localizedDescription
        }
    }
}

struct SwipeableQuoteRow: View {
    let quote: Quote
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var resetTask: DispatchWorkItem?
    private let leadingWidth: CGFloat = 92
    private let trailingWidth: CGFloat = 92

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                SwipeQuoteAction(icon: "pencil", title: "編集", tint: AppTheme.green) {
                    reset()
                    onEdit()
                }

                Spacer()

                SwipeQuoteAction(icon: "trash.fill", title: "削除", tint: AppTheme.red) {
                    reset()
                    onDelete()
                }
            }
            .padding(.horizontal, 6)

            Button {
                onOpen()
            } label: {
                QuoteRow(quote: quote)
            }
            .buttonStyle(.plain)
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onChanged { value in
                        let translation = value.translation.width
                        if translation > 0 {
                            offset = min(translation, leadingWidth)
                        } else {
                            offset = max(translation, -trailingWidth)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            if value.translation.width > 72 {
                                offset = leadingWidth
                                scheduleAutoReset()
                            } else if value.translation.width < -52 {
                                offset = -trailingWidth
                                scheduleAutoReset()
                            } else {
                                offset = 0
                            }
                        }
                    }
            )
        }
        .clipped()
    }

    private func reset() {
        resetTask?.cancel()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            offset = 0
        }
    }

    private func scheduleAutoReset() {
        resetTask?.cancel()
        let task = DispatchWorkItem {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                offset = 0
            }
        }
        resetTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: task)
    }
}

struct SwipeQuoteAction: View {
    let icon: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                Text(LocalizedStringKey(title))
                    .font(.caption2.weight(.heavy))
            }
            .foregroundStyle(.white)
            .frame(width: 64, height: 68)
            .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

enum CustomerSort: String, CaseIterable, Identifiable {
    case recent = "最近"
    case name = "名前"
    case amount = "金額"

    var id: String { rawValue }
}

struct CustomersView: View {
    @EnvironmentObject private var store: QuoteStore
    @State private var searchText = ""
    @State private var sort: CustomerSort = .recent
    @State private var showingNewCustomer = false
    @State private var editingCustomer: Customer?
    @State private var deleteCustomerCandidate: Customer?

    private var filteredCustomers: [Customer] {
        var list = store.customers
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            list = list.filter {
                $0.displayName.localizedCaseInsensitiveContains(text) ||
                $0.phone.localizedCaseInsensitiveContains(text) ||
                $0.email.localizedCaseInsensitiveContains(text)
            }
        }

        switch sort {
        case .recent:
            return list.sorted { $0.lastUpdated > $1.lastUpdated }
        case .name:
            return list.sorted { $0.displayName < $1.displayName }
        case .amount:
            return list.sorted { amount(for: $0) > amount(for: $1) }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("顧客")
                        .font(.largeTitle.weight(.heavy))
                    Spacer()
                    Button { showingNewCustomer = true } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 58, height: 42)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 18)

                SearchField(placeholder: "顧客、会社、電話を検索", text: $searchText)

                HStack {
                    Text("並び替え")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.inkSecondary)
                    Picker("並び替え", selection: $sort) {
                        ForEach(CustomerSort.allCases) { option in
                            Text(LocalizedStringKey(option.rawValue)).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if filteredCustomers.isEmpty {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.plus",
                        title: "顧客資料を追加",
                        message: "ここはまだ空白です。会社名、連絡先、住所を登録すると、見積書へ自動で反映できます。",
                        buttonTitle: "新規顧客を追加",
                        buttonIcon: "person.badge.plus",
                        action: { showingNewCustomer = true }
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(filteredCustomers) { customer in
                            CustomerRow(
                                customer: customer,
                                total: amount(for: customer),
                                onEdit: { editingCustomer = customer },
                                onDelete: { deleteCustomerCandidate = customer }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .sheet(isPresented: $showingNewCustomer) {
            CustomerEditorView(customer: .empty) { customer in
                store.addCustomer(customer)
            }
        }
        .sheet(item: $editingCustomer) { customer in
            CustomerEditorView(customer: customer, title: "顧客を編集") { customer in
                store.saveCustomer(customer)
            }
        }
        .alert("顧客を削除しますか？", isPresented: Binding(get: { deleteCustomerCandidate != nil }, set: { if !$0 { deleteCustomerCandidate = nil } })) {
            Button("キャンセル", role: .cancel) { deleteCustomerCandidate = nil }
            Button("削除", role: .destructive) {
                if let deleteCustomerCandidate {
                    store.deleteCustomer(deleteCustomerCandidate)
                }
                deleteCustomerCandidate = nil
            }
        } message: {
            Text("削除すると、この顧客は一覧から消え、関連する見積書の顧客情報も解除されます。")
        }
    }

    private func amount(for customer: Customer) -> Double {
        store.quotes
            .filter { $0.customer?.id == customer.id }
            .reduce(0) { $0 + $1.grandTotal }
    }
}

struct CustomerRow: View {
    let customer: Customer
    let total: Double
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(customer.initials)
                .font(.headline.weight(.heavy))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 54, height: 54)
                .background(AppTheme.lavender, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(customer.displayName)
                    .font(.headline.weight(.bold))
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
            VStack(alignment: .trailing, spacing: 10) {
                Text(currencyString(total))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.primary)
                HStack(spacing: 8) {
                    CustomerIconButton(systemImage: "pencil", tint: AppTheme.primary, action: onEdit)
                    CustomerIconButton(systemImage: "trash.fill", tint: AppTheme.red, action: onDelete)
                }
            }
        }
        .glassPanel()
    }
}

struct CustomerIconButton: View {
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(LocalizedStringKey(systemImage == "pencil" ? "編集" : "削除"))
    }
}

struct CustomerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var customer: Customer
    let title: String
    let onSave: (Customer) -> Void

    init(customer: Customer, title: String = "顧客を追加", onSave: @escaping (Customer) -> Void) {
        _customer = State(initialValue: customer)
        self.title = title
        self.onSave = onSave
    }

    private var canSave: Bool {
        !customer.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !customer.company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("名前", text: $customer.name)
                    TextField("会社名", text: $customer.company)
                    TextField("登録番号", text: $customer.registrationNumber)
                }

                Section("連絡先") {
                    TextField("電話", text: $customer.phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $customer.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("住所", text: $customer.address, axis: .vertical)
                        .lineLimit(3...6)
                        .textContentType(.fullStreetAddress)
                }
            }
            .navigationTitle(LocalizedStringKey(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave(customer)
                        dismiss()
                    }
                    .disabled(!canSave)
                    .fontWeight(.bold)
                }
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var store: QuoteStore
    @State private var showingCompanyEditor = false
    @State private var showingQuoteSettings = false
    @State private var shareItem: ShareItem?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("設定")
                    .font(.largeTitle.weight(.heavy))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 18)

                SettingsHero()

                SettingGroup(title: "見積書設定と業績") {
                    InfoRow(icon: "building.2.fill", title: "会社", subtitle: "会社名、住所、連絡先、ロゴ", trailing: store.company.name) {
                        showingCompanyEditor = true
                    }
                    Divider()
                    InfoRow(icon: "number", title: "見積書設定", subtitle: "通貨、PDFロゴ、書類の初期設定", trailing: store.currency.rawValue) {
                        showingQuoteSettings = true
                    }
                }

                SettingGroup(title: "到期リマインダー") {
                    Toggle(isOn: Binding(get: { store.dueReminderEnabled }, set: { store.setDueReminderEnabled($0) })) {
                        Label("期限前に通知", systemImage: "bell.fill")
                            .font(.headline.weight(.semibold))
                    }
                }

                SettingGroup(title: "言語") {
                    Picker("言語", selection: $store.appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.rawValue).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("初期表示は日本語です。選択した言語設定は保存されます。")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SettingGroup(title: "外観") {
                    DarkModeSwitch(isOn: $store.isDarkMode)
                }

                SettingGroup(title: "サポート") {
                    InfoRow(icon: "star.fill", title: "Quantaflow APPを評価") {
                        if let url = URL(string: "https://apps.apple.com/app/quantaflow") {
                            openURL(url)
                        }
                    }
                    Divider()
                    InfoRow(icon: "square.and.arrow.up", title: "Quantaflow APPを共有") {
                        if let url = URL(string: "https://apps.apple.com/app/quantaflow") {
                            shareItem = ShareItem(url: url)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .sheet(isPresented: $showingCompanyEditor) {
            CompanyEditorView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showingQuoteSettings) {
            QuoteSettingsView()
                .environmentObject(store)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
    }
}

struct SettingsHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text("データベースをすばやく構築")
                        .font(.title2.weight(.heavy))
                    Text("顧客・見積・売上をQuantaflowで整理")
                        .font(.headline)
                        .opacity(0.86)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [AppTheme.primary, Color(hex: 0xA892FF), Color(hex: 0x9EE7D9)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}

struct DarkModeSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 1.0)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isOn ? "moon.stars.fill" : "sun.max.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(isOn ? Color(hex: 0x23215B) : AppTheme.orange, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(isOn ? "ダークモード" : "ライトモード"))
                        .font(.headline.weight(.bold))
                }
                Spacer()
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? AppTheme.primaryDeep : AppTheme.butter)
                    Circle()
                        .fill(.white)
                        .padding(4)
                        .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
                }
                .frame(width: 70, height: 38)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CompanyEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: QuoteStore
    @State private var company: CompanyProfile = .default
    @State private var logoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("会社ロゴ") {
                    LogoPickerRow(logoData: company.logoData, item: $logoItem)
                }
                Section("会社情報") {
                    TextField("会社名", text: $company.name)
                    TextField("担当者名", text: $company.ownerName)
                    TextField("登録番号", text: $company.registrationNumber)
                    TextField("電話", text: $company.phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $company.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Webサイト", text: $company.website)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("住所", text: $company.address, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("会社")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        store.company = company
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                company = store.company
            }
            .onChange(of: logoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        company.logoData = data
                    }
                }
            }
        }
    }
}

struct QuoteSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: QuoteStore
    @State private var selectedCurrency: CurrencyOption = .jpy
    @State private var logoItem: PhotosPickerItem?
    @State private var logoData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("通貨") {
                    Picker("通貨", selection: $selectedCurrency) {
                        ForEach(CurrencyOption.allCases) { currency in
                            Text(store.appLanguage.localized(currency.displayName)).tag(currency)
                        }
                    }
                }

                Section("PDFロゴ") {
                    LogoPickerRow(logoData: logoData, item: $logoItem)
                    Text("ここで登録したロゴは、新しく作る見積書とPDFに反映されます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("見積書設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        store.currency = selectedCurrency
                        var updatedCompany = store.company
                        updatedCompany.logoData = logoData
                        store.company = updatedCompany
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                selectedCurrency = store.currency
                logoData = store.company.logoData
            }
            .onChange(of: logoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        logoData = data
                    }
                }
            }
        }
    }
}

struct LogoPickerRow: View {
    let logoData: Data?
    @Binding var item: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let logoData, let image = UIImage(data: logoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .frame(width: 64, height: 64)
            .background(AppTheme.lavender, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("会社LOGO")
                    .font(.headline.weight(.bold))
                Text("写真ライブラリから選択")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            PhotosPicker(selection: $item, matching: .images) {
                Text("選択")
                    .font(.headline.weight(.bold))
            }
        }
    }
}

struct SettingGroup<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(title))
                .font(.headline)
                .foregroundStyle(AppTheme.inkSecondary)
            VStack(spacing: 12) {
                content
            }
            .glassPanel()
        }
    }
}

struct MainTabViewPreviews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(QuoteStore.preview)
    }
}
