import XCTest
import AVFoundation
@testable import Shuo

final class PCMConverterTests: XCTestCase {

    func test_converts_44100_float_to_24000_int16_mono() throws {
        let inputFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let frameCount: AVAudioFrameCount = 4410
        let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        if let ch = buffer.floatChannelData {
            for c in 0..<Int(inputFormat.channelCount) {
                for i in 0..<Int(frameCount) {
                    ch[c][i] = sinf(Float(i) * 0.05) * 0.1
                }
            }
        }

        let converter = try PCMConverter(inputFormat: inputFormat)
        let output = try converter.convert(buffer)

        // 100 ms at 24 kHz mono Int16 = 2400 samples = 4800 bytes
        XCTAssertGreaterThanOrEqual(output.count, 4600)
        XCTAssertLessThanOrEqual(output.count, 5000)
    }
}
