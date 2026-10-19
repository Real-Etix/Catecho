import Foundation

/// Streaming projection for oversized rollout rows. Bodies are structurally consumed,
/// never retained; only the identity, time and numeric fields used by the collector survive.
final class CodexJSONProjection {
    private indirect enum Schema {
        case scalar, presence, object([String: Schema])
        var fields: [String: Schema]? { if case .object(let fields) = self { return fields }; return nil }
    }
    private static let counts: Schema = .object(Dictionary(uniqueKeysWithValues:
        ["input_tokens", "cached_input_tokens", "output_tokens", "reasoning_output_tokens"].map { ($0, .scalar) }))
    private static let record: Schema = .object(["response_id": .scalar, "thread_id": .scalar, "session_id": .scalar, "usage": counts])
    private static let schema: Schema = .object([
        "type": .scalar, "timestamp": .scalar, "payload": .object([
            "id": .scalar, "timestamp": .scalar, "parent_thread_id": .scalar,
            "source": .object(["subagent": .presence]), "type": .scalar,
            "info": .object(["total_token_usage": counts, "last_token_usage": counts]),
            "response_id": .scalar, "thread_id": .scalar, "session_id": .scalar, "usage": counts,
            "compaction_response_id": .scalar, "latest_token_usage_record": record
        ])
    ])
    private enum State { case keyOrEnd, key, colon, value, valueOrEnd, commaOrEnd }
    private struct Frame {
        let array: Bool
        let schema: Schema?
        var state: State
        var key: String?
        var values: [String: Any] = [:]
    }
    private var stack: [Frame] = []
    private var started = false
    private var complete = false
    private var failed = false
    private var result: [String: Any]?
    private var inString = false
    private var inAtom = false
    private var isKey = false
    private var capture = false
    private var escaped = false
    private var unicodeDigits = 0
    private var token = Data()
    private var selectedBytes = 0
    var retainedByteEstimate: Int { selectedBytes + token.count + stack.count * 512 }

    func consume(_ data: Data) {
        guard !failed else { return }
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            var i = 0
            while i < raw.count && !failed {
                let b = raw[i]
                if inString {
                    if unicodeDigits > 0 {
                        guard (48...57).contains(b) || (65...70).contains(b) || (97...102).contains(b) else { failed = true; break }
                        append(raw, i..<(i + 1)); unicodeDigits -= 1; i += 1
                    } else if escaped {
                        guard [34, 92, 47, 98, 102, 110, 114, 116, 117].contains(b) else { failed = true; break }
                        append(raw, i..<(i + 1)); escaped = false; unicodeDigits = b == 117 ? 4 : 0; i += 1
                    } else if b == 92 {
                        append(raw, i..<(i + 1)); escaped = true; i += 1
                    } else if b == 34 {
                        append(raw, i..<(i + 1)); i += 1; inString = false; endToken()
                    } else {
                        let begin = i
                        while i < raw.count && raw[i] >= 32 && raw[i] != 34 && raw[i] != 92 { i += 1 }
                        append(raw, begin..<i)
                        if i < raw.count && raw[i] < 32 { failed = true }
                    }
                    continue
                }
                if inAtom {
                    if Self.delimiter(b) {
                        inAtom = false; endToken(); continue
                    }
                    token.append(b); i += 1
                    if token.count > 128 { failed = true }
                    continue
                }
                if Self.whitespace(b) { i += 1; continue }
                if complete { failed = true; break }
                if stack.isEmpty {
                    guard !started && b == 123 else { failed = true; break }
                    started = true
                    stack.append(Frame(array: false, schema: Self.schema, state: .keyOrEnd)); i += 1; continue
                }
                let index = stack.count - 1
                switch stack[index].state {
                case .keyOrEnd, .key:
                    if b == 125 && stack[index].state == .keyOrEnd { close(); i += 1 }
                    else if b == 34 { startString(key: true); i += 1 }
                    else { failed = true }
                case .colon:
                    if b == 58 { stack[index].state = .value; i += 1 } else { failed = true }
                case .value, .valueOrEnd:
                    if b == 93 && stack[index].array && stack[index].state == .valueOrEnd { close(); i += 1; continue }
                    if b == 123 || b == 91 {
                        let schema = valueSchema
                        if case .scalar = schema { failed = true; break }
                        if b == 91, case .object = schema { failed = true; break }
                        guard stack.count < 128 else { failed = true; break }
                        stack.append(Frame(array: b == 91, schema: schema, state: b == 91 ? .valueOrEnd : .keyOrEnd)); i += 1
                    } else if b == 34 { startString(key: false); i += 1 }
                    else if b == 45 || (48...57).contains(b) || [116, 102, 110].contains(b) {
                        isKey = false; capture = true; token = Data([b]); inAtom = true; i += 1
                    } else { failed = true }
                case .commaOrEnd:
                    if b == (stack[index].array ? 93 : 125) { close(); i += 1 }
                    else if b == 44 { stack[index].state = stack[index].array ? .value : .key; i += 1 }
                    else { failed = true }
                }
            }
        }
    }

    func finish() -> Data? {
        guard !failed, complete, !inString, !inAtom, let result else { return nil }
        return try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
    }
    private static func whitespace(_ byte: UInt8) -> Bool { byte == 32 || byte == 9 || byte == 10 || byte == 13 }
    private static func delimiter(_ byte: UInt8) -> Bool { whitespace(byte) || byte == 44 || byte == 93 || byte == 125 }
    private var valueSchema: Schema? {
        guard let frame = stack.last, !frame.array, let key = frame.key else { return nil }
        return frame.schema?.fields?[key]
    }
    private func startString(key: Bool) {
        isKey = key; inString = true; escaped = false; unicodeDigits = 0
        capture = key ? stack.last?.schema?.fields != nil : valueSchema != nil
        token = capture ? Data([34]) : Data()
    }
    private func append(_ raw: UnsafeRawBufferPointer, _ range: Range<Int>) {
        guard capture, !range.isEmpty else { return }
        guard token.count + range.count <= (isKey ? 256 : 8192) else { failed = true; return }
        token.append(contentsOf: raw[range])
    }
    private func endToken() {
        guard !failed else { return }
        let object: Any?
        if capture {
            guard let decoded = try? JSONSerialization.jsonObject(with: token, options: [.fragmentsAllowed]) else { failed = true; return }
            object = decoded
        } else { object = nil }
        if isKey {
            stack[stack.count - 1].key = object as? String
            stack[stack.count - 1].state = .colon
        } else {
            let schema = valueSchema
            if schema != nil {
                selectedBytes += token.count
                if selectedBytes > 64 * 1024 { failed = true; return }
            }
            if case .presence = schema { store(NSNull()) }
            else { store(schema == nil ? nil : object) }
        }
        token = Data()
    }
    private func close() {
        let frame = stack.removeLast()
        if stack.isEmpty { result = frame.values; complete = true; return }
        if case .presence = frame.schema { store(NSNull()) }
        else { store(frame.schema?.fields == nil ? nil : frame.values) }
    }
    private func store(_ value: Any?) {
        guard !stack.isEmpty else { failed = true; return }
        let index = stack.count - 1
        if let key = stack[index].key, let value {
            guard stack[index].values[key] == nil else { failed = true; return }
            stack[index].values[key] = value
        }
        stack[index].key = nil
        stack[index].state = .commaOrEnd
    }
}
