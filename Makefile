
PREFIX = $(HOME)/.local
BINDIR = $(PREFIX)/bin
INSTALL = /bin/install

all: bin/bar

bin/bar: *.cr
	shards build

.PHONY: clean
clean:
	rm bin/bar

.PHONY: install
install: bin/bar
	$(INSTALL) -m 0755 bin/bar "$(BINDIR)"

