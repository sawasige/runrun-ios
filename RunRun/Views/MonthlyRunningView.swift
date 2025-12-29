import SwiftUI
import Charts

struct MonthlyRunningView: View {
    @StateObject private var viewModel = MonthlyRunningViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                yearPickerSection

                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error: error)
                } else {
                    statsListView
                }
            }
            .navigationTitle("ランニング記録")
            .task {
                await viewModel.onAppear()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .onChange(of: viewModel.selectedYear) {
                Task {
                    await viewModel.loadMonthlyStats()
                }
            }
        }
    }

    private var yearPickerSection: some View {
        VStack(spacing: 12) {
            Picker("年", selection: $viewModel.selectedYear) {
                ForEach(viewModel.availableYears, id: \.self) { year in
                    Text(verbatim: "\(year)年").tag(year)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            HStack {
                Text("年間合計")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.formattedTotalYearlyDistance)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()
        }
        .padding(.top)
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("読み込み中...")
                .foregroundStyle(.secondary)
                .padding(.top)
            Spacer()
        }
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("再読み込み") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    private var statsListView: some View {
        List {
            Section {
                monthlyChart
                    .frame(height: 200)
            }

            Section {
                ForEach(viewModel.monthlyStats.reversed()) { stats in
                    NavigationLink {
                        MonthDetailView(year: stats.year, month: stats.month)
                    } label: {
                        MonthlyStatsRow(stats: stats)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var monthlyChart: some View {
        Chart(viewModel.monthlyStats) { stats in
            BarMark(
                x: .value("月", "\(stats.month)月"),
                y: .value("距離", stats.totalDistanceInKilometers)
            )
            .foregroundStyle(.blue.gradient)
        }
        .chartYAxisLabel("km")
    }
}

struct MonthlyStatsRow: View {
    let stats: MonthlyRunningStats

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stats.formattedMonth)
                    .font(.headline)
                Text("\(stats.runCount)回")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(stats.formattedTotalDistance)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(stats.totalDistanceInKilometers > 0 ? .primary : .secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MonthlyRunningView()
}
