import Foundation
import TensorFlowLite  // TensorFlowLiteSwift pod / LiteRT Swift Interpreter.
import Shared  // KMP framework — re-exports the shield `AudioClassifier` protocol.

/// YAMNet (TFLite / LiteRT `Interpreter`) — the iOS `AudioClassifier` seam impl. 1:1 port of
/// `AndroidAudioClassifier`: 15600-sample (975 ms @ 16 kHz) ring buffer; once filled, runs
/// inference over the AudioSet-521 output → top-K (display name, confidence), read oldest-first.
///
/// ⚠️ ON-DEVICE VERIFICATION REQUIRED (authored without a full-Xcode build):
///  - The `AudioClassifier` protocol signature (KotlinShortArray / [KotlinPair<NSString,KotlinDouble>])
///    must match the generated `Shared-Swift.h` — confirm after the first XCFramework build.
///  - TFLite Swift `Interpreter` API is from the official LiteRT iOS quickstart; confirm labels
///    (index-aligned 521 lines) load from the resolved labelsPath.
final class YamnetAudioClassifier: NSObject, AudioClassifier {

    private var interpreter: Interpreter?
    private var labels: [String] = []

    private var ring = [Float](repeating: 0, count: Self.inputSize)
    private var ringPos = 0
    private var ringFilled = false

    func loadModel(modelPath: String, labelsPath: String) -> Bool {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            NSLog("Kavach:YAMNet model not found: \(modelPath)")
            return false
        }
        do {
            let interp = try Interpreter(modelPath: modelPath)
            try interp.allocateTensors()
            self.interpreter = interp
            loadLabels(labelsPath)
            // Empty labels ⇒ className() yields "Class_<i>" not AudioSet names ⇒ name-based SoS
            // matching never fires (detection silently dead) while reporting ready. Fail loudly (#10).
            guard !labels.isEmpty else {
                NSLog("Kavach:YAMNet labels missing/empty: \(labelsPath)")
                self.interpreter = nil
                return false
            }
            return true
        } catch {
            NSLog("Kavach:YAMNet load failed: \(error)")
            return false
        }
    }

    // AudioSet-521 display names, index-aligned with the model output. Blanks are NOT filtered —
    // index alignment must be preserved (else class names mislabel).
    private func loadLabels(_ labelsPath: String) {
        guard !labelsPath.isEmpty, let text = try? String(contentsOfFile: labelsPath, encoding: .utf8) else {
            labels = []
            return
        }
        // Preserve every line (incl. trailing) for index alignment; drop only a final empty newline.
        var lines = text.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        labels = lines
    }

    func topKForFrame(samples: KotlinShortArray, count: Int32, k: Int32) -> [KotlinPair<NSString, KotlinDouble>] {
        let n = Int(count)
        for i in 0..<n {
            ring[ringPos] = Float(samples.get(index: Int32(i))) / Float(Int16.max)
            ringPos += 1
            if ringPos >= Self.inputSize {
                ringPos = 0
                ringFilled = true
            }
        }
        return ringFilled ? runTopK(Int(k)) : []
    }

    private func runTopK(_ k: Int) -> [KotlinPair<NSString, KotlinDouble>] {
        guard let interp = interpreter else { return [] }
        let safeK = min(max(k, 1), Self.classCount)
        do {
            // Read the ring buffer oldest-first: [ringPos..end, 0..ringPos).
            var input = [Float](repeating: 0, count: Self.inputSize)
            let start = ringPos
            for i in 0..<Self.inputSize { input[i] = ring[(start + i) % Self.inputSize] }
            let inputData = input.withUnsafeBytes { Data($0) }

            try interp.copy(inputData, toInputAt: 0)
            try interp.invoke()
            let outputTensor = try interp.output(at: 0)
            let scores: [Float] = outputTensor.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }

            return scores.enumerated()
                .sorted { $0.element > $1.element }
                .prefix(safeK)
                .map { KotlinPair(first: className(for: $0.offset) as NSString,
                                  second: KotlinDouble(value: Double($0.element))) }
        } catch {
            NSLog("Kavach:YAMNet inference error: \(error)")
            return []
        }
    }

    private func className(for index: Int) -> String {
        (index >= 0 && index < labels.count) ? labels[index] : "Class_\(index)"
    }

    func reset() {
        ringPos = 0
        ringFilled = false
    }

    private static let inputSize = 15600 // 975 ms at 16 kHz
    private static let classCount = 521  // AudioSet ontology
}
