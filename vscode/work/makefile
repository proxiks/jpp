CC = gcc
CXX = g++
CFLAGS = -Wall -Wextra -O2 -std=c99
CXXFLAGS = -Wall -Wextra -O2 -std=c++17

PREFIX = /usr/local
BINDIR = $(PREFIX)/bin
INCLUDEDIR = $(PREFIX)/include/jpp

# Directories
SRC_DIR = src
BUILD_DIR = build
EXAMPLES_DIR = examples
EDITOR_DIR = editors

# Targets
.PHONY: all clean install uninstall test docs

all: compiler editors

compiler:
	@echo "Building J++ compiler..."
	@mkdir -p $(BUILD_DIR)
	# TODO: Add compiler source files
	# $(CXX) $(CXXFLAGS) -o $(BUILD_DIR)/jpp $(SRC_DIR)/*.cpp

editors:
	@echo "Building editor support..."
	cd $(EDITOR_DIR)/vscode && npm install && npm run compile
	cd $(EDITOR_DIR)/tree-sitter && npm install && npm run generate

test:
	@echo "Running tests..."
	# TODO: Add test suite
	# ./$(BUILD_DIR)/jpp --test

install:
	@echo "Installing J++..."
	install -d $(BINDIR)
	install -d $(INCLUDEDIR)
	# install -m 755 $(BUILD_DIR)/jpp $(BINDIR)/jpp
	cp -r stdlib/* $(INCLUDEDIR)/
	cp -r kernel/* $(INCLUDEDIR)/

uninstall:
	@echo "Uninstalling J++..."
	rm -f $(BINDIR)/jpp
	rm -rf $(INCLUDEDIR)

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -rf $(EDITOR_DIR)/vscode/node_modules
	rm -rf $(EDITOR_DIR)/vscode/out
	rm -rf $(EDITOR_DIR)/tree-sitter/node_modules
	rm -rf $(EDITOR_DIR)/tree-sitter/src

docs:
	@echo "Building documentation..."
	# TODO: Add doc generation

# Example programs
examples:
	@echo "Building example programs..."
	# $(BUILD_DIR)/jpp $(EXAMPLES_DIR)/hello.jpp -o $(BUILD_DIR)/hello
	# $(BUILD_DIR)/jpp $(EXAMPLES_DIR)/kernel_boot.jpp -o $(BUILD_DIR)/kernel_boot