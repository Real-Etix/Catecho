import Foundation
import CZstd

struct CodexZstdChunk {
    let output: Data
    let consumed: Int
    let frameComplete: Bool
}

/// An actor-owned streaming decoder. The caller retains unconsumed input and
/// treats EOF without `frameComplete` as truncation; empty input may drain output.
final class CodexZstd {
    private let context: OpaquePointer

    init() throws {
        guard let context = ZSTD_createDStream() else { throw CodexZstdError.allocation }
        let result = ZSTD_DCtx_setParameter(context, ZSTD_d_windowLogMax, 23)
        guard ZSTD_isError(result) == 0 else {
            ZSTD_freeDStream(context)
            throw CodexZstdError.configuration
        }
        self.context = context
    }

    deinit { ZSTD_freeDStream(context) }

    func decode(_ input: Data, outputLimit: Int) throws -> CodexZstdChunk {
        guard (1...(256 * 1024)).contains(outputLimit) else { throw CodexZstdError.outputLimit }
        var output = Data(count: outputLimit)
        var consumed = 0
        var produced = 0
        let result: Int = input.withUnsafeBytes { source in
            output.withUnsafeMutableBytes { destination in
                var inputBuffer = ZSTD_inBuffer(src: source.baseAddress, size: source.count, pos: 0)
                var outputBuffer = ZSTD_outBuffer(dst: destination.baseAddress, size: destination.count, pos: 0)
                let result = ZSTD_decompressStream(context, &outputBuffer, &inputBuffer)
                consumed = inputBuffer.pos
                produced = outputBuffer.pos
                return result
            }
        }
        if ZSTD_isError(result) != 0 {
            if ZSTD_getErrorCode(result) == ZSTD_error_frameParameter_windowTooLarge {
                throw CodexZstdError.windowLimit
            }
            throw CodexZstdError.invalidFrame
        }
        output.count = produced
        return CodexZstdChunk(output: output, consumed: consumed, frameComplete: result == 0)
    }
}

private enum CodexZstdError: LocalizedError {
    case allocation, configuration, outputLimit, windowLimit, invalidFrame

    var errorDescription: String? {
        switch self {
        case .allocation: return "Unable to allocate the history decoder."
        case .configuration: return "Unable to configure the history decoder."
        case .outputLimit: return "History decoder output limit must be between 1 byte and 256 KiB."
        case .windowLimit: return "Compressed history requires a window larger than 8 MiB."
        case .invalidFrame: return "Compressed history contains an invalid or unsupported Zstandard frame."
        }
    }
}
