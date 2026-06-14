# J++ Compiler Build System
# Multi-language: Go (frontend) + C/ASM (backend) + Zig (tools) + Ada (runtime)
# Author: Jatin (linuxab)

# Directories
SRC_DIR = compiler
ADA_DIR = $(SRC_DIR)/runtime/ada
HARDWARE_DIR = $(SRC_DIR)/hardware
RUNTIME_DIR = $(SRC_DIR)/runtime
FRONTEND_DIR = $(SRC_DIR)/frontend
BACKEND_DIR = $(SRC_DIR)/backend
BOOTSTRAP_DIR = $(SRC_DIR)/bootstrap
BUILD_DIR = build
LIB_DIR = $(BUILD_DIR)/lib
BIN_DIR = $(BUILD_DIR)/bin

# Compilers
GO = go
GCC = gcc
GXX = g++
ZIG = zig
GNAT = gnatmake
GPRBUILD = gprbuild
NASM = nasm

# Flags
CFLAGS = -Wall -Wextra -O2 -fPIC -std=c11 -I$(RUNTIME_DIR)
CXXFLAGS = -Wall -Wextra -O2 -fPIC -std=c++17 -I$(RUNTIME_DIR)
ASMFLAGS = -f elf64 -g
LDFLAGS = -L$(LIB_DIR) -ljpp_runtime -lpthread
GOFLAGS = -ldflags="-s -w"
ZIGFLAGS = -O ReleaseFast

# Ada/SPARK settings
SPARK_LEVEL = silver
ADA_TARGET = x86_64

# Targets
.PHONY: all clean install test ada-runtime frontend backend bootstrap lsp hardware docs

all: dirs ada-runtime c-runtime go-bindings zig-bindings frontend backend lsp hardware

dirs:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(LIB_DIR)
	@mkdir -p $(BIN_DIR)
	@mkdir -p $(BUILD_DIR)/obj

# ============================================
# ADA/SPARK RUNTIME (Memory + Hardware)
# ============================================

ada-runtime: dirs
	@echo "Building Ada/SPARK runtime..."
	cd $(SRC_DIR) && $(GPRBUILD) -P jpp_runtime.gpr \
		-XJPP_TARGET=$(ADA_TARGET) \
		-XJPP_BUILD_MODE=release \
		-XJPP_SPARK=$(SPARK_LEVEL)
	cp $(SRC_DIR)/lib/libjpp_runtime.a $(LIB_DIR)/
	@echo "Ada/SPARK runtime built with SPARK $(SPARK_LEVEL) verification"

# Verify Ada/SPARK code with GNATprove
ada-verify:
	@echo "Running SPARK formal verification..."
	cd $(SRC_DIR) && gnatprove -P jpp_runtime.gpr \
		--mode=prove \
		--level=$(SPARK_LEVEL) \
		--checks \
		--report=all

# ============================================
# C RUNTIME (Low-level, ASM glue)
# ============================================

c-runtime: dirs
	@echo "Building C runtime..."
	$(GCC) $(CFLAGS) -c $(RUNTIME_DIR)/jpp_runtime.c -o $(BUILD_DIR)/obj/jpp_runtime_c.o
	$(NASM) $(ASMFLAGS) $(BACKEND_DIR)/asm/jpp_asm_x86_64.s -o $(BUILD_DIR)/obj/jpp_asm.o
	ar rcs $(LIB_DIR)/libjpp_runtime_c.a $(BUILD_DIR)/obj/jpp_runtime_c.o $(BUILD_DIR)/obj/jpp_asm.o

# ============================================
# GO BINDINGS + FRONTEND
# ============================================

go-bindings: dirs
	@echo "Building Go bindings..."
	cd $(RUNTIME_DIR) && $(GO) build $(GOFLAGS) -buildmode=c-archive \
		-o $(LIB_DIR)/jpp_go.a ./jpp_runtime.go

frontend: go-bindings
	@echo "Building J++ frontend (parser, AST, type checker)..."
	cd $(FRONTEND_DIR) && $(GO) build $(GOFLAGS) \
		-o $(BIN_DIR)/jpp-frontend ./cmd/jpp-frontend

# ============================================
# ZIG BINDINGS + TOOLS
# ============================================

zig-bindings: dirs
	@echo "Building Zig bindings..."
	cd $(RUNTIME_DIR) && $(ZIG) build-lib $(ZIGFLAGS) \
		-jpp_runtime.zig \
		-femit-bin=$(LIB_DIR)/libjpp_runtime_zig.a

# ============================================
# BACKEND (C + ASM -> LLVM IR / Machine Code)
# ============================================

