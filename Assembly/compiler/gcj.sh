#!/bin/bash
# ============================================================================
# GNU J++ Collection (GCJ) - Command Line Interface
# 
# Usage:
#   gcj filename.jpp              Compile and create executable
#   gcj filename.jpp -exec      Compile and execute immediately
#   gcj filename.jpp -o file    Output to specific file
#   gcj filename.jpp -c         Compile only (object file)
#   gcj filename.jpp -S         Generate assembly
#   gcj filename.jpp -E         Preprocess only
#   gcj filename.jpp -ffreestanding  Compile without stdlib
#   gcj filename.jpp -g         Debug info
#   gcj filename.jpp -O0/-O1/-O2/-O3 Optimization levels
#   gcj filename.jpp -Wall      All warnings
#   gcj filename.jpp -Werror    Warnings as errors
# ============================================================================

set -e

# GCJ Configuration
GCJ_VERSION="1.0.0"
GCJ_NAME="GNU J++ Collection"
GCJ_COMPILER="jpp_compiler"
GCJ_INSTALL_DIR="/usr/local/lib/gcj"
GCJ_STD_INCLUDE="/usr/local/include/jpp"
GCJ_TEMP_DIR="/tmp/gcj_$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_error() {
    echo -e "${RED}gcj: error: $1${NC}" >&2
}

print_warning() {
    echo -e "${YELLOW}gcj: warning: $1${NC}" >&2
}

print_info() {
    echo -e "${BLUE}gcj: info: $1${NC}"
}

print_success() {
    echo -e "${GREEN}gcj: $1${NC}"
}

# Function to show help
show_help() {
    cat << 'EOF'

===============================================
GNU J++ Collection (GCJ) - Version 1.0.0
Copyright (C) 2026 Jatin. All rights reserved.
===============================================

Usage: gcj [options] <filename.jpp>

Basic Options:
  -exec                    Compile and execute immediately
  -o <file>                Output to specified file
  -c                       Compile only, do not link
  -S                       Generate assembly output
  -E                       Preprocess only
  -ffreestanding           Compile without standard library

Optimization Options:
  -O0                      No optimization (default)
  -O1                      Basic optimization
  -O2                      Standard optimization
  -O3                      Aggressive optimization
  -Os                      Optimize for size

Warning Options:
  -Wall                    Enable all warnings
  -Werror                  Treat warnings as errors
  -Wextra                  Extra warnings

Debug Options:
  -g                       Generate debug information
  -g0, -g1, -g2, -g3      Debug levels

J++ Specific Options:
  --emit-ast               Emit AST dump
  --emit-tokens            Emit token dump
  --emit-ir                Emit intermediate representation
  --syntax-only            Only check syntax
  --show-time              Show compilation timing
  --use-jpp-stdlib         Include J++ standard library (default)
  --use-jpp-math           Include J++ math library
  --use-jpp-physics        Include J++ physics library
  --use-jpp-string         Include J++ string library
  --use-jpp-time           Include J++ time library

Preprocessor Options:
  -I<path>                 Add include path
  -D<macro>                Define macro
  -U<macro>                Undefine macro

Linker Options:
  -l<library>              Link with library
  -L<path>                 Add library search path
  -static                  Static linking
  -shared                  Create shared library

Architecture Options:
  -m32                     Compile for 32-bit
  -m64                     Compile for 64-bit (default)

Output Control:
  -v, --verbose            Verbose output
  -s, --silent             Silent mode
  --keep-temp              Keep temporary files

Information:
  --help                   Show this help
  --version                Show version

Examples:
  gcj hello.jpp                    # Compile hello.jpp
  gcj hello.jpp -exec              # Compile and run
  gcj hello.jpp -o hello           # Output to 'hello'
  gcj hello.jpp -c                 # Compile to hello.o
  gcj hello.jpp -S                 # Generate hello.s
  gcj hello.jpp -O2 -Wall          # Optimize with warnings
  gcj hello.jpp -g -O0             # Debug build
  gcj hello.jpp -ffreestanding     # Freestanding
  gcj hello.jpp -m32               # 32-bit compile

EOF
}

