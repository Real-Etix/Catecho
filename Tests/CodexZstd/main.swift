import Foundation

private struct TestFailure: Error { let message: String }

@main struct ZstdTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw TestFailure(message: message) }
    }

    static func main() {
        do { try run() }
        catch let failure as TestFailure { print("FAIL \(failure.message)"); exit(1) }
        catch { print("FAIL unexpected decoder error"); exit(1) }
    }

    static func run() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        func fixture(_ name: String) throws -> Data { try Data(contentsOf: directory.appendingPathComponent(name + ".zst")) }
        let numeric = try fixture("numeric")
        let expected = Data(String(repeating: "0123456789\n", count: 600).utf8)
        let second = try fixture("second")
        let expectedSecond = Data(String(repeating: "9876543210\n", count: 17).utf8)
        let decoder = try CodexZstd()
        let decoded = try decoder.decode(numeric, outputLimit: 256 * 1024)
        try require(decoded.output == expected, "numeric frame output")
        try require(decoded.consumed == numeric.count && decoded.frameComplete, "exact input accounting and frame completion")
        print("PASS numeric frame with exact consumed count")

        for inputLimit in [1, 2, 7, numeric.count] {
            for outputLimit in [1, 7, 256 * 1024] {
                let stream = try CodexZstd()
                var offset = 0
                var output = Data()
                var complete = false
                var drainOutput = 0
                for _ in 0..<20_000 {
                    let end = min(numeric.count, offset + inputLimit)
                    let chunk = try stream.decode(numeric.subdata(in: offset..<end), outputLimit: outputLimit)
                    try require((0...(end - offset)).contains(chunk.consumed), "consumption stays within provided input")
                    try require(chunk.output.count <= outputLimit, "output obeys caller budget")
                    offset += chunk.consumed
                    output.append(chunk.output)
                    complete = chunk.frameComplete
                    if complete { break }
                    if chunk.output.count == outputLimit {
                        let drain = try stream.decode(Data(), outputLimit: outputLimit)
                        try require(drain.consumed == 0 && drain.output.count <= outputLimit, "empty drain accounting")
                        output.append(drain.output)
                        drainOutput += drain.output.count
                        complete = drain.frameComplete
                        if complete { break }
                    }
                }
                try require(complete && offset == numeric.count && output == expected, "tiny input/output streaming reaches exact frame boundary")
                if outputLimit == 1 { try require(drainOutput > 0, "empty input drains buffered output") }
            }
        }
        print("PASS tiny input, tiny output and empty input drains")

        let joined = numeric + second
        let concatenated = try CodexZstd()
        let firstChunk = try concatenated.decode(joined, outputLimit: 256 * 1024)
        try require(firstChunk.frameComplete && firstChunk.consumed == numeric.count && firstChunk.output == expected, "stop exactly at first concatenated frame")
        let nextChunk = try concatenated.decode(joined.subdata(in: firstChunk.consumed..<joined.count), outputLimit: 256 * 1024)
        try require(nextChunk.frameComplete && nextChunk.consumed == second.count && nextChunk.output == expectedSecond, "reuse decoder for next concatenated frame")
        print("PASS concatenated frames preserve exact frame boundaries")

        let truncated = try CodexZstd()
        let partial = try truncated.decode(numeric.dropLast(), outputLimit: 256 * 1024)
        let endOfInput = try truncated.decode(Data(), outputLimit: 256 * 1024)
        try require(partial.consumed == numeric.count - 1 && !partial.frameComplete && !endOfInput.frameComplete, "caller can identify truncated EOF")
        print("PASS truncation remains incomplete at EOF")

        func rejects(_ input: Data, matching text: String? = nil) throws {
            var rejected = false
            do { _ = try CodexZstd().decode(input, outputLimit: 256 * 1024) }
            catch {
                rejected = true
                if let text { try require(error.localizedDescription.contains(text), "sanitized error category") }
                try require(!error.localizedDescription.contains("0123456789"), "error excludes content")
            }
            try require(rejected, "invalid frame must throw")
        }
        var corrupt = numeric
        corrupt[corrupt.count - 1] ^= 0xff
        try rejects(corrupt)
        try rejects(Data([0, 1, 2, 3, 4, 5, 6, 7]))
        try rejects(try fixture("window-16m"), matching: "8 MiB")
        print("PASS corrupt frame and oversized window produce sanitized errors")

        for limit in [-1, 0, 256 * 1024 + 1, Int.max] {
            var rejected = false
            do { _ = try CodexZstd().decode(numeric, outputLimit: limit) }
            catch { rejected = true }
            try require(rejected, "invalid output limit rejected before allocating")
        }
        print("PASS output budget bounds")
    }
}
