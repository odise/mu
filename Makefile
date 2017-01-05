ORG := stelligent
PACKAGE := mu
TARGET_OS := linux windows darwin

# don't change
BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
IS_MASTER := $(filter master, $(BRANCH))
VERSION := $(shell cat VERSION)$(if $(IS_MASTER),,-$(BRANCH))
ARCH := $(shell go env GOARCH)
BUILD_FILES = $(foreach os, $(TARGET_OS), release/$(PACKAGE)-$(os)-$(ARCH))
UPLOAD_FILES = $(foreach os, $(TARGET_OS), $(PACKAGE)-$(os)-$(ARCH))
GOLDFLAGS = "-X main.version=$(VERSION)"
TAG_VERSION = v$(VERSION)

default: build

setup:
	@echo "=== preparing ==="
	mkdir -p release
	go get -u "github.com/golang/lint/golint"
	go get -u "github.com/aktau/github-release"
	go get -t -d -v ./...

lint: setup
	@echo "=== linting ==="
	go vet ./...
	golint ./...

test: lint
	@echo "=== testing ==="
	go test ./...

build: test $(BUILD_FILES)

$(BUILD_FILES): setup
	@echo "=== building $@ ==="
	GOOS=$(word 2,$(subst -, ,$@)) GOARCH=$(word 3,$(subst -, ,$@)) go build -ldflags=$(GOLDFLAGS) -o '$@'

pre-release-clean:
ifeq ($(IS_MASTER),)
	@echo "=== clearing old release $(VERSION) ==="
	github-release delete -u $(ORG) -r $(PACKAGE) -t $(TAG_VERSION)
	git push --delete origin $(TAG_VERSION)
endif

pre-release-create: pre-release-clean #clean build
	@echo "=== creating pre-release $(VERSION) ==="
	git tag -f $(TAG_VERSION)
	git push origin $(TAG_VERSION)
	github-release release -u $(ORG) -r $(PACKAGE) -t $(TAG_VERSION) -p

$(TARGET_OS): pre-release-create
	@echo "=== uploading $@ ==="
	github-release upload -u $(ORG) -r $(PACKAGE) -t $(TAG_VERSION) -n "$(PACKAGE)-$@-$(ARCH)" -f "release/$(PACKAGE)-$@-$(ARCH)"

pre-release: $(TARGET_OS)

release: pre-release
ifneq ($(IS_MASTER),)
    @echo "=== releasing $(VERSION) ==="
    github-release edit -u $(ORG) -r $(PACKAGE) -t $(TAG_VERSION)
endif

clean:
	@echo "=== cleaning ==="
	rm -rf release

.PHONY: default lint test build setup clean pre-release-clean pre-release-create pre-release release $(UPLOAD_FILES) $(TARGET_OS)