# Function to show version
show_version() {
    cat << EOF

===============================================
GNU J++ Collection (GCJ)
Version: ${GCJ_VERSION} (J++ Standard: J++23)
Copyright (C) 2026 Jatin. All rights reserved.
===============================================

Compiler Details:
  Target: x86_64-linux-gnu
  Thread model: posix
  Supported J++ Standards: J++11, J++17, J++20, J++23
  Default Standard: J++23
  Built-in Types: 17 (including very long double)
  Max Array Dimensions: 32
  Max Struct Fields: 1024
  Max Function Parameters: 256
  Max Identifier Length: 1024
  Max String Literal: 65536

Backend: GCC-compatible C code generator
Assembler: GNU as
Linker: GNU ld / gold

EOF
}

# Function to check if file exists
check_file() {
    if [ ! -f "$1" ]; then
        print_error "cannot find '$1': No such file or directory"
        exit 1
    fi
}

# Function to check file extension
check_extension() {
    if [[ ! "$1" =~ \.jpp$ ]]; then
        print_warning "file '$1' does not have .jpp extension"
    fi
}

# Function to create temp directory
setup_temp() {
    mkdir -p "${GCJ_TEMP_DIR}"
    trap 'cleanup_temp' EXIT
}

# Function to cleanup temp directory
cleanup_temp() {
    if [ -d "${GCJ_TEMP_DIR}" ]; then
        rm -rf "${GCJ_TEMP_DIR}"
    fi
}

# Function to get base filename without extension
get_basename() {
    local filename=$(basename "$1")
    echo "${filename%.jpp}"
}

# Function to get directory of file
get_dirname() {
    dirname "$1"
}

# Function to compile J++ to C
compile_jpp_to_c() {
    local input_file="$1"
    local output_c="$2"
    local extra_args="$3"
    
    print_info "compiling '${input_file}'..."
    
    # Check if compiler binary exists
    if [ ! -f "${GCJ_INSTALL_DIR}/${GCJ_COMPILER}" ]; then
        # Try local build
        if [ -f "./${GCJ_COMPILER}" ]; then
            GCJ_INSTALL_DIR="."
        else
            print_error "J++ compiler not found. Please build first."
            print_info "Run: make build"
            exit 1
        fi
    fi
    
    # Run the actual compiler
    "${GCJ_INSTALL_DIR}/${GCJ_COMPILER}" "${input_file}" ${extra_args} -o "${output_c}" 2>&1
    
    if [ $? -ne 0 ]; then
        print_error "compilation failed"
        exit 1
    fi
}

# Function to compile C to object
compile_c_to_o() {
    local input_c="$1"
    local output_o="$2"
    local gcc_args="$3"
    
    print_info "generating object file..."
    
    gcc ${gcc_args} -c "${input_c}" -o "${output_o}"
    
    if [ $? -ne 0 ]; then
        print_error "object compilation failed"
        exit 1
    fi
}

# Function to compile C to assembly
compile_c_to_s() {
    local input_c="$1"
    local output_s="$2"
    local gcc_args="$3"
    
    print_info "generating assembly..."
    
    gcc ${gcc_args} -S "${input_c}" -o "${output_s}"
    
    if [ $? -ne 0 ]; then
        print_error "assembly generation failed"
        exit 1
    fi
}

# Function to link object to executable
link_to_executable() {
    local input_o="$1"
    local output_bin="$2"
    local gcc_args="$3"
    local libs="$4"
    
    print_info "linking..."
    
    gcc ${gcc_args} "${input_o}" ${libs} -o "${output_bin}"
    
    if [ $? -ne 0 ]; then
        print_error "linking failed"
        exit 1
    fi
}

# Function to run executable
run_executable() {
    local executable="$1"
    
    print_info "executing '${executable}'..."
    echo ""
    echo "========== PROGRAM OUTPUT =========="
    
    "./${executable}"
    local exit_code=$?
    
    echo "========== END OUTPUT (exit: ${exit_code}) =========="
    echo ""
    
    return ${exit_code}
}