backend: c-runtime
	@echo "Building J++ backend (code generator)..."
	$(GXX) $(CXXFLAGS) -c $(BACKEND_DIR)/codegen.cpp -o $(BUILD_DIR)/obj/codegen.o
	$(GXX) $(CXXFLAGS) -c $(BACKEND_DIR)/llvm_ir.cpp -o $(BUILD_DIR)/obj/llvm_ir.o
	$(GXX) $(CXXFLAGS) -c $(BACKEND_DIR)/x86_64_emitter.cpp -o $(BUILD_DIR)/obj/x86_64_emitter.o
	$(GXX) $(CXXFLAGS) -c $(BACKEND_DIR)/arm64_emitter.cpp -o $(BUILD_DIR)/obj/arm64_emitter.o
	$(GXX) $(CXXFLAGS) -c $(BACKEND_DIR)/riscv_emitter.cpp -o $(BUILD_DIR)/obj/riscv_emitter.o
	$(GXX) $(CXXFLAGS) -o $(BIN_DIR)/jpp-backend \
		$(BUILD_DIR)/obj/codegen.o \
		$(BUILD_DIR)/obj/llvm_ir.o \
		$(BUILD_DIR)/obj/x86_64_emitter.o \
		$(BUILD_DIR)/obj/arm64_emitter.o \
		$(BUILD_DIR)/obj/riscv_emitter.o \
		$(LDFLAGS)

# ============================================
# BOOTSTRAP COMPILER (Go)
# ============================================

bootstrap: frontend backend
	@echo "Building J++ bootstrap compiler..."
	cd $(BOOTSTRAP_DIR) && $(GO) build $(GOFLAGS) \
		-o $(BIN_DIR)/jpp-bootstrap ./cmd/jpp-bootstrap

# ============================================
# LSP SERVER
# ============================================

lsp: go-bindings
	@echo "Building J++ LSP server..."
	cd $(SRC_DIR)/lsp && $(GO) build $(GOFLAGS) \
		-o $(BIN_DIR)/jpp-lsp ./cmd/jpp-lsp

# ============================================
# HARDWARE GENERATOR (Ada + Zig)
# ============================================

hardware: ada-runtime zig-bindings
	@echo "Building J++ hardware generator..."
	cd $(HARDWARE_DIR) && $(ZIG) build $(ZIGFLAGS) \
		-o $(BIN_DIR)/jpp-hardware ./cmd/jpp-hardware

# ============================================
# TESTING
# ============================================

test: all
	@echo "Running tests..."
	cd $(SRC_DIR)/lsp && $(GO) test ./...
	cd $(FRONTEND_DIR) && $(GO) test ./...
	cd $(BACKEND_DIR) && $(GO) test ./...
	@echo "Ada/SPARK tests..."
	cd $(SRC_DIR) && gnatprove -P jpp_runtime.gpr --mode=check

# ============================================
# INSTALLATION
# ============================================

install: all
	@echo "Installing J++ compiler..."
	install -d /usr/local/bin
	install -d /usr/local/lib/jpp
	install -d /usr/local/include/jpp
	cp $(BIN_DIR)/* /usr/local/bin/
	cp $(LIB_DIR)/* /usr/local/lib/jpp/
	cp $(RUNTIME_DIR)/jpp_runtime.h /usr/local/include/jpp/
	cp -r kernel/* /usr/local/include/jpp/
	cp -r stdlib/* /usr/local/include/jpp/
	@echo "J++ installed successfully!"

uninstall:
	@echo "Uninstalling J++..."
	rm -f /usr/local/bin/jpp-*
	rm -rf /usr/local/lib/jpp
	rm -rf /usr/local/include/jpp

# ============================================
# CLEAN
# ============================================

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	cd $(SRC_DIR) && gprclean -P jpp_runtime.gpr

# ============================================
# DOCUMENTATION
# ============================================

docs:
	@echo "Building documentation..."
	cd docs && $(GO) run ./cmd/gendocs

# ============================================
# HELP
# ============================================

help:
	@echo "J++ Compiler Build System"
	@echo "========================="
	@echo ""
	@echo "Targets:"
	@echo "  all           - Build everything"
	@echo "  ada-runtime   - Build Ada/SPARK memory manager + hardware generator"
	@echo "  ada-verify    - Run SPARK formal verification"
	@echo "  c-runtime     - Build C/ASM low-level runtime"
	@echo "  go-bindings   - Build Go bindings to Ada runtime"
	@echo "  zig-bindings  - Build Zig bindings to Ada runtime"
	@echo "  frontend      - Build J++ parser/AST/type checker (Go)"
	@echo "  backend       - Build code generator (C++)"
	@echo "  bootstrap     - Build bootstrap compiler"
	@echo "  lsp           - Build LSP server"
	@echo "  hardware      - Build hardware generator (Ada + Zig)"
	@echo "  test          - Run all tests"
	@echo "  install       - Install to /usr/local"
	@echo "  clean         - Clean build artifacts"
	@echo ""
	@echo "Environment variables:"
	@echo "  SPARK_LEVEL   - SPARK verification level (none/stone/bronze/silver/gold)"
	@echo "  ADA_TARGET    - Target platform (x86_64/arm64/riscv64/bare_metal)"