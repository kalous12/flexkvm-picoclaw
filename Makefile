#
# Picoclaw ARMv7 Cross-Compilation Makefile
# Target Platform: RV1106 (arm-rockchip830-linux-uclibcgnueabihf)
# Tag: v0.2.1
#

SHELL:=/bin/bash
export LC_ALL=C

# Build output configuration
PKG_NAME := picoclaw
PKG_BIN ?= out
OUTPUT_DIR := $(PKG_BIN)
CURRENT_DIR := $(shell pwd)

# Toolchain settings (use CROSS_COMPILE from environment or default)
CROSS_COMPILE ?= arm-rockchip830-linux-uclibcgnueabihf-
CROSS_CC := $(CROSS_COMPILE)gcc
CROSS_CXX := $(CROSS_COMPILE)g++

# Picoclaw version
PICOCLAW_TAG := v0.2.1
PICOCLAW_SRC := $(CURDIR)/picoclaw

# Number of parallel jobs
JOBS ?= $(shell nproc)

# Go version (from picoclaw/go.mod)
GO_VERSION := 1.23

.PHONY: all clean clone info help build build-launcher generate

all: info clone build install
	@echo "Build $(PKG_NAME) done"

info:
	@echo "=========================================="
	@echo "Picoclaw ARMv7 Cross-Compilation"
	@echo "=========================================="
	@echo "Version: $(PICOCLAW_TAG)"
	@echo "Toolchain: $(CROSS_CC)"
	@echo "Source: $(PICOCLAW_SRC)"
	@echo "Output Dir: $(OUTPUT_DIR)"
	@echo "=========================================="

clone:
	@echo "Initializing/Updating picoclaw submodule $(PICOCLAW_TAG)..."
	@git submodule update --init --force picoclaw
	@cd $(PICOCLAW_SRC) && git checkout $(PICOCLAW_TAG) 2>/dev/null || true

generate:
	@echo "Running go generate..."
	@cd $(PICOCLAW_SRC) && \
		rm -rf ./cmd/picoclaw/workspace 2>/dev/null || true && \
		go generate ./...

build: clone generate
	@echo "Building picoclaw..."
	@mkdir -p $(PKG_BIN)

	@( \
		export CGO_ENABLED=1 && \
		export GOOS=linux && \
		export GOARCH=arm && \
		export GOARM=7 && \
		export CC=$(CROSS_CC) && \
		export CXX=$(CROSS_CXX) && \
		export CGO_LDFLAGS="-static -lpthread -lm" && \
		cd $(PICOCLAW_SRC) && \
		GOPROXY=https://goproxy.cn,direct go build \
			-ldflags="-s -w -buildid= -compressdwarf=true -extldflags=-s" \
			-gcflags="all=-l -B" \
			-trimpath \
			-o $(CURDIR)/$(PKG_BIN)/picoclaw \
			./cmd/picoclaw \
	)

	@$(CROSS_COMPILE)strip -s $(PKG_BIN)/picoclaw 2>/dev/null || true

build-launcher: clone
	@echo "Building picoclaw-launcher..."
	@mkdir -p $(PKG_BIN)

	@if [ ! -f $(PICOCLAW_SRC)/web/backend/dist/index.html ]; then \
		echo "Frontend not built, skipping launcher build"; \
	fi

	@( \
		export CGO_ENABLED=1 && \
		export GOOS=linux && \
		export GOARCH=arm && \
		export GOARM=7 && \
		export CC=$(CROSS_CC) && \
		export CXX=$(CROSS_CXX) && \
		export CGO_LDFLAGS="-static -lpthread -lm" && \
		cd $(PICOCLAW_SRC) && \
		GOPROXY=https://goproxy.cn,direct go build \
			-ldflags="-s -w -buildid=" \
			-trimpath \
			-o $(CURDIR)/$(PKG_BIN)/picoclaw-launcher \
			./web/backend \
	)

install: build
	@echo "Binaries ready in $(OUTPUT_DIR)/"

# Compress with upx
	@echo ""
	@echo "Compressing with upx..."
	@which upx >/dev/null 2>&1 && upx --best --lzma $(OUTPUT_DIR)/picoclaw || echo "  upx not found, skipping compression"

	@echo ""
	@echo "Installed files:"
	@ls -lh $(OUTPUT_DIR)/

clean:
	@if [ -d "$(PICOCLAW_SRC)" ]; then \
		cd $(PICOCLAW_SRC) && git checkout . && git clean -fd; \
	fi
	rm -rf $(PKG_BIN)
	@echo "Clean done"

help:
	@echo "Picoclaw Build Targets:"
	@echo ""
	@echo "  make               - Build picoclaw"
	@echo "  make clone         - Clone/update picoclaw source"
	@echo "  make build         - Build only"
	@echo "  make build-launcher - Build picoclaw-launcher (web console)"
	@echo "  make install       - Install binaries"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make help          - Show this help"