# Function to preprocess only
preprocess_only() {
    local input_file="$1"
    local extra_args="$2"
    
    print_info "preprocessing '${input_file}'..."
    
    "${GCJ_INSTALL_DIR}/${GCJ_COMPILER}" "${input_file}" ${extra_args} -E 2>&1
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

# Parse arguments
INPUT_FILE=""
OUTPUT_FILE=""
EXEC_MODE=0
COMPILE_ONLY=0
ASSEMBLE_ONLY=0
PREPROCESS_ONLY=0
FREESTANDING=0
DEBUG_INFO=""
OPTIMIZATION="-O0"
WARNINGS=""
VERBOSE=0
SILENT=0
KEEP_TEMP=0
EMIT_AST=0
EMIT_TOKENS=0
EMIT_IR=0
SYNTAX_ONLY=0
SHOW_TIME=0
USE_JPP_STDLIB=1
USE_JPP_MATH=0
USE_JPP_PHYSICS=0
USE_JPP_STRING=0
USE_JPP_TIME=0
ARCH="-m64"
EXTRA_GCC_ARGS=""
EXTRA_LIBS=""
INCLUDE_PATHS=""
DEFINE_MACROS=""

# Parse all arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --version)
            show_version
            exit 0
            ;;
        -exec)
            EXEC_MODE=1
            shift
            ;;
        -o)
            if [ -n "$2" ]; then
                OUTPUT_FILE="$2"
                shift 2
            else
                print_error "-o requires an argument"
                exit 1
            fi
            ;;
        -c)
            COMPILE_ONLY=1
            shift
            ;;
        -S)
            ASSEMBLE_ONLY=1
            shift
            ;;
        -E)
            PREPROCESS_ONLY=1
            shift
            ;;
        -ffreestanding)
            FREESTANDING=1
            EXTRA_GCC_ARGS="${EXTRA_GCC_ARGS} -ffreestanding -nostdlib"
            shift
            ;;
        -g)
            DEBUG_INFO="-g"
            shift
            ;;
        -g0)
            DEBUG_INFO="-g0"
            shift
            ;;
        -g1)
            DEBUG_INFO="-g1"
            shift
            ;;
        -g2)
            DEBUG_INFO="-g2"
            shift
            ;;
        -g3)
            DEBUG_INFO="-g3"
            shift
            ;;
        -O0)
            OPTIMIZATION="-O0"
            shift
            ;;
        -O1)
            OPTIMIZATION="-O1"
            shift
            ;;
        -O2)
            OPTIMIZATION="-O2"
            shift
            ;;
        -O3)
            OPTIMIZATION="-O3"
            shift
            ;;
        -Os)
            OPTIMIZATION="-Os"
            shift
            ;;
        -Ofast)
            OPTIMIZATION="-Ofast"
            shift
            ;;
        -Wall)
            WARNINGS="${WARNINGS} -Wall"
            shift
            ;;
        -Werror)
            WARNINGS="${WARNINGS} -Werror"
            shift
            ;;
        -Wextra)
            WARNINGS="${WARNINGS} -Wextra"
            shift
            ;;
        -pedantic)
            WARNINGS="${WARNINGS} -pedantic"
            shift
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -s|--silent)
            SILENT=1
            shift
            ;;
        --keep-temp)
            KEEP_TEMP=1
            shift
            ;;
        --emit-ast)
            EMIT_AST=1
            shift
            ;;
        --emit-tokens)
            EMIT_TOKENS=1
            shift
            ;;
        --emit-ir)
            EMIT_IR=1
            shift
            ;;
        --syntax-only)
            SYNTAX_ONLY=1
            shift
            ;;
        --show-time)
            SHOW_TIME=1
            shift
            ;;
        --use-jpp-stdlib)
            USE_JPP_STDLIB=1
            shift
            ;;
        --no-jpp-stdlib)
            USE_JPP_STDLIB=0
            shift
            ;;
        --use-jpp-math)
            USE_JPP_MATH=1
            shift
            ;;
        --use-jpp-physics)
            USE_JPP_PHYSICS=1
            shift
            ;;
        --use-jpp-string)
            USE_JPP_STRING=1
            shift
            ;;
        --use-jpp-time)
            USE_JPP_TIME=1
            shift
            ;;
        -m32)
            ARCH="-m32"
            shift
            ;;
        -m64)
            ARCH="-m64"
            shift
            ;;
        -fPIC)
            EXTRA_GCC_ARGS="${EXTRA_GCC_ARGS} -fPIC"
            shift
            ;;
        -fPIE)
            EXTRA_GCC_ARGS="${EXTRA_GCC_ARGS} -fPIE -pie"
            shift
            ;;
        -static)
            EXTRA_GCC_ARGS="${EXTRA_GCC_ARGS} -static"
            shift
            ;;
        -shared)
            EXTRA_GCC_ARGS="${EXTRA_GCC_ARGS} -shared"
            shift
            ;;
        -I*)
            if [ "${#1}" -gt 2 ]; then
                INCLUDE_PATHS="${INCLUDE_PATHS} $1"
            else
                INCLUDE_PATHS="${INCLUDE_PATHS} -I$2"
                shift
            fi
            shift
            ;;
        -D*)
            if [ "${#1}" -gt 2 ]; then
                DEFINE_MACROS="${DEFINE_MACROS} $1"
            else
                DEFINE_MACROS="${DEFINE_MACROS} -D$2"
                shift
            fi
            shift
            ;;
        -U*)
            DEFINE_MACROS="${DEFINE_MACROS} $1"
            shift
            ;;
        -L*)
            EXTRA_GCC_ARGS="${EXTRA_GCC_ARGS} $1"
            shift
            ;;
        -l*)
            EXTRA_LIBS="${EXTRA_LIBS} $1"
            shift
            ;;
        -framework)
            if [ -n "$2" ]; then
                EXTRA_LIBS="${EXTRA_LIBS} -framework $2"
                shift 2
            else
                print_error "-framework requires an argument"
                exit 1
            fi
            ;;
        -strip)
            EXTRA_GCC_ARGS="${EXTRA_GCC_ARGS} -s"
            shift
            ;;
        -*)
            print_error "unrecognized command-line option '$1'"
            print_info "use 'gcj --help' for usage information"
            exit 1
            ;;
        *)
            if [ -z "${INPUT_FILE}" ]; then
                INPUT_FILE="$1"
            else
                print_error "multiple input files not supported yet"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if input file is provided
