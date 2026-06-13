#!/bin/bash

set -e

GCJ_VERSION="2.0.0"
GCJ_NAME="GNU J++ Collection"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_error() { echo -e "${RED}gcj: error: $1${NC}" >&2; }
print_warning() { echo -e "${YELLOW}gcj: warning: $1${NC}" >&2; }
print_info() { echo -e "${BLUE}gcj: info: $1${NC}"; }
print_success() { echo -e "${GREEN}gcj: $1${NC}"; }
print_fast() { echo -e "${CYAN}gcj: $1${NC}"; }

show_help() {
    cat << 'EOF'

===============================================
GNU J++ Collection (GCJ) - DIRECT ASSEMBLY
Version 2.0.0 - J++ → ASM → Machine Code
===============================================

Usage: gcj [options] <filename.jpp>

COMPILE MODES:
  gcj file.jpp              Compile to executable (default)
  gcj file.jpp -exec        Compile and execute immediately
  gcj file.jpp -o file      Output to specific file
  gcj file.jpp -S            Generate assembly only (.s file)
  gcj file.jpp -c            Compile to object file (.o file)
  gcj file.jpp -E            Preprocess only

ASSEMBLY OPTIONS:
  -masm=intel               Intel syntax (default)
  -masm=att                 AT&T syntax
  -march=x86-64             x86-64 architecture (default)
  -march=x86                32-bit x86
  -march=arm64              ARM64 architecture
  -march=arm32              ARM 32-bit
  -march=riscv64            RISC-V 64-bit
  -march=riscv32            RISC-V 32-bit

OPTIMIZATION:
  -O0                       No optimization (default)
  -O1                       Basic optimization
  -O2                       Standard optimization
  -O3                       Aggressive optimization
  -Os                       Optimize for size
  -Ofast                    Fast optimization
  -funroll-loops            Unroll loops
  -finline-functions        Inline functions
  -fvectorize               Vectorize operations

DEBUG:
  -g                        Generate debug info
  -g0/-g1/-g2/-g3           Debug levels

WARNINGS:
  -Wall                     All warnings
  -Werror                   Warnings as errors
  -Wextra                   Extra warnings

ARCHITECTURE:
  -m32                      32-bit mode
  -m64                      64-bit mode (default)
  -mavx                     Enable AVX
  -mavx2                    Enable AVX2
  -msse4.2                  Enable SSE4.2
  -mfpu=neon                ARM NEON

J++ SPECIFIC:
  --emit-ast                Emit AST dump
  --emit-tokens             Emit token dump
  --emit-asm                Emit assembly (same as -S)
  --emit-ir                 Emit intermediate IR
  --syntax-only             Check syntax only
  --show-time               Show timing
  --show-asm                Show generated assembly
  --save-temps              Keep all intermediate files

FREESTANDING:
  -ffreestanding            No standard library
  -nostdlib                 No standard library
  -nostdinc                 No standard includes

LINKER OPTIONS:
  -static                   Static linking
  -shared                   Shared library
  -fPIC                     Position independent code
  -l<lib>                   Link library
  -L<path>                  Library path

PREPROCESSOR:
  -I<path>                  Include path
  -D<macro>                 Define macro
  -U<macro>                 Undefine macro

OUTPUT:
  -v, --verbose             Verbose output
  -s, --silent              Silent mode
  --help                    Show help
  --version                 Show version

EXAMPLES:
  gcj hello.jpp                        # Compile to hello
  gcj hello.jpp -exec                  # Compile and run
  gcj hello.jpp -S                     # Generate hello.s
  gcj hello.jpp -c                     # Generate hello.o
  gcj hello.jpp -O2 -Wall -exec        # Optimize + warnings + run
  gcj hello.jpp -m32 -o hello32        # 32-bit compile
  gcj hello.jpp -march=arm64 -o hello  # ARM64 compile
  gcj hello.jpp -ffreestanding -o hello.o  # No stdlib
  gcj hello.jpp -S -masm=att           # AT&T syntax assembly

EOF
}

