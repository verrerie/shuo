import SwiftUI

enum IndicatorState { case listening, finalizing }

struct IndicatorView: View {
    @State private var pulse = false
    let state: IndicatorState

    var body: some View {
        ZStack {
            switch state {
            case .listening:
                Circle()
                    .fill(Color.red)
                    .frame(width: 14, height: 14)
                    .opacity(pulse ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
            case .finalizing:
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(6)
        .background(Color.black.opacity(0.55))
        .clipShape(Capsule())
    }
}