if [ -z "${INPUT_FILE}" ]; then
    print_error "no input files"
    print_info "use 'gcj --help' for usage information"
    exit 1
fi

# Check if file exists
check_file "${INPUT_FILE}"

# Check extension
check_extension "${INPUT_FILE}"

# Setup temp directory
setup_temp

# Determine output file name
if [ -z "${OUTPUT_FILE}" ]; then
    BASENAME=$(get_basename "${INPUT_FILE}")
    if [ ${COMPILE_ONLY} -eq 1 ]; then
        OUTPUT_FILE="${BASENAME}.o"
    elif [ ${ASSEMBLE_ONLY} -eq 1 ]; then
        OUTPUT_FILE="${BASENAME}.s"
    else
        OUTPUT_FILE="${BASENAME}"
    fi
fi

# Build compiler extra arguments
COMPILER_ARGS=""
if [ ${VERBOSE} -eq 1 ]; then
    COMPILER_ARGS="${COMPILER_ARGS} -v"
fi
if [ ${SILENT} -eq 1 ]; then
    COMPILER_ARGS="${COMPILER_ARGS} -s"
fi
if [ ${EMIT_AST} -eq 1 ]; then
    COMPILER_ARGS="${COMPILER_ARGS} --emit-ast"
fi
if [ ${EMIT_TOKENS} -eq 1 ]; then
    COMPILER_ARGS="${COMPILER_ARGS} --emit-tokens"
fi
if [ ${EMIT_IR} -eq 1 ]; then
    COMPILER_ARGS="${COMPILER_ARGS} --emit-ir"
fi
if [ ${SYNTAX_ONLY} -eq 1 ]; then
    COMPILER_ARGS="${COMPILER_ARGS} --syntax-only"
fi
if [ ${SHOW_TIME} -eq 1 ]; then
    COMPILER_ARGS="${COMPILER_ARGS} --show-time"
fi
if [ ${USE_JPP_STDLIB} -eq 1 ]; then
    COMPILER_ARGS="${COMPILER_ARGS} --use-jpp-stdlib"
else
    COMPILER_ARGS="${COMPILER_ARGS} --no-jpp-stdlib"
