#!/bin/bash
# ============================================================
# J++ Unity Build Script
# BSD-2-Clause License
# ============================================================

set -e

JPP_SRC="src/jpp"
BUILD_DIR="build"
UNITY_DIR="Assets/Jpp"

echo "=== J++ Unity Build ==="

# 1. Parse J++ → XML
echo "[1/5] Parsing J++ source..."
mkdir -p $BUILD_DIR/xml
for f in $JPP_SRC/*.jpp; do
    ./tools/gjc_parser "$f" > "$BUILD_DIR/xml/$(basename $f .jpp).xml"
done

# 2. Generate Lua (Physics/Shaders)
echo "[2/5] Generating Lua modules..."
mkdir -p $BUILD_DIR/lua
./tools/gjc_codegen --module lua --input $BUILD_DIR/xml --output $BUILD_DIR/lua

# 3. Generate C# (UI/Networking)
echo "[3/5] Generating C# modules..."
mkdir -p $BUILD_DIR/cs
./tools/gjc_codegen --module csharp --input $BUILD_DIR/xml --output $BUILD_DIR/cs

# 4. Compile Lua → WASM
echo "[4/5] Compiling Lua to WASM..."
mkdir -p $BUILD_DIR/wasm
for f in $BUILD_DIR/lua/*.lua; do
    luajit -b "$f" "$BUILD_DIR/wasm/$(basename $f .lua).wasm"
done

# 5. Copy to Unity
echo "[5/5] Copying to Unity project..."
mkdir -p $UNITY_DIR/{Scripts,Plugins,Resources,Shaders}

cp $BUILD_DIR/cs/*.cs $UNITY_DIR/Scripts/
cp $BUILD_DIR/wasm/*.wasm $UNITY_DIR/Plugins/
cp src/csharp/JppUnity_Complete.cs $UNITY_DIR/Scripts/
cp src/webgl/*.jslib $UNITY_DIR/Plugins/WebGL/

echo "=== Build Complete ==="
echo "Output: $UNITY_DIR"