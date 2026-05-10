import AVFoundation

final class PCMConverter {
    static let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24000,
        channels: 1,
        interleaved: true
    )!

    private let converter: AVAudioConverter

    init(inputFormat: AVAudioFormat) throws {
        guard let conv = AVAudioConverter(from: inputFormat, to: PCMConverter.outputFormat) else {
            throw NSError(domain: "PCMConverter", code: 1)
        }
        self.converter = conv
    }

    /// Converts one input buffer to 24 kHz mono Int16 little-endian PCM bytes.
    func convert(_ input: AVAudioPCMBuffer) throws -> Data {
        let ratio = PCMConverter.outputFormat.sampleRate / input.format.sampleRate
        let outFrames = AVAudioFrameCount(Double(input.frameLength) * ratio + 1024)
        guard let out = AVAudioPCMBuffer(pcmFormat: PCMConverter.outputFormat, frameCapacity: outFrames) else {
            throw NSError(domain: "PCMConverter", code: 2)
        }

        var fed = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, status in
            if fed {
                status.pointee = .endOfStream
                return nil
            }
            fed = true
            status.pointee = .haveData
            return input
        }
        if let error { throw error }
        if status == .error { throw NSError(domain: "PCMConverter", code: 3) }

        let frames = Int(out.frameLength)
        let bytes = frames * MemoryLayout<Int16>.size
        guard let ptr = out.int16ChannelData?[0] else { return Data() }
        return Data(bytes: ptr, count: bytes)
    }
}
