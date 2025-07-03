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

# Build targets for individual images
.PHONY: build-dpdk-testpmd
build-dpdk-testpmd: ## Build dpdk-testpmd image
	podman build \
		--build-arg COMMIT_SHA=$(COMMIT_SHA) \
		--build-arg VERSION=$(BASE_VERSION) \
		--build-arg ARCH=$(ARCH) \
		--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
		-f Dockerfile-dpdk-testpmd \
		-t $(REGISTRY)/$(ORG)/dpdk-testpmd:$(BASE_VERSION) \
		.

.PHONY: build-cyclictest
build-cyclictest: ## Build cyclictest image
	podman build \
		--build-arg COMMIT_SHA=$(COMMIT_SHA) \
		--build-arg VERSION=$(BASE_VERSION) \
		--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
		-f Dockerfile-cyclictest \
		-t $(REGISTRY)/$(ORG)/cyclictest:$(BASE_VERSION) \
		.

.PHONY: build-hwlatdetect
build-hwlatdetect: ## Build hwlatdetect image
	podman build \
		--build-arg COMMIT_SHA=$(COMMIT_SHA) \
		--build-arg VERSION=$(BASE_VERSION) \
		--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
		-f Dockerfile-hwlatdetect \
		-t $(REGISTRY)/$(ORG)/hwlatdetect:$(BASE_VERSION) \
		.

.PHONY: build-oslat
build-oslat: ## Build oslat image
	podman build \
		--build-arg COMMIT_SHA=$(COMMIT_SHA) \
		--build-arg VERSION=$(BASE_VERSION) \
		--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
		-f Dockerfile-oslat \
		-t $(REGISTRY)/$(ORG)/oslat:$(BASE_VERSION) \
		.

.PHONY: build-rtla
build-rtla: ## Build rtla image
	podman build \
		--build-arg COMMIT_SHA=$(COMMIT_SHA) \
		--build-arg VERSION=$(BASE_VERSION) \
		--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
		-f Dockerfile-rtla \
		-t $(REGISTRY)/$(ORG)/rtla:$(BASE_VERSION) \
		.

.PHONY: build-stress-ng
build-stress-ng: ## Build stress-ng image
	podman build \
		--build-arg COMMIT_SHA=$(COMMIT_SHA) \
		--build-arg VERSION=$(BASE_VERSION) \
		--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
		-f Dockerfile-stress-ng \
		-t $(REGISTRY)/$(ORG)/stress-ng:$(BASE_VERSION) \
		.

# Build all images
.PHONY: build-all
build-all: $(addprefix build-,$(IMAGES)) ## Build all images

# Push targets
.PHONY: push-dpdk-testpmd
push-dpdk-testpmd: ## Push dpdk-testpmd image
	podman push $(REGISTRY)/$(ORG)/dpdk-testpmd:$(BASE_VERSION)

.PHONY: push-cyclictest
push-cyclictest: ## Push cyclictest image
	podman push $(REGISTRY)/$(ORG)/cyclictest:$(BASE_VERSION)

.PHONY: push-hwlatdetect
push-hwlatdetect: ## Push hwlatdetect image
	podman push $(REGISTRY)/$(ORG)/hwlatdetect:$(BASE_VERSION)

.PHONY: push-oslat
push-oslat: ## Push oslat image
	podman push $(REGISTRY)/$(ORG)/oslat:$(BASE_VERSION)

.PHONY: push-rtla
push-rtla: ## Push rtla image
	podman push $(REGISTRY)/$(ORG)/rtla:$(BASE_VERSION)

.PHONY: push-stress-ng
push-stress-ng: ## Push stress-ng image
	podman push $(REGISTRY)/$(ORG)/stress-ng:$(BASE_VERSION)

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