show_version() {
    cat << EOF

===============================================
${GCJ_NAME}
Version: ${GCJ_VERSION}
J++ Standard: J++23
===============================================

Backend: Direct Assembly Code Generator
Assembler: GNU as / LLVM MC
Linker: GNU ld / gold / lld

Supported Architectures:
  x86-64 (default)     - Intel/AMD 64-bit
  x86 (i386)           - Intel/AMD 32-bit
  arm64 (aarch64)      - ARM 64-bit
  arm32 (armv7)        - ARM 32-bit
  riscv64              - RISC-V 64-bit
  riscv32              - RISC-V 32-bit

Optimization Levels: O0, O1, O2, O3, Os, Ofast

Features:
   J++ to Assembly
   J++ to Object (.o files)
  machine code generation
  architecture support
  SIMD vectorization (AVX/AVX2/SSE/NEON)
  Inline assembly support
  Fast compilation 

EOF
}

# Parse arguments
INPUT_FILE=""
OUTPUT_FILE=""
EXEC_MODE=0
ASSEMBLY_ONLY=0
OBJECT_ONLY=0
PREPROCESS_ONLY=0
ARCH="x86-64"
ASM_SYNTAX="intel"
OPTIMIZATION="O0"
DEBUG_INFO=""
WARNINGS=""
VERBOSE=0
SILENT=0
SHOW_ASM=0
SAVE_TEMPS=0
FREESTANDING=0
STATIC_LINK=0
SHARED_LIB=0
PIC=0
BITS=64
EXTRA_FLAGS=""
INCLUDE_PATHS=""
DEFINE_MACROS=""
LIBS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) show_help; exit 0 ;;
        --version) show_version; exit 0 ;;
        -exec) EXEC_MODE=1; shift ;;
        -S) ASSEMBLY_ONLY=1; shift ;;
        -c) OBJECT_ONLY=1; shift ;;
        -E) PREPROCESS_ONLY=1; shift ;;
        -o)
            if [ -n "$2" ]; then OUTPUT_FILE="$2"; shift 2; else print_error "-o requires argument"; exit 1; fi
            ;;
        -masm=intel) ASM_SYNTAX="intel"; shift ;;
        -masm=att) ASM_SYNTAX="att"; shift ;;
        -march=x86-64) ARCH="x86-64"; BITS=64; shift ;;
        -march=x86) ARCH="x86"; BITS=32; shift ;;
        -march=arm64|-march=aarch64) ARCH="arm64"; BITS=64; shift ;;
        -march=arm32|-march=armv7) ARCH="arm32"; BITS=32; shift ;;
        -march=riscv64) ARCH="riscv64"; BITS=64; shift ;;
        -march=riscv32) ARCH="riscv32"; BITS=32; shift ;;
        -O0) OPTIMIZATION="O0"; shift ;;
        -O1) OPTIMIZATION="O1"; shift ;;
        -O2) OPTIMIZATION="O2"; shift ;;
        -O3) OPTIMIZATION="O3"; shift ;;
        -Os) OPTIMIZATION="Os"; shift ;;
        -Ofast) OPTIMIZATION="Ofast"; shift ;;
        -g) DEBUG_INFO="-g"; shift ;;
        -g0) DEBUG_INFO="-g0"; shift ;;
        -g1) DEBUG_INFO="-g1"; shift ;;
        -g2) DEBUG_INFO="-g2"; shift ;;
        -g3) DEBUG_INFO="-g3"; shift ;;
        -Wall) WARNINGS="$WARNINGS -Wall"; shift ;;
        -Werror) WARNINGS="$WARNINGS -Werror"; shift ;;
        -Wextra) WARNINGS="$WARNINGS -Wextra"; shift ;;
        -m32) BITS=32; shift ;;
        -m64) BITS=64; shift ;;
        -mavx) EXTRA_FLAGS="$EXTRA_FLAGS -mavx"; shift ;;
        -mavx2) EXTRA_FLAGS="$EXTRA_FLAGS -mavx2"; shift ;;
        -msse4.2) EXTRA_FLAGS="$EXTRA_FLAGS -msse4.2"; shift ;;
        -mfpu=neon) EXTRA_FLAGS="$EXTRA_FLAGS -mfpu=neon"; shift ;;
        -funroll-loops) EXTRA_FLAGS="$EXTRA_FLAGS -funroll-loops"; shift ;;
        -finline-functions) EXTRA_FLAGS="$EXTRA_FLAGS -finline-functions"; shift ;;
        -fvectorize) EXTRA_FLAGS="$EXTRA_FLAGS -fvectorize"; shift ;;
        -ffreestanding|-nostdlib) FREESTANDING=1; shift ;;
        -static) STATIC_LINK=1; shift ;;
        -shared) SHARED_LIB=1; shift ;;
        -fPIC) PIC=1; shift ;;
        -v|--verbose) VERBOSE=1; shift ;;
        -s|--silent) SILENT=1; shift ;;
        --show-asm) SHOW_ASM=1; shift ;;
        --save-temps) SAVE_TEMPS=1; shift ;;
        --emit-ast|--emit-tokens|--emit-ir) shift ;;
        --syntax-only) shift ;;
        --show-time) shift ;;
        -I*) INCLUDE_PATHS="$INCLUDE_PATHS $1"; shift ;;
        -D*) DEFINE_MACROS="$DEFINE_MACROS $1"; shift ;;
        -U*) DEFINE_MACROS="$DEFINE_MACROS $1"; shift ;;
        -L*) EXTRA_FLAGS="$EXTRA_FLAGS $1"; shift ;;
        -l*) LIBS="$LIBS $1"; shift ;;
        -*) print_error "unknown option '$1'"; exit 1 ;;
        *)
            if [ -z "$INPUT_FILE" ]; then INPUT_FILE="$1"; else print_error "multiple input files"; exit 1; fi
            shift
            ;;
    esac
