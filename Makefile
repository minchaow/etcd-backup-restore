# Copyright 2018 The Gardener Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

VCS                                := github.com
ORGANIZATION                       := gardener
PROJECT                            := etcd-backup-restore
REPOSITORY                         := $(VCS)/$(ORGANIZATION)/$(PROJECT)
VERSION                            := 0.1.0
LD_FLAGS                           := "-w -X $(REPOSITORY)/pkg/version.Version=$(VERSION)"
PACKAGES                           := $(shell go list ./... | grep -vE '/vendor/')
LINT_FOLDERS                       := $(shell echo $(PACKAGES) | sed "s|$(REPOSITORY)|.|g")
REGISTRY                           := registry.hub.docker.com/gardener/etcdbr
BACKUP_IMAGE_REPOSITORY		       := $(REGISTRY)/etcd-backup
BACKUP_IMAGE_TAG          		   := $(VERSION)

BUILD_DIR        := build
BIN_DIR          := bin
GOBIN            := $(PWD)/$(BIN_DIR)
GO_EXTRA_FLAGS   := -v
PATH             := $(GOBIN):$(PATH)
USER             := $(shell id -u -n)

export PATH
export GOBIN

.PHONY: backup-dev
dev: 
	@go build -o $(BIN_DIR)/etcd-backup $(GO_EXTRA_FLAGS) -ldflags $(LD_FLAGS) cmd/snapshot/main.go
	
.PHONY: verify
verify: vet fmt lint

.PHONY: revendor
revendor:
	@dep ensure -update

.PHONY: build
build: build-backup 

.PHONY: build-backup
build-backup: 
	@env GOOS=linux GOARCH=amd64 go build -o $(BIN_DIR)/linux-amd64/etcd-backup $(GO_EXTRA_FLAGS) -ldflags $(LD_FLAGS) cmd/snapshot/main.go

.PHONY: docker-image-backup
docker-image-backup: 
	@if [[ ! -f $(BIN_DIR)/linux-amd64/etcd-backup ]]; then echo "No binary found. Please run 'make docker-build'"; false; fi
	@docker build -t $(BACKUP_IMAGE_REPOSITORY):$(BACKUP_IMAGE_TAG) -f $(BUILD_DIR)/etcd-backup/Dockerfile --rm .

.PHONY: docker-push-backup
docker-push-backup:
	@if ! docker images $(BACKUP_IMAGE_REPOSITORY) | awk '{ print $$2 }' | grep -q -F $(BACKUP_IMAGE_TAG); then echo "$(BACKUP_IMAGE_REPOSITORY) version $(BACKUP_IMAGE_TAG) is not yet built. Please run 'make backup-docker-image'"; false; fi
	@docker push $(BACKUP_IMAGE_REPOSITORY):$(BACKUP_IMAGE_TAG)

.PHONY: clean
clean:
	@rm -rf $(BIN_DIR)/

.PHONY: fmt
fmt:
	@go fmt $(PACKAGES)

.PHONY: vet
vet:
	@go vet $(PACKAGES)

.PHONY: lint
lint:
	@golint  --set_exit_status $(LINT_FOLDERS)