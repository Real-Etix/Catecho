# Vendored Zstandard decompressor

Source: [facebook/zstd v1.5.7](https://github.com/facebook/zstd/tree/v1.5.7), commit
`f8745da6ff1ad1e7bab384bd1f9d742439278e99` (annotated tag
`ac66b19e6bd6b83238bf008eecc1298105298532`). Obtained from the official GitHub
[v1.5.7 source archive](https://github.com/facebook/zstd/archive/refs/tags/v1.5.7.tar.gz).
The GitHub tag API was used to resolve the tag to the source commit; no claim of
independent PGP signature verification is made.

We select upstream's BSD 3-Clause license, reproduced in `LICENSE`. `build.sh`
copies that license into the application's Resources as `Zstandard-LICENSE.txt`.
Upstream source and headers retain their copyright and dual-license notices.

`zstddeclib.c` is an unmodified, generated decompression-only amalgamation. The
upstream `combine.py`, `create_single_file_decoder.sh`, and `zstddeclib-in.c` were
inspected before generation. To reproduce from an extracted official archive:

```sh
cd zstd-1.5.7/build/single_file_libs
python3 combine.py -r ../../lib -x legacy/zstd_legacy.h -o zstddeclib.c zstddeclib-in.c
```

Copy the result to this directory; copy `lib/zstd.h`, `lib/zstd_errors.h` to
`include/`, and upstream `LICENSE` here. `include/module.modulemap` is Catecho's
Swift module definition. The complete upstream public headers are retained to
avoid maintaining hand-written copies of the C ABI. Compression functions are
not linked and must not be used.

SHA-256:

| File | Hash |
| --- | --- |
| v1.5.7.tar.gz | `37d7284556b20954e56e1ca85b80226768902e2edabd3b649e9e72c0c9012ee3` |
| zstddeclib.c | `5eb38abe0a7eea13674b312a006df72002d4192f0f0b4d09e6f03fb927a1f3d0` |
| include/zstd.h | `9b4bc8245565c98ccfc61c07749928b57e7c0f6fddb0530c4f6aa1971893d88b` |
| include/zstd_errors.h | `66a8c3f71d12ea6e797e4f622f31f3f8f81c41b36f48cad4f5de7d8bfb6aac0a` |
| LICENSE | `7055266497633c9025b777c78eb7235af13922117480ed5c674677adc381c9d8` |

The decoder is compiled as C99 and linked statically. It has no Homebrew, process,
network, or external zstd dylib dependency. SwiftPM uses a dedicated `CZstd` C
target. The shell toolchain caches the C object by source, header, module map and
toolchain-script hash. The Swift adapter permits windows up to 8 MiB and outputs
at most 256 KiB per call. Destroy a decoder after any malformed-frame error;
upstream does not guarantee the stream state can be reused after an error.