done

if [ -z "$INPUT_FILE" ]; then
    print_error "no input file"
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    print_error "cannot find '$INPUT_FILE'"
    exit 1
fi

# Determine output filename
if [ -z "$OUTPUT_FILE" ]; then
    BASENAME=$(basename "$INPUT_FILE" .jpp)
    if [ $ASSEMBLY_ONLY -eq 1 ]; then
        OUTPUT_FILE="${BASENAME}.s"
    elif [ $OBJECT_ONLY -eq 1 ]; then
        OUTPUT_FILE="${BASENAME}.o"
    else
        OUTPUT_FILE="$BASENAME"
    fi
fi

# Temporary directory
TEMP_DIR="/tmp/gcj_$$"
mkdir -p "$TEMP_DIR"
trap "rm -rf $TEMP_DIR" EXIT

# Build compiler arguments
COMPILER_ARGS=""
[ $VERBOSE -eq 1 ] && COMPILER_ARGS="$COMPILER_ARGS --verbose"
[ $SILENT -eq 1 ] && COMPILER_ARGS="$COMPILER_ARGS --silent"
[ $SHOW_ASM -eq 1 ] && COMPILER_ARGS="$COMPILER_ARGS --show-asm"
[ $SAVE_TEMPS -eq 1 ] && COMPILER_ARGS="$COMPILER_ARGS --save-temps"
[ $FREESTANDING -eq 1 ] && COMPILER_ARGS="$COMPILER_ARGS --freestanding"

COMPILER_ARGS="$COMPILER_ARGS --arch=$ARCH"
COMPILER_ARGS="$COMPILER_ARGS --syntax=$ASM_SYNTAX"
COMPILER_ARGS="$COMPILER_ARGS --opt=$OPTIMIZATION"
COMPILER_ARGS="$COMPILER_ARGS --bits=$BITS"
COMPILER_ARGS="$COMPILER_ARGS $INCLUDE_PATHS"
COMPILER_ARGS="$COMPILER_ARGS $DEFINE_MACROS"

# J++ Compiler binary
JPP_COMPILER="jpp_compiler"
if [ -f "./$JPP_COMPILER" ]; then
    JPP_COMPILER="./$JPP_COMPILER"
elif [ -f "/usr/local/lib/gcj/$JPP_COMPILER" ]; then
    JPP_COMPILER="/usr/local/lib/gcj/$JPP_COMPILER"
else
    print_error "J++ compiler not found. Build first with: make"
    exit 1
fi

# Timing
START_TIME=$(date +%s.%N)

if [ $PREPROCESS_ONLY -eq 1 ]; then
    print_info "preprocessing '$INPUT_FILE'..."
    $JPP_COMPILER "$INPUT_FILE" $COMPILER_ARGS --preprocess-only
    exit 0
fi

# Step 1: J++ → Assembly
print_fast "J++ → Assembly compilation..."
print_info "target: $ARCH ($BITS-bit)"
print_info "syntax: $ASM_SYNTAX"
print_info "optimization: $OPTIMIZATION"

ASM_FILE="$TEMP_DIR/output.s"
$JPP_COMPILER "$INPUT_FILE" $COMPILER_ARGS -o "$ASM_FILE"

if [ $? -ne 0 ]; then
    print_error "J++ compilation failed"
    exit 1
fi