fi
if [ ${USE_JPP_MATH} -eq 1 ]; then
    COMPILER_ARGS="${COMPILER_ARGS} --use-jpp-math"
fi
if [ ${USE_JPP_PHYSICS} -eq 1 ]; then
    COMPILER_ARGS="${COMPILER_ARGS} --use-jpp-physics"
fi
if [ ${USE_JPP_STRING} -eq 1 ]; then
    COMPILER_ARGS="${COMPILER_ARGS} --use-jpp-string"
fi
if [ ${USE_JPP_TIME} -eq 1 ]; then
    COMPILER_ARGS="${COMPILER_ARGS} --use-jpp-time"
fi

# Add include paths
COMPILER_ARGS="${COMPILER_ARGS} ${INCLUDE_PATHS}"

# Add defines
COMPILER_ARGS="${COMPILER_ARGS} ${DEFINE_MACROS}"

# Preprocess only mode
if [ ${PREPROCESS_ONLY} -eq 1 ]; then
    preprocess_only "${INPUT_FILE}" "${COMPILER_ARGS}"
    exit 0
fi

# Main compilation pipeline
START_TIME=$(date +%s.%N)

# Step 1: Compile J++ to C
TEMP_C="${GCJ_TEMP_DIR}/output.c"
compile_jpp_to_c "${INPUT_FILE}" "${TEMP_C}" "${COMPILER_ARGS}"

# If syntax only, we're done
if [ ${SYNTAX_ONLY} -eq 1 ]; then
    print_success "syntax check passed"
    exit 0
fi

# Build GCC arguments
GCC_ARGS="${ARCH} ${OPTIMIZATION} ${DEBUG_INFO} ${WARNINGS} ${EXTRA_GCC_ARGS}"

# Add J++ standard library includes if needed
if [ ${USE_JPP_STDLIB} -eq 1 ] && [ ${FREESTANDING} -eq 0 ]; then
    GCC_ARGS="${GCC_ARGS} -I${GCJ_STD_INCLUDE}"
fi

# Add math library if needed
if [ ${USE_JPP_MATH} -eq 1 ] && [ ${FREESTANDING} -eq 0 ]; then
    EXTRA_LIBS="${EXTRA_LIBS} -lm"
fi

# Step 2: Compile based on mode
if [ ${ASSEMBLE_ONLY} -eq 1 ]; then
    # Generate assembly
    compile_c_to_s "${TEMP_C}" "${OUTPUT_FILE}" "${GCC_ARGS}"
    print_success "assembly generated: ${OUTPUT_FILE}"
    
elif [ ${COMPILE_ONLY} -eq 1 ]; then
    # Compile to object
    compile_c_to_o "${TEMP_C}" "${OUTPUT_FILE}" "${GCC_ARGS}"
    print_success "object file created: ${OUTPUT_FILE}"
    
else
    # Full compilation to executable
    TEMP_O="${GCJ_TEMP_DIR}/output.o"
    compile_c_to_o "${TEMP_C}" "${TEMP_O}" "${GCC_ARGS}"
    link_to_executable "${TEMP_O}" "${OUTPUT_FILE}" "${GCC_ARGS}" "${EXTRA_LIBS}"
    print_success "executable created: ${OUTPUT_FILE}"
    
    # Make executable
    chmod +x "${OUTPUT_FILE}"
    
    # Execute if requested
    if [ ${EXEC_MODE} -eq 1 ]; then
        run_executable "${OUTPUT_FILE}"
        EXIT_CODE=$?
        
        END_TIME=$(date +%s.%N)
        if [ ${SHOW_TIME} -eq 1 ] || [ ${VERBOSE} -eq 1 ]; then
            ELAPSED=$(echo "${END_TIME} - ${START_TIME}" | bc)
            print_info "total time: ${ELAPSED}s"
        fi
        
        exit ${EXIT_CODE}
    fi
fi

END_TIME=$(date +%s.%N)
if [ ${SHOW_TIME} -eq 1 ] || [ ${VERBOSE} -eq 1 ]; then
    ELAPSED=$(echo "${END_TIME} - ${START_TIME}" | bc)
    print_info "total time: ${ELAPSED}s"
fi

print_success "compilation complete"
exit 0
