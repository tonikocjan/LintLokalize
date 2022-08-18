prefix ?= /usr/local
bindir = $(prefix)/bin
libdir = $(prefix)/lib

build:
	swift build -c release --disable-sandbox

install: build
	install ".build/release/LintLokalize" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/LintLokalize"

clean:
	rm -rf .build/
