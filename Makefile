# Container Performance Tools Makefile
# Variables
REGISTRY ?= quay.io
ORG ?= container-perf-tools
COMMIT_SHA := $(shell git rev-parse --short HEAD)
ARCH := $(shell uname -m)
BASE_VERSION ?= latest
VERSION := $(BASE_VERSION)-$(ARCH)

# All container images (default to all)
IMAGES ?= cyclictest hwlatdetect oslat rtla stress-ng dpdk-testpmd

# Default target
.DEFAULT_GOAL := help

# Help target
.PHONY: help
help: ## Show this help message
	@echo "Container Performance Tools Build System"
	@echo ""
	@echo "Current configuration:"
	@echo "  Architecture: $(ARCH)"
	@echo "  Base Version: $(BASE_VERSION)"
	@echo "  Full Version: $(VERSION)"
	@echo "  Registry: $(REGISTRY)"
	@echo "  Organization: $(ORG)"
	@echo "  Images: $(IMAGES)"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo "Single image build targets:"
	@for img in $(IMAGES); do \
		printf "  build-%-15s Build image $$img\n" $$img; \
	done
	@echo "Single image push targets:"
	@for img in $(IMAGES); do \
		printf "  push-%-15s Push image $$img\n" $$img; \
	done

# Build targets for individual images
.PHONY: build-%
build-%: ## Build a specific image by name
	@echo "Building $*..."
	@podman build \
		--build-arg COMMIT_SHA=$(COMMIT_SHA) \
		--build-arg VERSION=$(BASE_VERSION) \
		--build-arg ARCH=$(ARCH) \
		--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
		-f $*/Dockerfile \
		-t $(REGISTRY)/$(ORG)/$*:$(BASE_VERSION) \
		.

# Build all images
.PHONY: build-all
build-all: $(addprefix build-,$(IMAGES)) ## Build all images

# Push targets for individual images
.PHONY: push-%
push-%: ## Push a specific image by name
	@echo "Pushing $*..."
	@podman push $(REGISTRY)/$(ORG)/$*:$(BASE_VERSION)

.PHONY: push-all
push-all: $(addprefix push-,$(IMAGES)) ## Push all images

# Utility targets
.PHONY: clean
clean: ## Clean up images
	podman rmi $(REGISTRY)/$(ORG)/dpdk-testpmd:$(BASE_VERSION) || true
	podman rmi $(REGISTRY)/$(ORG)/cyclictest:$(BASE_VERSION) || true
	podman rmi $(REGISTRY)/$(ORG)/hwlatdetect:$(BASE_VERSION) || true
	podman rmi $(REGISTRY)/$(ORG)/oslat:$(BASE_VERSION) || true
	podman rmi $(REGISTRY)/$(ORG)/rtla:$(BASE_VERSION) || true
	podman rmi $(REGISTRY)/$(ORG)/stress-ng:$(BASE_VERSION) || true
	podman rmi $(REGISTRY)/$(ORG)/container-perf-tools:$(BASE_VERSION) || true

.PHONY: clean-all
clean-all: clean ## Clean up all images and dangling images
	podman system prune -f

# Architecture-specific targets
.PHONY: show-arch
show-arch: ## Show current architecture
	@echo "Current architecture: $(ARCH)"
	@echo "Full version tag: $(VERSION)"

.PHONY: build-multiarch
build-multiarch: ## Build for multiple architectures and create manifest
	@echo "Building multi-architecture images..."
	@for image in $(IMAGES); do \
		echo "Building multi-arch $$image..."; \
		echo "  Building amd64..."; \
		podman build --platform linux/amd64 \
			--build-arg COMMIT_SHA=$(COMMIT_SHA) \
			--build-arg VERSION=$(BASE_VERSION) \
			--build-arg ARCH=x86_64 \
			--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
			-f Dockerfile-$$image -t $(REGISTRY)/$(ORG)/$$image:$(BASE_VERSION)-amd64 .; \
		echo "  Building arm64..."; \
		podman build --platform linux/arm64 \
			--build-arg COMMIT_SHA=$(COMMIT_SHA) \
			--build-arg VERSION=$(BASE_VERSION) \
			--build-arg ARCH=aarch64 \
			--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
			-f Dockerfile-$$image -t $(REGISTRY)/$(ORG)/$$image:$(BASE_VERSION)-arm64 .; \
		echo "  Creating manifest for $$image..."; \
		podman manifest create $(REGISTRY)/$(ORG)/$$image:$(BASE_VERSION); \
		podman manifest add $(REGISTRY)/$(ORG)/$$image:$(BASE_VERSION) $(REGISTRY)/$(ORG)/$$image:$(BASE_VERSION)-amd64; \
		podman manifest add $(REGISTRY)/$(ORG)/$$image:$(BASE_VERSION) $(REGISTRY)/$(ORG)/$$image:$(BASE_VERSION)-arm64; \
	done

.PHONY: push-multiarch
push-multiarch: ## Push multi-architecture manifests (including images)
	@echo "Pushing multi-architecture manifests..."
	@for image in $(IMAGES); do \
		echo "Pushing manifest for $$image..."; \
		podman manifest push --all $(REGISTRY)/$(ORG)/$$image:$(BASE_VERSION) docker://$(REGISTRY)/$(ORG)/$$image:$(BASE_VERSION); \
	done

.PHONY: clean-multiarch
clean-multiarch: ## Clean up multi-architecture podman images
	@for image in $(IMAGES); do \
		echo "Removing $$image amd64 and arm64 images..."; \
		podman rmi $(REGISTRY)/$(ORG)/$$image:$(BASE_VERSION)-amd64; \
		podman rmi $(REGISTRY)/$(ORG)/$$image:$(BASE_VERSION)-arm64; \
		podman rmi $(REGISTRY)/$(ORG)/$$image:$(BASE_VERSION); \
	done
