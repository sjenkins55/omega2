import SwiftUI
import SwiftData
import Charts

struct GrowthView: View {

    let baby: Baby

    @Environment(\.modelContext) private var modelContext
    @State private var measurementType: MeasurementType = .weight
    @State private var showAddMeasurement = false
    @State private var selectedPoint: Measurement? = nil

    @Query private var allMeasurements: [Measurement]

    private var measurements: [Measurement] {
        allMeasurements
            .filter { $0.babyID == baby.id && $0.type == measurementType }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var weightTable: [WHOPercentileTable.AgePoint] {
        baby.sex == .female ? WHOPercentileTable.weightGirls : WHOPercentileTable.weightBoys
    }
    private var lengthTable: [WHOPercentileTable.AgePoint] {
        baby.sex == .female ? WHOPercentileTable.lengthGirls : WHOPercentileTable.lengthBoys
    }

    var body: some View {
        List {
            Section {
                typePicker
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init())
            }

            // Chart card
            Section {
                percentileChart
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init())
            }

            // Measurements list
            Section("Measurements") {
                if measurements.isEmpty {
                    ContentUnavailableView(
                        "No \(measurementType.rawValue) measurements",
                        systemImage: "ruler",
                        description: Text("Tap + to add your first measurement.")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(measurements.reversed()) { m in
                        MeasurementRow(measurement: m, baby: baby,
                                       table: measurementType == .weight ? weightTable : lengthTable)
                    }
                    .onDelete { offsets in
                        deleteMeasurements(at: offsets)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Growth")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddMeasurement = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddMeasurement) {
            AddMeasurementSheet(baby: baby, defaultType: measurementType)
        }
    }

    // MARK: - Type picker

    private var typePicker: some View {
        Picker("Type", selection: $measurementType) {
            ForEach([MeasurementType.weight, .height, .headCircumference], id: \.self) {
                Text($0.shortLabel).tag($0)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Percentile chart

    private var percentileChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(measurementType.rawValue + " Chart")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("WHO " + (baby.sex == .male ? "Boys" : baby.sex == .female ? "Girls" : ""))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            let table = measurementType == .weight ? weightTable : lengthTable
            let maxAge = 24.0

            Chart {
                // Percentile bands — shaded areas
                ForEach(percentileBands(table: table, maxAge: maxAge), id: \.label) { band in
                    ForEach(band.points, id: \.age) { pt in
                        LineMark(
                            x: .value("Age (mo)", pt.age),
                            y: .value(measurementType.unit, pt.value),
                            series: .value("Percentile", band.label)
                        )
                        .foregroundStyle(band.color)
                        .lineStyle(StrokeStyle(lineWidth: band.label == "P50" ? 1.5 : 1, dash: band.label == "P50" ? [] : [4, 3]))
                    }
                }

                // Actual measurements
                ForEach(measurements) { m in
                    let age = ageMonths(at: m.timestamp)
                    let value = normalizedValue(m)
                    PointMark(
                        x: .value("Age (mo)", age),
                        y: .value(measurementType.unit, value)
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(60)

                    LineMark(
                        x: .value("Age (mo)", age),
                        y: .value(measurementType.unit, value),
                        series: .value("Baby", "Baby")
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartXScale(domain: 0...maxAge)
            .chartXAxis {
                AxisMarks(values: [0, 3, 6, 9, 12, 15, 18, 21, 24]) {
                    AxisValueLabel()
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartLegend(position: .bottomTrailing, spacing: 4) {
                HStack(spacing: 10) {
                    ForEach(["P3", "P50", "P97"], id: \.self) { label in
                        HStack(spacing: 4) {
                            Rectangle().fill(bandColor(label)).frame(width: 16, height: 2)
                            Text(label).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                        Text("Baby").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 220)

            // Latest percentile callout
            if let latest = measurements.last {
                let age = ageMonths(at: latest.timestamp)
                let value = normalizedValue(latest)
                let pct = WHOPercentileTable.computePercentile(
                    value: value, ageMonths: age,
                    table: measurementType == .weight ? weightTable : lengthTable
                )
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Latest: \(formattedValue(latest))")
                            .font(.subheadline.weight(.semibold))
                        Text("at \(Int(age)) months")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f", pct) + "th percentile")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(percentileColor(pct))
                        Text("WHO \(baby.sex == .female ? "Girls" : "Boys")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Chart helpers

    private struct PercentileBand {
        let label: String
        let color: Color
        let points: [(age: Double, value: Double)]
    }

    private func percentileBands(table: [WHOPercentileTable.AgePoint], maxAge: Double) -> [PercentileBand] {
        let ages = stride(from: 0.0, through: maxAge, by: 0.5).map { $0 }
        return [
            PercentileBand(label: "P3",  color: bandColor("P3"),  points: ages.map { ($0, WHOPercentileTable.interpolate(table: table, ageMonths: $0, percentile: \.p3)) }),
            PercentileBand(label: "P15", color: bandColor("P15"), points: ages.map { ($0, WHOPercentileTable.interpolate(table: table, ageMonths: $0, percentile: \.p15)) }),
            PercentileBand(label: "P50", color: bandColor("P50"), points: ages.map { ($0, WHOPercentileTable.interpolate(table: table, ageMonths: $0, percentile: \.p50)) }),
            PercentileBand(label: "P85", color: bandColor("P85"), points: ages.map { ($0, WHOPercentileTable.interpolate(table: table, ageMonths: $0, percentile: \.p85)) }),
            PercentileBand(label: "P97", color: bandColor("P97"), points: ages.map { ($0, WHOPercentileTable.interpolate(table: table, ageMonths: $0, percentile: \.p97)) }),
        ]
    }

    private func bandColor(_ label: String) -> Color {
        switch label {
        case "P3", "P97":  return .gray.opacity(0.5)
        case "P15","P85":  return .gray.opacity(0.35)
        case "P50":        return .gray.opacity(0.7)
        default:           return .gray.opacity(0.3)
        }
    }

    private func ageMonths(at date: Date) -> Double {
        let ref = baby.dueDate ?? baby.dateOfBirth
        return max(0, date.timeIntervalSince(ref) / (30.44 * 86400))
    }

    private func normalizedValue(_ m: Measurement) -> Double {
        // Convert to kg or cm for chart
        switch m.unit {
        case .lbs:    return m.value * 0.453592
        case .inches: return m.value * 2.54
        default:      return m.value
        }
    }

    private func formattedValue(_ m: Measurement) -> String {
        switch m.type {
        case .weight:
            if m.unit == .lbs { return String(format: "%.1f lbs", m.value) }
            return String(format: "%.2f kg", m.value)
        case .height:
            if m.unit == .inches { return String(format: "%.1f in", m.value) }
            return String(format: "%.1f cm", m.value)
        case .headCircumference:
            return String(format: "%.1f cm", m.value)
        }
    }

    private func percentileColor(_ pct: Double) -> Color {
        if pct < 3 || pct > 97 { return .red }
        if pct < 10 || pct > 90 { return .orange }
        return .green
    }

    private func deleteMeasurements(at offsets: IndexSet) {
        let reversed = Array(measurements.reversed())
        for i in offsets {
            modelContext.delete(reversed[i])
        }
        try? modelContext.save()
    }
}

// MARK: - Measurement Row

struct MeasurementRow: View {
    let measurement: Measurement
    let baby: Baby
    let table: [WHOPercentileTable.AgePoint]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(valueLabel)
                    .font(.subheadline.weight(.semibold))
                Text(measurement.timestamp, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(percentileLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(percentileColor)
                Text("percentile")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ageMonthsAtEntry: Double {
        let ref = baby.dueDate ?? baby.dateOfBirth
        return max(0, measurement.timestamp.timeIntervalSince(ref) / (30.44 * 86400))
    }

    private var normalizedKgOrCm: Double {
        switch measurement.unit {
        case .lbs:    return measurement.value * 0.453592
        case .inches: return measurement.value * 2.54
        default:      return measurement.value
        }
    }

    private var percentile: Double {
        WHOPercentileTable.computePercentile(value: normalizedKgOrCm, ageMonths: ageMonthsAtEntry, table: table)
    }

    private var percentileLabel: String { String(format: "%.0f", percentile) + "th" }

    private var percentileColor: Color {
        if percentile < 3 || percentile > 97 { return .red }
        if percentile < 10 || percentile > 90 { return .orange }
        return .green
    }

    private var valueLabel: String {
        switch measurement.type {
        case .weight:
            if measurement.unit == .lbs { return String(format: "%.1f lbs", measurement.value) }
            return String(format: "%.2f kg", measurement.value)
        case .height:
            if measurement.unit == .inches { return String(format: "%.1f in", measurement.value) }
            return String(format: "%.1f cm", measurement.value)
        case .headCircumference:
            return String(format: "%.1f cm", measurement.value)
        }
    }
}

// MARK: - Add Measurement Sheet

struct AddMeasurementSheet: View {

    let baby: Baby
    let defaultType: MeasurementType

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var type: MeasurementType
    @State private var value: Double = 0
    @State private var useMetric = true
    @State private var date = Date()
    @State private var notes = ""

    init(baby: Baby, defaultType: MeasurementType) {
        self.baby = baby
        self.defaultType = defaultType
        _type = State(initialValue: defaultType)
    }

    private var unit: MeasurementUnit {
        switch type {
        case .weight: return useMetric ? .kg : .lbs
        case .height, .headCircumference: return useMetric ? .cm : .inches
        }
    }

    private var unitLabel: String {
        switch unit { case .kg: "kg"; case .lbs: "lbs"; case .cm: "cm"; case .inches: "in" }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $type) {
                        Text("Weight").tag(MeasurementType.weight)
                        Text("Height/Length").tag(MeasurementType.height)
                        Text("Head Circ.").tag(MeasurementType.headCircumference)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Value") {
                    HStack {
                        TextField("0.0", value: $value, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                        Text(unitLabel)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Toggle("Metric", isOn: $useMetric)
                            .labelsHidden()
                        Text(useMetric ? "Metric" : "Imperial")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Date") {
                    DatePicker("Measured on", selection: $date, displayedComponents: [.date])
                }
                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("Add Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(value <= 0)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        let m = Measurement(babyID: baby.id, caregiverID: UUID(), type: type, value: value, unit: unit)
        m.timestamp = date
        m.notes = notes.isEmpty ? nil : notes
        modelContext.insert(m)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - MeasurementType helper

extension MeasurementType {
    var shortLabel: String {
        switch self { case .weight: "Weight"; case .height: "Height"; case .headCircumference: "Head" }
    }
    var unit: String {
        switch self { case .weight: "kg"; case .height: "cm"; case .headCircumference: "cm" }
    }
}
