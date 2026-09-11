# ── Rust toolchain setup (run once) ──────────────────────────
#   rustup toolchain install nightly
#   rustup component add rust-src --toolchain nightly
#   rustup target add wasm32-unknown-emscripten --toolchain nightly
#   rustup target add wasm32-unknown-emscripten
#
# ── Emscripten SDK setup (run once) ──────────────────────────
#   git clone https://github.com/emscripten-core/emsdk.git
#   cd emsdk && ./emsdk install 3.1.74 && ./emsdk activate 3.1.74
#   source ./emsdk_env.sh

# Build Rust GDExtension for native (cross-platform)
# Handles platform-specific extension copying and codesigning (macOS only).
build-rust:
    cd extensions && cargo build
    @if [ "$(uname)" = "Darwin" ]; then \
        echo "macOS detected: copying and signing dylib"; \
        cp extensions/target/debug/libxiangke_godot_bridge.dylib addons/gdext/libxiangke-godot-bridge.macos.debug.dylib; \
        codesign --force --sign - addons/gdext/libxiangke-godot-bridge.macos.debug.dylib; \
    elif [ "$(expr substr $(uname -s) 1 5)" = "Linux" ]; then \
        echo "Linux detected: copying so"; \
        cp extensions/target/debug/libxiangke_godot_bridge.so addons/gdext/libxiangke-godot-bridge.linux.debug.so; \
    elif [ "$(expr substr $(uname -s) 1 10)" = "MINGW64_NT" ]; then \
        echo "Windows detected: copying dll"; \
        cp extensions/target/debug/xiangke_godot_bridge.dll addons/gdext/xiangke-godot-bridge.windows.debug.dll; \
    else \
        echo "Unknown platform: copying debug library"; \
        cp extensions/target/debug/libxiangke_godot_bridge.* addons/gdext/; \
    fi

# Build Rust GDExtension for native in release mode (cross-platform)
build-rust-release:
    cd extensions && cargo build --release
    @if [ "$(uname)" = "Darwin" ]; then \
        echo "macOS detected: copying and signing release dylib"; \
        cp extensions/target/release/libxiangke_godot_bridge.dylib addons/gdext/libxiangke-godot-bridge.macos.release.dylib; \
        codesign --force --sign - addons/gdext/libxiangke-godot-bridge.macos.release.dylib; \
    elif [ "$(expr substr $(uname -s) 1 5)" = "Linux" ]; then \
        echo "Linux detected: copying release so"; \
        cp extensions/target/release/libxiangke_godot_bridge.so addons/gdext/libxiangke-godot-bridge.linux.release.so; \
    elif [ "$(expr substr $(uname -s) 1 10)" = "MINGW64_NT" ]; then \
        echo "Windows detected: copying release dll"; \
        cp extensions/target/release/xiangke_godot_bridge.dll addons/gdext/xiangke-godot-bridge.windows.release.dll; \
    else \
        echo "Unknown platform: copying release library"; \
        cp extensions/target/release/libxiangke_godot_bridge.* addons/gdext/; \
    fi

# Build Rust GDExtension for Web (WASM/Emscripten)
# Requires: nightly toolchain, Emscripten SDK, rust-src component
build-rust-wasm:
    cd extensions && cargo +nightly build -Zbuild-std --target wasm32-unknown-emscripten

# Build WASM in release mode with size optimization
build-rust-wasm-release:
    cd extensions && cargo +nightly build -Zbuild-std --target wasm32-unknown-emscripten --release
    wasm-opt -Oz \
      --enable-bulk-memory \
      --enable-sign-ext \
      --enable-nontrapping-float-to-int \
      --enable-mutable-globals \
      target/wasm32-unknown-emscripten/release/xiangke_godot_bridge.wasm \
      -o target/wasm32-unknown-emscripten/release/xiangke_godot_bridge.wasm

# Quick-check WASM compilation without full build
check-rust-wasm:
    cd extensions && cargo +nightly check -Zbuild-std --target wasm32-unknown-emscripten

test-rust:
    cd extensions && cargo test

check-rust:
    cd extensions && cargo check

run-godot: build-rust
    godot

# Godot project validation
inspect: build-rust
    godot --headless --check-only --debug --verbose --quit

# ── Data verification ────────────────────────────────────────
# Export all .tres resources via Godot and validate against Rust core schema/rules.
# Requires: local Godot install (headless mode).
# Usage: just verify-data
#        UPDATE_FIXTURE=1 just verify-data   (regenerate integration fixture)
verify-data:
	set -eu; \
	export_path=$(mktemp -t xiangke_data.XXXXXX.json); \
	trap 'rm -f "$export_path"' EXIT; \
	echo "Exporting resources to $export_path..."; \
	godot --headless res://tools/data_export.tscn -- --export-path=$export_path; \
	echo "Validating with Rust checker..."; \
	cd extensions && cargo run -p xiangke-checker --release -- validate $export_path; \
	if [ -n "${UPDATE_FIXTURE:-}" ]; then \
		echo "Updating fixture..."; \
		cp $export_path core/tests/fixtures/resources.json; \
		echo "✓ Fixture updated at core/tests/fixtures/resources.json"; \
	else \
		echo "✓ All data valid"; \
	fi; \
	rm -f $export_path

# ── Roster report CLI ────────────────────────────────────────
# Rust-based CLI tool for data analysis and visualization.
# Usage: just report roster
#        just report types --format=csv
#        just report radar --format=html --output=report.html
report cmd *args:
    cd extensions && cargo run -q -p roster_report -- {{cmd}} --dir=../resources {{args}}
