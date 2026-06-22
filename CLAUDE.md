# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This is the **aymara fork** of Facebook's [fastText](https://fasttext.cc/) (a C++ library + CLI for word representation learning and text classification, with Python bindings). The fork's distinguishing feature is the ability to **read training/test input directly from compressed archives** (`.xz`/LZMA and `.gz`/gzip) using Boost.Iostreams. Most divergence from upstream lives on the `read_from_xz` branch.

## Building

**CMake** is the only build system: `mkdir build && cd build && cmake .. && make`. It builds shared, static, and PIC libraries plus the CLI. Requires CMake ≥ 3.22 and C++11. The `-march=native` flag is on by default.

(The upstream Makefile, CircleCI config, and the Emscripten/WebAssembly build were removed when this fork dropped upstream compatibility — see commit history.)

### The READ_FROM_XZ option (fork-specific)
CMake exposes `option(READ_FROM_XZ ... ON)`. When ON (default), the build does `find_package(Boost 1.46 REQUIRED COMPONENTS iostreams)` and links `Boost::iostreams`. Turn it OFF (`cmake -DREAD_FROM_XZ=OFF ..`) to build without the Boost dependency. **Boost iostreams (with liblzma/zlib) is a hard build dependency unless this option is disabled.** On Debian/Ubuntu: `apt install libboost-all-dev`.

### Python bindings
`pip install .` from the repo root (uses `setup.py`, requires pybind11, NumPy, SciPy). Source under `python/fasttext_module/`.

### Docker / release artifacts
`Dockerfile` builds against `quay.io/pypa/manylinux_2_28_x86_64` for portable Linux/Python wheels. `.github/workflows/build.yml` (GitHub Actions) builds and pushes `aymara/fasttext_manylinux_2_28` to ghcr.io on push to `read_from_xz`. This is the only CI.

## Testing

- Python tests: `python runtests.py -u` (unit) or `python runtests.py -i --data-dir <dir>` (integration). Integration tests need data fetched via `tests/fetch_test_data.sh` first.
- There is no C++ unit test suite; the shell scripts in the repo root (`word-vector-example.sh`, `classification-example.sh`, `classification-results.sh`, `quantization-example.sh`) double as end-to-end smoke tests that download data and exercise the CLI.

## Architecture

All C++ lives in `src/`. Core flow, top-down:

- **`main.cc`** — CLI dispatch: maps subcommands (`skipgram`, `cbow`, `supervised`, `test`, `predict`, `predict-prob`, `quantize`, `print-word-vectors`, `print-sentence-vectors`, etc.) onto `FastText` methods.
- **`fasttext.{h,cc}`** — the `FastText` orchestrator. Owns training loop, model save/load (`.bin`/`.vec`/`.ftz`), inference, and quantization. This is where input is opened: training (`train`) and dictionary building read through `impl::ArchiveReader` (see below).
- **`dictionary.{h,cc}`** — vocabulary, subword (char n-gram) hashing, and line reading. `getLine(...)` and `reset(...)` take an `impl::ArchiveReader&` rather than a raw stream — this is the main fork touch point for transparent decompression.
- **`model.{h,cc}`** + **`loss.{h,cc}`** — the training model and pluggable loss functions (negative sampling `ns`, hierarchical softmax `hs`, full `softmax`, one-vs-all `ova`).
- **Matrix layer:** `matrix.h` (abstract) → `densematrix` (training-time weights) and `quantmatrix` (quantized inference). `productquantizer.{h,cc}` implements the PQ compression behind `quantize`/`.ftz`.
- **`args.{h,cc}`** — all hyperparameters and CLI argument parsing/defaults.
- **`vector`, `utils`, `meter`, `real.h`** — math vectors, helpers, evaluation metrics (P@k/R@k), and the `real` (float) typedef.

### archivereader.h (the fork's core addition)
`src/archivereader.h` defines `fasttext::impl::ArchiveReader`, a header-only RAII wrapper over a `boost::iostreams::filtering_stream`. It auto-detects/pushes gzip and lzma decompression filters so that `FastText` and `Dictionary` consume compressed input files transparently. It is only compiled meaningfully when the Boost iostreams path is enabled. When modifying input-reading code, route through `ArchiveReader` rather than `std::ifstream` to preserve archive support.

## Conventions

- C++11 only (original upstream constraint); when adding `.cc`/`.h` files, update the explicit source lists in `CMakeLists.txt` (`SOURCE_FILES`/`HEADER_FILES`).
- Upstream fastText is archived, so changes no longer need to be merge-compatible with upstream `master`.
