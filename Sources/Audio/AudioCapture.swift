import AVFoundation
import AVFAudio

final class AudioCapture {
    /// AVAudioEngine doesn't always survive a stop → start cycle cleanly
    /// (an installTap on the second start can crash inside CoreAudio). Build
    /// a fresh engine for each capture turn.
    private var engine: AVAudioEngine?
    private var converter: PCMConverter?
    var onChunk: ((Data) -> Void)?
    var onError: ((Error) -> Void)?

    func start() throws {
        // Tear down anything left over before building a fresh engine.
        stop()

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        converter = try PCMConverter(inputFormat: format)

        input.installTap(onBus: 0, bufferSize: 4800, format: format) { [weak self] buffer, _ in
            guard let self, let conv = self.converter else { return }
            do {
                let data = try conv.convert(buffer)
                self.onChunk?(data)
            } catch {
                self.onError?(error)
            }
        }

        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    func stop() {
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        engine = nil
        converter = nil
    }

    static func authorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    static func requestAuthorization() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }
}
