EMACS ?= emacs
BATCH = $(EMACS) -Q --batch -L .

.PHONY: all compile test test-fast clean

all: compile test

compile:
	$(BATCH) --eval '(setq byte-compile-error-on-warn t)' \
	  -f batch-byte-compile scribble-minor.el

# All tests, including the ones that run raco.
test:
	$(BATCH) -l test/scribble-minor-test.el -f ert-run-tests-batch-and-exit

# Skip tests tagged :expensive (those running raco).
test-fast:
	$(BATCH) -l test/scribble-minor-test.el \
	  --eval '(ert-run-tests-batch-and-exit (quote (not (tag :expensive))))'

clean:
	rm -f *.elc test/*.elc
