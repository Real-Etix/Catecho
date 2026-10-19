# Numeric streaming fixtures

Generated with the official Zstandard CLI v1.5.7 for tests only. No private logs or
user text were used. Plaintext consists exclusively of ASCII digits and newlines.
Fixtures do not require a compressor at test time.

Reproduce using Python 3 and `zstd` v1.5.7:

```python
import pathlib, subprocess
root = pathlib.Path("Tests/CodexZstd/Fixtures")
for name, data in {
    "numeric": b"0123456789\n" * 600,
    "second": b"9876543210\n" * 17,
}.items():
    (root / (name + ".zst")).write_bytes(subprocess.run(
        ["zstd", "-q", "-f", "-3", "--check", "--no-content-size", "-c"],
        input=data, stdout=subprocess.PIPE, check=True).stdout)
(root / "window-16m.zst").write_bytes(subprocess.run(
    ["zstd", "-q", "-f", "-3", "--long=24", "--check", "--no-content-size", "-c"],
    input=b"123", stdout=subprocess.PIPE, check=True).stdout)
```

SHA-256:

- numeric.zst: `97e8041a4502a633a27ed6f222f6a1a62cf2c93e22f67b30aab090438e179f2c`
- second.zst: `504bae5422fd2e9283aad89437112eff41a89bd488a09d6bef89c678df9d5c60`
- window-16m.zst: `ad0ce4155e1a760643e722afa2b71ac05cff56a35054811f64f6b627044b0372`