if [ $ASSEMBLY_ONLY -eq 1 ]; then
    cp "$ASM_FILE" "$OUTPUT_FILE"
    print_success "assembly generated: $OUTPUT_FILE"
    
    if [ $SHOW_ASM -eq 1 ] || [ $VERBOSE -eq 1 ]; then
        echo ""
        echo "=== GENERATED ASSEMBLY ==="
        cat "$OUTPUT_FILE"
        echo "=========================="
    fi
    
    exit 0
fi

# Show assembly if requested
if [ $SHOW_ASM -eq 1 ] || [ $VERBOSE -eq 1 ]; then
    echo ""
    echo "=== GENERATED ASSEMBLY ==="
    cat "$ASM_FILE"
    echo "=========================="
    echo ""
fi

# Step 2: Assembly → Object (using as)
print_fast "Assembly → Object..."

OBJ_FILE="$TEMP_DIR/output.o"

# Choose assembler based on architecture
case "$ARCH" in
    x86-64|x86)
        AS="as"
        [ $BITS -eq 32 ] && AS_FLAGS="--32" || AS_FLAGS="--64"
        ;;
    arm64)
        AS="aarch64-linux-gnu-as"
        AS_FLAGS=""
        ;;
    arm32)
        AS="arm-linux-gnueabihf-as"
        AS_FLAGS="-march=armv7-a"
        ;;
    riscv64)
        AS="riscv64-linux-gnu-as"
        AS_FLAGS=""
        ;;
    riscv32)
        AS="riscv32-linux-gnu-as"
        AS_FLAGS=""
        ;;
    *)
        AS="as"
        AS_FLAGS=""
        ;;
esac

$AS $AS_FLAGS "$ASM_FILE" -o "$OBJ_FILE"

if [ $? -ne 0 ]; then
    print_error "assembly failed"
    exit 1
fi

if [ $OBJECT_ONLY -eq 1 ]; then
    cp "$OBJ_FILE" "$OUTPUT_FILE"
    print_success "object file created: $OUTPUT_FILE"
    exit 0
fi

# Step 3: Object → Executable (using ld or gcc)
print_fast "Object → Executable..."

# Build linker command
LD_FLAGS=""
[ $BITS -eq 32 ] && LD_FLAGS="$LD_FLAGS -m elf_i386"
[ $BITS -eq 64 ] && LD_FLAGS="$LD_FLAGS -m elf_x86_64"
[ $STATIC_LINK -eq 1 ] && LD_FLAGS="$LD_FLAGS -static"
[ $SHARED_LIB -eq 1 ] && LD_FLAGS="$LD_FLAGS -shared"
[ $PIC -eq 1 ] && LD_FLAGS="$LD_FLAGS -pie"
[ -n "$DEBUG_INFO" ] && LD_FLAGS="$LD_FLAGS $DEBUG_INFO"

# Use gcc for linking (handles C runtime)
if [ $FREESTANDING -eq 1 ]; then
    # Freestanding - no C runtime, just raw link
    LD="ld"
    $LD $LD_FLAGS "$OBJ_FILE" -o "$OUTPUT_FILE" $LIBS
else
    # Normal - use gcc to link with C runtime
    LD="gcc"
    GCC_ARCH=""
    [ $BITS -eq 32 ] && GCC_ARCH="-m32"
    [ $BITS -eq 64 ] && GCC_ARCH="-m64"
    $LD $GCC_ARCH $LD_FLAGS $EXTRA_FLAGS "$OBJ_FILE" -o "$OUTPUT_FILE" $LIBS
fi

if [ $? -ne 0 ]; then
    print_error "linking failed"
    exit 1
fi

chmod +x "$OUTPUT_FILE"

END_TIME=$(date +%s.%N)
ELAPSED=$(echo "$END_TIME - $START_TIME" | bc)

print_success "executable created: $OUTPUT_FILE"
print_fast "compilation time: ${ELAPSED}s"

# Save temps if requested
if [ $SAVE_TEMPS -eq 1 ]; then
    cp "$ASM_FILE" "${BASENAME}.s"
    cp "$OBJ_FILE" "${BASENAME}.o"
    print_info "saved: ${BASENAME}.s and ${BASENAME}.o"
fi

# Execute if requested
if [ $EXEC_MODE -eq 1 ]; then
    echo ""
    echo "========== EXECUTING =========="
    "./$OUTPUT_FILE"
    EXIT_CODE=$?
    echo "========== EXIT: $EXIT_CODE =========="
    echo ""
    exit $EXIT_CODE
fi

exit 0
