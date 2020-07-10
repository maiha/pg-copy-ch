export GNUMAKEFLAGS=--no-print-directory

TESTS=$(shell find ./tests  -maxdepth 1 -name '*_test.sh' | sort)

.PHONY: test
test: unit_test

unit_test:
	@echo $(TESTS)
	@for x in $(TESTS); do \
	  echo "----------------------------------------------------------------------"; \
	  echo "-- `basename $$x`"; \
	  echo "----------------------------------------------------------------------"; \
	  ./$$x || exit 255; \
	done

