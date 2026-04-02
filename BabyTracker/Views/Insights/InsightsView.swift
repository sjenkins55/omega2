import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var viewModel: InsightsViewModel?
    @State private var selectedTab: InsightTab = .feeding

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    content(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { buildViewModel() }
        .onChange(of: appState.activeBabyID) { buildViewModel() }
    }

    // MARK: - Content

    private func content(vm: InsightsViewModel) -> some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $selectedTab) {
                ForEach(InsightTab.allCases, id: \.self) { tab in
                    Text(tab.label).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Range picker
            Picker("Range", selection: Binding(
                get: { vm.selectedRange },
                set: { vm.selectedRange = $0 }
            )) {
                ForEach(InsightRange.allCases, id: \.self) {
                    Text($0.label).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 12)

            if vm.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .feeding:  FeedingChartSection(vm: vm)
                        case .sleep:    SleepChartSection(vm: vm)
                        case .diapers:  DiaperChartSection(vm: vm)
                        }
                    }
                    .padding()
                }
            }
        }
        .task { await vm.load() }
        .onChange(of: appState.activeBabyID) { Task { await vm.load() } }
    }

    private func buildViewModel() {
        guard let babyID = appState.activeBabyID else { return }
        if viewModel?.babyID == babyID { return }
        viewModel = InsightsViewModel(babyID: babyID, modelContext: modelContext)
    }
}

enum InsightTab: CaseIterable {
    case feeding, sleep, diapers
    var label: String {
        switch self { case .feeding: "Feeding"; case .sleep: "Sleep"; case .diapers: "Diapers" }
    }
}

// MARK: - Feeding Charts

struct FeedingChartSection: View {
    let vm: InsightsViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Stat cards
            HStack(spacing: 12) {
                InsightStatCard(title: "Feeds", value: "\(vm.totalFeedsThisWeek)",
                                subtitle: "this period", color: .blue)
                InsightStatCard(title: "Avg Interval", value: vm.avgIntervalLabel,
                                subtitle: "between feeds", color: .cyan)
            }

            // Feed count bar chart
            InsightCard(title: "Feeds per Day") {
                if vm.feedDailyData.isEmpty {
                    emptyChart
                } else {
                    Chart(vm.feedDailyData) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Feeds", point.feedCount)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: axisDayStride(vm.feedDailyData.count))) {
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 160)
                }
            }

            // Volume bar chart (only if bottle/pump data exists)
            if vm.feedDailyData.contains(where: { $0.totalVolumeMl > 0 }) {
                InsightCard(title: "Daily Volume (ml)") {
                    Chart(vm.feedDailyData) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("ml", point.totalVolumeMl)
                        )
                        .foregroundStyle(Color.cyan.gradient)
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: axisDayStride(vm.feedDailyData.count))) {
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 160)
                }
            }
        }
    }
}

// MARK: - Sleep Charts

struct SleepChartSection: View {
    let vm: InsightsViewModel

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                InsightStatCard(title: "Avg Night", value: vm.avgNightSleepLabel,
                                subtitle: "per night", color: .indigo)
                InsightStatCard(title: "Longest", value: vm.longestStretchLabel,
                                subtitle: "single stretch", color: .purple)
            }

            InsightCard(title: "Sleep per Day (hours)") {
                if vm.sleepDailyData.isEmpty {
                    emptyChart
                } else {
                    Chart {
                        ForEach(vm.sleepDailyData) { point in
                            BarMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Hours", point.napMinutes / 60)
                            )
                            .foregroundStyle(by: .value("Type", "Nap"))
                            .cornerRadius(2)

                            BarMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Hours", point.nightMinutes / 60)
                            )
                            .foregroundStyle(by: .value("Type", "Night"))
                            .cornerRadius(2)
                        }
                    }
                    .chartForegroundStyleScale([
                        "Nap": Color.purple.opacity(0.6),
                        "Night": Color.indigo
                    ])
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: axisDayStride(vm.sleepDailyData.count))) {
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisValueLabel(format: .number.precision(.fractionLength(0)))
                        }
                    }
                    .chartLegend(position: .topTrailing)
                    .frame(height: 180)
                }
            }

            // Sleep line chart (total trend)
            InsightCard(title: "Total Sleep Trend") {
                if vm.sleepDailyData.isEmpty {
                    emptyChart
                } else {
                    Chart(vm.sleepDailyData) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Hours", point.totalMinutes / 60)
                        )
                        .foregroundStyle(Color.indigo)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Hours", point.totalMinutes / 60)
                        )
                        .foregroundStyle(Color.indigo.opacity(0.12))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: axisDayStride(vm.sleepDailyData.count))) {
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisValueLabel(format: .number.precision(.fractionLength(0)))
                        }
                    }
                    .frame(height: 160)
                }
            }
        }
    }
}

// MARK: - Diaper Charts

struct DiaperChartSection: View {
    let vm: InsightsViewModel

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                InsightStatCard(title: "Avg / Day", value: String(format: "%.1f", vm.avgDiapersPerDay),
                                subtitle: "diapers", color: .orange)
                InsightStatCard(title: "Total", value: "\(vm.diaperDailyData.map(\.totalCount).reduce(0, +))",
                                subtitle: "this period", color: .brown)
            }

            InsightCard(title: "Diapers per Day") {
                if vm.diaperDailyData.isEmpty {
                    emptyChart
                } else {
                    Chart {
                        ForEach(vm.diaperDailyData) { point in
                            BarMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Count", point.wetCount)
                            )
                            .foregroundStyle(by: .value("Type", "Wet"))
                            .cornerRadius(2)

                            BarMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Count", point.dirtyCount)
                            )
                            .foregroundStyle(by: .value("Type", "Dirty"))
                            .cornerRadius(2)
                        }
                    }
                    .chartForegroundStyleScale([
                        "Wet": Color.blue.opacity(0.7),
                        "Dirty": Color.orange
                    ])
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: axisDayStride(vm.diaperDailyData.count))) {
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    }
                    .chartLegend(position: .topTrailing)
                    .frame(height: 160)
                }
            }
        }
    }
}

// MARK: - Shared chart components

private var emptyChart: some View {
    ContentUnavailableView("No data yet", systemImage: "chart.bar",
                           description: Text("Log some entries to see trends here."))
        .frame(height: 160)
}

struct InsightCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct InsightStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Avoid overcrowding the x-axis on narrow ranges
private func axisDayStride(_ count: Int) -> Int {
    if count <= 7 { return 1 }
    if count <= 14 { return 2 }
    return 7
}
