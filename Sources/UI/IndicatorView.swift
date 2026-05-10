import SwiftUI

enum IndicatorState { case listening, finalizing }

struct IndicatorView: View {
    let state: IndicatorState

    var body: some View {
        Group {
            switch state {
            case .listening:
                ListeningBars()
            case .finalizing:
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .clipShape(Capsule())
    }
}

/// A horizontal row of three small bars whose heights pulse in sequence —
/// reads as "listening" / live-mic without a label.
private struct ListeningBars: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.18, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(Color.red)
                    .frame(width: 3, height: barHeight(i))
                    .animation(.easeInOut(duration: 0.18), value: phase)
            }
        }
        .frame(height: 14)
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }

    private func barHeight(_ i: Int) -> CGFloat {
        // Three heights cycle through positions; the "active" bar is tallest.
        let active = (i == phase)
        let near = (i == (phase + 2) % 3)
        if active { return 14 }
        if near { return 9 }
        return 5
    }
}
