import SwiftUI
import Charts

struct HeartRateChartView: View {
    let samples: [HeartRateSample]

    private var chartData: [HeartRateSample] {
        // パフォーマンス: 300点以上はダウンサンプリング
        guard samples.count > 300 else { return samples }
        let stride = samples.count / 300
        return samples.enumerated()
            .filter { $0.offset % stride == 0 }
            .map { $0.element }
    }

    private var avgBPM: Double {
        guard !samples.isEmpty else { return 0 }
        return samples.map(\.bpm).reduce(0, +) / Double(samples.count)
    }

    private var yAxisDomain: ClosedRange<Double> {
        let minBPM = samples.map(\.bpm).min() ?? 60
        let maxBPM = samples.map(\.bpm).max() ?? 200
        let padding = (maxBPM - minBPM) * 0.1
        return max(0, minBPM - padding)...(maxBPM + padding)
    }

    var body: some View {
        Chart {
            ForEach(chartData) { sample in
                LineMark(
                    x: .value(String(localized: "時間"), sample.elapsedSeconds / 60),
                    y: .value(String(localized: "心拍数"), sample.bpm)
                )
                .foregroundStyle(Color.red.gradient)
                .interpolationMethod(.catmullRom)
            }

            ForEach(chartData) { sample in
                AreaMark(
                    x: .value(String(localized: "時間"), sample.elapsedSeconds / 60),
                    y: .value(String(localized: "心拍数"), sample.bpm)
                )
                .foregroundStyle(Color.red.opacity(0.1))
                .interpolationMethod(.catmullRom)
            }

            RuleMark(y: .value(String(localized: "平均"), avgBPM))
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .annotation(position: .top, alignment: .trailing) {
                    Text(String(format: String(localized: "Avg %d", comment: "Average heart rate"), Int(avgBPM)))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
        }
        .chartYAxisLabel("bpm")
        .chartXAxisLabel(String(localized: "分"))
        .chartYScale(domain: yAxisDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5))
        }
        .frame(height: 200)
    }
}

#Preview {
    let samples = (0..<60).map { i in
        var sample = HeartRateSample(
            timestamp: Date().addingTimeInterval(Double(i) * 60),
            bpm: Double.random(in: 140...170)
        )
        sample.elapsedSeconds = Double(i) * 60
        return sample
    }

    return HeartRateChartView(samples: samples)
        .padding()
}
