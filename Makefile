SHELL=/bin/bash

export GNUMAKEFLAGS=--no-print-directory
.SHELLFLAGS = -o pipefail -c

all: compile

######################################################################
### compiling

release: pg-copy-ch
compile: pg-copy-ch-dev

BUILD_TARGET=
COMPILE_FLAGS=-Dstatic
DOCKER=docker run -t -u "`id -u`:`id -g`" -v $(PWD):/v -w /v --rm crystallang/crystal:1.6.1-alpine

.PHONY: build
build:
	@$(DOCKER) shards build $(COMPILE_FLAGS) --link-flags "-static" $(BUILD_TARGET) $(O)

.PHONY: pg-copy-ch-dev
pg-copy-ch-dev: BUILD_TARGET=pg-copy-ch-dev
pg-copy-ch-dev: build

.PHONY: pg-copy-ch
pg-copy-ch: BUILD_TARGET=--release pg-copy-ch
pg-copy-ch: build
	@md5sum bin/$@

.PHONY: console
console:
	@$(DOCKER) sh

install: bin/pg-copy-ch
	@cp -p $< /usr/local/bin/

clean:
	docker compose down -v --remove-orphans
	-$(DOCKER) rm -rf bin lib .shards .crystal

######################################################################
### testing

.PHONY: ci
ci: compile test

test: bin/pg-copy-ch-dev
	@docker compose run --rm test ./tests/run

#- PG_HOST=pg
#- CH_HOST=ch

######################################################################
### versioning

VERSION=
CURRENT_VERSION=$(shell git tag -l | sort -V | tail -1)
GUESSED_VERSION=$(shell git tag -l | sort -V | tail -1 | awk 'BEGIN { FS="." } { $$3++; } { printf "%d.%d.%d", $$1, $$2, $$3 }')

.PHONY : version
version:
	@if [ "$(VERSION)" = "" ]; then \
	  echo "ERROR: specify VERSION as bellow. (current: $(CURRENT_VERSION))";\
	  echo "  make version VERSION=$(GUESSED_VERSION)";\
	else \
	  sed -i -e 's/^version: .*/version: $(VERSION)/' shard.yml ;\
	  echo git commit -a -m "'$(COMMIT_MESSAGE)'" ;\
	  git commit -a -m 'version: $(VERSION)' ;\
	  git tag "v$(VERSION)" ;\
	fi

.PHONY : bump
bump:
	make version VERSION=$(GUESSED_VERSION) -s
