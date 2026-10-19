import Foundation

func check(_ ok: @autoclosure () -> Bool, _ label: String) {
    guard ok() else { fatalError("FAIL projection: " + label) }
    print("PASS projection: " + label)
}

func project(_ text: String, chunk: Int = 17) -> [String: Any]? {
    let p = CodexJSONProjection()
    let bytes = Data(text.utf8)
    for start in stride(from: 0, to: bytes.count, by: chunk) { p.consume(bytes.subdata(in: start..<min(start + chunk, bytes.count))) }
    guard let data = p.finish() else { return nil }
    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
}

@main struct ProjectionTests {
    static func main() {
        let body = String(repeating: "ignored 🐈 ", count: 800_000)
        let object: [String: Any] = ["type": "compacted", "timestamp": "2026-10-19T00:00:00Z", "payload": ["a_body": body, "latest_token_usage_record": ["response_id": "r\\\"🐈", "thread_id": "t", "usage": ["input_tokens": 123, "output_tokens": 7, "cached_input_tokens": 2, "reasoning_output_tokens": 3]], "replacement_history": [["type": "token_usage_record", "payload": ["usage": ["input_tokens": 99999]]]]]]
        let text = String(data: try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), encoding: .utf8)!
        let projected = project(text, chunk: 256 * 1024)!
        let payload = projected["payload"] as! [String: Any]
        let record = payload["latest_token_usage_record"] as! [String: Any]
        check((record["usage"] as! [String: Any])["input_tokens"] as? Int == 123 && record["response_id"] as? String == "r\\\"🐈", "retains usage after a huge body and decodes escaped Unicode identities")
        check(payload["a_body"] == nil && payload["replacement_history"] == nil, "drops bodies and nested copied usage")
        check(project("{\"payload\":{\"source\":{\"subagent\":{\"anything\":[1,2]}},\"id\":\"s\"},\"type\":\"session_meta\"}", chunk: 1) != nil, "handles every byte boundary and subagent presence")
        for bad in ["{", "{\"type\":\"x\",}", "{\"type\":\"x\"}junk", "{\"unused\":[1,]}", "{\"unused\":\"bad\\q\"}", "{\"unused\":01}", "{\"type\":\"x\",\"type\":\"y\"}"] {
            check(project(bad) == nil, "rejects malformed or ambiguous JSON")
        }
        check(project("{\"unused\":\"\\\"usage\\\":{\\\"input_tokens\\\":999}\",\"type\":\"response_item\"}")?["type"] as? String == "response_item", "usage-looking text cannot become token counts")
        check(project("{\"type\":\"token_usage_record\",\"payload\":{\"response_id\":\"" + String(repeating: "x", count: 9000) + "\"}}") == nil, "bounds selected scalar storage")
        check(project("{\"unused\":" + String(repeating: "[", count: 150) + "0" + String(repeating: "]", count: 150) + "}") == nil, "bounds structural depth")
    }
}
