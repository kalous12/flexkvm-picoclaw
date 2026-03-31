#
# Picoclaw ARMv7 Cross-Compilation Makefile
# Target Platform: RV1106 (arm-rockchip830-linux-uclibcgnueabihf)
# Tag: v0.2.3
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

# Picoclaw version (use latest commit for newest features)
PICOCLAW_TAG := c36b06a
PICOCLAW_SRC := $(CURDIR)/picoclaw

# Number of parallel jobs
JOBS ?= $(shell nproc)

# Go version (from picoclaw/go.mod)
GO_VERSION := 1.23

.PHONY: all clean clone info help build build-launcher

all: info clone build build-launcher install
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

	@# Apply patches: add ARM32 (arm) support to feishu channel
	@echo "Patching feishu channel for ARM32 support..."
	@cd $(PICOCLAW_SRC)/pkg/channels/feishu && \
		sed -i 's/amd64 || arm64 || riscv64 || mips64 || ppc64/amd64 || arm64 || arm || riscv64 || mips64 || ppc64/' feishu_64.go && \
		rm -f feishu_32.go

	@# Override onboard workspace with flexkvm custom configuration
	@echo "Overriding onboard workspace with flexkvm config..."
	@cp -rf $(CURDIR)/workspace/* $(PICOCLAW_SRC)/cmd/picoclaw/internal/onboard/workspace/

	@# Patch defaults: allow read outside workspace
	@echo "Patching default config: allow_read_outside_workspace=true..."
	@sed -i '/RestrictToWorkspace:.*true,/a\					AllowReadOutsideWorkspace:       true,' $(PICOCLAW_SRC)/pkg/config/defaults.go

	@# Apply patch: add read_image tool for FlexKVM
	@echo "Applying patch: read_image tool..."
	@cd $(PICOCLAW_SRC) && git apply $(CURDIR)/patch/0003-add-read-image-tool.patch 2>/dev/null || echo "  patch already applied or failed"

build: clone
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
			-tags "goolm,stdjson" \
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

	@# Build frontend first
	@echo "Building frontend..."
	@cd $(PICOCLAW_SRC)/web && \
		if [ ! -d frontend/node_modules ] || \
		   [ frontend/package.json -nt frontend/node_modules ] || \
		   [ frontend/pnpm-lock.yaml -nt frontend/node_modules ]; then \
			cd frontend && pnpm install --frozen-lockfile; \
		fi && \
		pnpm build:backend

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
			-tags "goolm,stdjson" \
			-ldflags="-s -w -buildid= -compressdwarf=true -extldflags=-s" \
			-gcflags="all=-l -B" \
			-trimpath \
			-o $(CURDIR)/$(PKG_BIN)/picoclaw-launcher \
			./web/backend \
	)

	@$(CROSS_COMPILE)strip -s $(PKG_BIN)/picoclaw-launcher 2>/dev/null || true

install: build build-launcher
	@echo "Binaries ready in $(OUTPUT_DIR)/"

# Compress with upx
	@echo ""
	@echo "Compressing with upx..."
	@which upx >/dev/null 2>&1 && upx --best --lzma $(OUTPUT_DIR)/picoclaw $(OUTPUT_DIR)/picoclaw-launcher || echo "  upx not found, skipping compression"

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
