import Foundation
// ORT Objective-C API is exposed via Runner-Bridging-Header.h (#import <onnxruntime.h>).
// If the pod/SPM module is imported instead, replace the bridging import with `import onnxruntime`.
import Shared  // KMP framework — re-exports the shield `VoiceDetector` protocol.

/// Silero VAD (ONNX Runtime) — the iOS `VoiceDetector` seam impl. 1:1 port of
/// `AndroidVoiceDetector`: fixed 512-sample chunks with a 64-sample carried context → [1, 576]
/// input (64 context + 512 new), stateful [2,1,128] hidden state threaded across calls.
///
/// ⚠️ ON-DEVICE VERIFICATION REQUIRED (authored without a full-Xcode build):
///  - The `VoiceDetector` protocol signature (KotlinShortArray / Int32) must match the generated
///    `Shared-Swift.h` — confirm the exact spelling after the first XCFramework build.
///  - ORT ObjC method names/labels (ORTValue init, run(withInputs:...)) are from official docs;
///    confirm against the linked onnxruntime-objc version.
///  - Model I/O names verified from silero_vad.onnx: inputs `input`/`state`/`sr`, outputs
///    `output`/`stateN`. sr passed as shape [1] int64 (mirrors the Android LongArray(1)).
final class SileroVoiceDetector: NSObject, VoiceDetector {

    private var env: ORTEnv?
    private var session: ORTSession?

    private var vadState = [Float](repeating: 0, count: 2 * 1 * 128) // 2 layers × 1 batch × 128 hidden
    private var vadChunk = [Float](repeating: 0, count: Self.chunkSize)
    private var vadChunkPos = 0
    private var vadContext = [Float](repeating: 0, count: Self.contextSize) // 64-sample carryover
    private var latestConfidence = 0.0

    func loadModel(modelPath: String) -> Bool {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            NSLog("Kavach:VAD model not found: \(modelPath)")
            return false
        }
        do {
            let env = try ORTEnv(loggingLevel: ORTLoggingLevel.warning)
            self.env = env
            self.session = try ORTSession(env: env, modelPath: modelPath, sessionOptions: nil)
            return true
        } catch {
            NSLog("Kavach:VAD load failed: \(error)")
            return false
        }
    }

    func confidenceForFrame(samples: KotlinShortArray, count: Int32) -> Double {
        let n = Int(count)
        for i in 0..<n {
            vadChunk[vadChunkPos] = Float(samples.get(index: Int32(i))) / Float(Int16.max)
            vadChunkPos += 1
            if vadChunkPos >= Self.chunkSize {
                latestConfidence = runVadWithContext(vadChunk)
                // Carry the last 64 samples as context for the next chunk.
                vadContext = Array(vadChunk[(Self.chunkSize - Self.contextSize)..<Self.chunkSize])
                vadChunkPos = 0
            }
        }
        return latestConfidence
    }

    private func runVadWithContext(_ chunk: [Float]) -> Double {
        guard let session = session else { return 0.0 }
        do {
            var fullInput = [Float](repeating: 0, count: Self.inputSize)
            for i in 0..<Self.contextSize { fullInput[i] = vadContext[i] }
            for i in 0..<Self.chunkSize { fullInput[Self.contextSize + i] = chunk[i] }

            let inputTensor = try ortFloatTensor(fullInput, shape: [1, NSNumber(value: Self.inputSize)])
            var sr: [Int64] = [16000]
            let srTensor = try ORTValue(
                tensorData: NSMutableData(bytes: &sr, length: MemoryLayout<Int64>.size),
                elementType: ORTTensorElementDataType.int64,
                shape: [1])
            let stateTensor = try ortFloatTensor(vadState, shape: [2, 1, 128])

            let outputs = try session.run(
                withInputs: ["input": inputTensor, "sr": srTensor, "state": stateTensor],
                outputNames: ["output", "stateN"],
                runOptions: nil)

            guard let out = outputs["output"], let newState = outputs["stateN"] else { return 0.0 }
            let confidence = try firstFloat(out)
            vadState = try floats(newState, count: vadState.count) // update hidden state for next call
            return Double(confidence)
        } catch {
            NSLog("Kavach:VAD inference error: \(error)")
            return 0.0
        }
    }

    func reset() {
        for i in vadState.indices { vadState[i] = 0 }
        for i in vadContext.indices { vadContext[i] = 0 }
        vadChunkPos = 0
        latestConfidence = 0.0
    }

    // MARK: - ORT helpers

    private func ortFloatTensor(_ values: [Float], shape: [NSNumber]) throws -> ORTValue {
        let data = values.withUnsafeBytes { NSMutableData(bytes: $0.baseAddress, length: $0.count) }
        return try ORTValue(tensorData: data, elementType: ORTTensorElementDataType.float, shape: shape)
    }

    private func firstFloat(_ value: ORTValue) throws -> Float {
        let data = try value.tensorData() as Data
        return data.withUnsafeBytes { $0.load(as: Float.self) }
    }

    private func floats(_ value: ORTValue, count: Int) throws -> [Float] {
        let data = try value.tensorData() as Data
        return data.withUnsafeBytes { raw in
            let ptr = raw.bindMemory(to: Float.self)
            return (0..<count).map { ptr[$0] }
        }
    }

    private static let contextSize = 64  // Silero v5/v6: context from previous chunk
    private static let chunkSize = 512   // Silero v5/v6: new audio samples per inference
    private static let inputSize = 576   // 64 context + 512 new
}
