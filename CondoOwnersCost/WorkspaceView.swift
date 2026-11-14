//
//  WorkspaceView.swift
//  CondoOwnersCost
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum WorkspaceRole {
    case standalone
    case agent
}

enum WorkspacePane: String, CaseIterable, Identifiable {
    case results
    case inputs
    case forecast

    var id: String { rawValue }
    var title: String {
        switch self {
        case .results: L10n.t("pane.results")
        case .inputs: L10n.t("pane.inputs")
        case .forecast: L10n.t("pane.forecast")
        }
    }
}

struct WorkspaceView: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(LanguageSettings.self) private var lang
    let propertyID: UUID
    var role: WorkspaceRole = .standalone
    var sharedYear: Binding<Int>? = nil
    @State private var pane: WorkspacePane = ScreenshotLaunch.mode == "condo-results" ? .results : .inputs
    @State private var selectedYear = CalendarYear.current

    private var year: Binding<Int> { sharedYear ?? $selectedYear }
    private var panes: [WorkspacePane] {
        role == .agent ? [.inputs, .forecast] : WorkspacePane.allCases
    }
    @State private var exportingPDF = false
    @State private var exportingJSON = false
    @State private var pdfFile: PDFFile?
    @State private var jsonFile: JSONFile?
    @State private var alertText: String?

    private var property: CondoProperty? { store.property(propertyID) }

    var body: some View {
        Group {
            if let property {
                VStack(spacing: 0) {
                    Picker(lang.t("pane.results"), selection: $pane) {
                        ForEach(panes) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    switch pane {
                    case .results:
                        ResultsPane(propertyID: propertyID, selectedYear: year)
                    case .inputs:
                        ParametersPane(propertyID: propertyID)
                    case .forecast:
                        ForecastPane(propertyID: propertyID, selectedYear: year)
                    }
                }
                .background(Theme.paper)
                .navigationTitle(property.name)
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    if pane != .results, let current = CostEngine.project(property).year(CalendarYear.current) {
                        totalBar(current)
                    }
                }
                .onChange(of: property.inputs.projection.targetYear) { _, target in
                    let upper = max(target, CalendarYear.current)
                    year.wrappedValue = min(max(year.wrappedValue, CalendarYear.current), upper)
                }
            } else {
                ContentUnavailableView(lang.t("missing"), systemImage: "questionmark.folder")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("PDF", systemImage: "doc.richtext") { exportPDF() }
                Menu {
                    Button(lang.t("nav.exportOne")) { exportJSON() }
                    Button(lang.t("nav.delete"), role: .destructive) { store.delete(propertyID) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(lang.t("nav.done")) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .fileExporter(isPresented: $exportingPDF, document: pdfFile, contentType: .pdf, defaultFilename: pdfName) { result in
            if case .failure(let error) = result { alertText = error.localizedDescription }
        }
        .fileExporter(isPresented: $exportingJSON, document: jsonFile, contentType: .json, defaultFilename: jsonName) { result in
            if case .failure(let error) = result { alertText = error.localizedDescription }
        }
        .alert(lang.t("export.fail"), isPresented: Binding(
            get: { alertText != nil },
            set: { if !$0 { alertText = nil } }
        )) {
            Button(lang.t("nav.ok"), role: .cancel) { alertText = nil }
        } message: {
            Text(alertText ?? "")
        }
    }

    private var pdfName: String { L10n.t("pdf.name", property?.name ?? L10n.t("property.new")) }
    private var jsonName: String { L10n.t("json.name", property?.name ?? L10n.t("property.new")) }

    private func totalBar(_ year: YearResult) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("bar.cost", year.year))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Text(Money.precise(year.netAnnual))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            if role == .standalone {
                Button(lang.t("bar.detail")) { pane = .results }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.teal)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func exportPDF() {
        guard let property else { return }
        pdfFile = PDFFile(data: PDFReport.make(
            property: property,
            projection: CostEngine.project(property),
            snapshot: store.document.snapshot
        ))
        exportingPDF = true
    }

    private func exportJSON() {
        do {
            jsonFile = JSONFile(data: try store.exportData(propertyIDs: [propertyID]))
            exportingJSON = true
        } catch {
            alertText = error.localizedDescription
        }
    }
}
