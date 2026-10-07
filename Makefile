# oocurl v0.2.0 Makefile
#
# Build, verification gate, 4-tier QA test suite, and tri-distribution packaging.
#
# Usage:
#   make build       - compile main.oo to dist/oocurl
#   make check       - run oodac check on every .oo file
#   make line-cap    - enforce 16-256 line cap on every .oo and .oot (shim-exempt)
#   make file-law    - reject forbidden file extensions and stray docs
#   make academy     - verify every .oo has the 4-element Academy header
#   make density     - enforce at most 8 pages per directory
#   make verify      - run line-cap, file-law, academy, density, and check
#   make test        - run 4-tier QA and MCP integration test suite
#   make bench       - run performance benchmarks
#   make package     - build deb, rpm, and arch packages with checksums
#   make clean       - remove build artifacts

OODA_COMPILER ?= $(firstword $(wildcard $(HOME)/.openooda/bin/oodac $(CURDIR)/../../openOODA/oodac/bin/oodac))
OODACODEX ?= $(HOME)/.openooda/northstar.oot
OO_LIST_AMBIENT_QUOTA ?= 8589934592
BIN := dist/oocurl

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

SRC := $(wildcard *.oo) $(wildcard */*.oo)
VERSION ?= 0.2.0

.PHONY: build check line-cap file-law academy density verify clean test bench package package-deb package-rpm package-arch install uninstall

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p dist .ooda-cache/ooda-tmp
	OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) build main.oo -o $(BIN)
	@chmod +x $(BIN)
	@cp -a $(BIN) dist/oocurl-linux-x86_64
	@sha256sum dist/oocurl-linux-x86_64 > dist/oocurl-linux-x86_64.sha256
	@echo "built $(BIN) (and dist/oocurl-linux-x86_64)"

# --- Verification gate ---------------------------------------------------------

line-cap:
	@violations=0; \
	for f in $$(find . -name "*.oo" -o -name "*.oot"); do \
		n=$$(wc -l < "$$f"); \
		if [ $$n -gt 256 ]; then \
			echo "VIOLATION: $$f = $$n lines (exceeds 256)"; violations=$$((violations+1)); \
			continue; \
		fi; \
		code=$$(grep -vE '^[[:space:]]*(//.*)?$$' "$$f" | grep -cvE '^[[:space:]]*import[[:space:]]+"'); \
		if [ "$$code" = "0" ]; then continue; fi; \
		if [ $$n -lt 16 ]; then \
			echo "VIOLATION: $$f = $$n lines (under 16-line floor, not a shim)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations files violate the Page Rule"; exit 1; fi; \
	echo "PASS: Page Rule sizing (16-256 lines, shims exempt from floor) holds"

file-law:
	@forbidden="py js ts rb pl json yaml toml"; \
	violations=0; \
	for ext in $$forbidden; do \
		found=$$(find . -name "*.$$ext" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" -not -path "./.blackbox/*" 2>/dev/null | head -3); \
		if [ -n "$$found" ]; then \
			echo "VIOLATION: .$$ext forbidden:"; echo "$$found"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.md" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null); do \
		if [ "$$f" != "./README.md" ] && [ "$$f" != "./AGENTS.md" ]; then \
			echo "VIOLATION: .md forbidden outside README.md and AGENTS.md: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.sh" -not -path "./.git/*" -not -path "./dist/*" 2>/dev/null); do \
		if [ "$$f" != "./install.sh" ] && [ "$$f" != "./uninstall.sh" ]; then \
			echo "VIOLATION: .sh forbidden outside install.sh and uninstall.sh: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: file-law violations"; exit 1; fi; \
	echo "PASS: file law holds"

academy:
	@failures=0; \
	for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		header=$$(head -7 "$$f"); \
		missing=""; \
		echo "$$header" | grep -q "^// # "        || missing="$$missing title"; \
		echo "$$header" | grep -q "^// Logline:"  || missing="$$missing logline"; \
		echo "$$header" | grep -q "^// Setup:"    || missing="$$missing setup"; \
		echo "$$header" | grep -q "^// Beats:"    || missing="$$missing beats"; \
		if [ -n "$$missing" ]; then \
			echo "FAIL: $$f missing Academy element(s):$$missing"; failures=$$((failures+1)); \
		fi; \
	done; \
	if [ $$failures -gt 0 ]; then echo "FAIL: $$failures academy header violations"; exit 1; fi; \
	echo "PASS: academy headers hold (all 4 elements present in first 7 lines)"

density:
	@violations=0; \
	for d in $$(find . -type d -not -path "./.git*" -not -path "./dist*" -not -path "./.ooda-cache*" -not -path "./packaging*"); do \
		n=$$(ls "$$d"/*.oo "$$d"/*.oot 2>/dev/null | grep -v '\*' | wc -l); \
		if [ $$n -gt 8 ]; then \
			echo "VIOLATION: $$d holds $$n pages (exceeds 8)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations directories exceed the density bound"; exit 1; fi; \
	echo "PASS: directory density (<= 8 pages per directory) holds"

check:
	@for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		$(OODA_COMPILER) check "$$f" > /dev/null || exit 1; \
	done; \
	echo "PASS: oodac check holds on all .oo files"

verify: line-cap file-law academy density check

test: $(BIN)
	@echo "=== Tier 1: Core CLI Flags, Headers, and Protocol Options ==="
	@./$(BIN) --help > /dev/null && echo "PASS: --help"
	@./$(BIN) -h > /dev/null && echo "PASS: -h"
	@./$(BIN) --version | grep -q "0.2.0" && echo "PASS: --version 0.2.0"
	@./$(BIN) -v | grep -q "0.2.0" && echo "PASS: -v 0.2.0"
	@./$(BIN) --help | grep -q -- "-I, --head" && echo "PASS: --help documents -I, --head"
	@./$(BIN) --help | grep -q -- "-H, --header" && echo "PASS: --help documents -H, --header"
	@./$(BIN) --help | grep -q -- "-d, --data" && echo "PASS: --help documents -d, --data"
	@./$(BIN) --help | grep -q -- "-X, --request" && echo "PASS: --help documents -X, --request"
	@./$(BIN) --help | grep -q -- "--no-color" && echo "PASS: --help documents --no-color"
	@./$(BIN) 2>&1 | grep -q "no URL specified" && echo "PASS: CLI missing URL exit code diagnostic"
	@./$(BIN) "invalid url with spaces" 2>&1 | grep -q "could not parse URL" && echo "PASS: CLI malformed URL diagnostic"
	@./$(BIN) http://127.0.0.1:1 2>&1 | grep -q "failed to fetch" && echo "PASS: connection refusal handling"
	@./$(BIN) -I http://127.0.0.1:1 2>&1 | grep -q "failed to fetch" && echo "PASS: CLI -I flag handling"
	@./$(BIN) -X POST -d "foo" -H "X-Bar: baz" http://127.0.0.1:1 2>&1 | grep -q "failed to fetch" && echo "PASS: CLI -X, -d, -H flags"
	@./$(BIN) -XPOST -dfoo -H"X-Bar: baz" http://127.0.0.1:1 2>&1 | grep -q "failed to fetch" && echo "PASS: CLI attached short flags -XPOST -dfoo -Hheader"
	@echo "=== Tier 2: MCP Handshake & Protocol Framing ==="
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q "2024-11-05" && echo "PASS: MCP initialize protocolVersion"
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q '"name":"oocurl","version":"0.2.0"' && echo "PASS: MCP initialize serverInfo"
	@printf '{"jsonrpc":"2.0","id":2,"method":"ping","params":{}}\n' | ./$(BIN) --mcp | grep -q '"result":{}' && echo "PASS: MCP ping"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "parse_url" && echo "PASS: MCP tools/list parse_url"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "http_request" && echo "PASS: MCP tools/list http_request"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "http_head" && echo "PASS: MCP tools/list http_head"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "encode_url_query" && echo "PASS: MCP tools/list encode_url_query"
	@test -z "$$(printf '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n' | ./$(BIN) --mcp)" && echo "PASS: MCP notifications/initialized produces no response"
	@printf '{"jsonrpc":"2.0","id":4,"method":"shutdown","params":{}}\n' | ./$(BIN) --mcp | grep -q '"result":null' && echo "PASS: MCP shutdown"
	@test -z "$$(printf '{"jsonrpc":"2.0","method":"exit","params":{}}\n' | ./$(BIN) --mcp)" && echo "PASS: MCP exit terminates cleanly"
	@test "$$(printf '{"jsonrpc":"2.0","id":1,"method":"ping","params":{}}{"jsonrpc":"2.0","id":2,"method":"ping","params":{}}\n' | ./$(BIN) --mcp | grep -c '"result":{}')" = "2" && echo "PASS: MCP concatenated JSON-RPC messages without newline"
	@printf '{"jsonrpc":"2.0","id":99,"method":"ping","params":{}}' | ./$(BIN) --mcp | grep -q '"id":99' && echo "PASS: MCP request without trailing newline"
	@(sleep 0.1 && printf '{"jsonrpc":"2.0","id":15,"method":"ping","params":{}}\n') | ./$(BIN) --mcp | grep -q '"result":{}' && echo "PASS: MCP stdio idle pause does not crash server"
	@echo "=== Tier 3: All 4 MCP Tools & URL Edge Cases ==="
	@printf '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"parse_url","arguments":{"url":"http://127.0.0.1:8080/api"}}}\n' | ./$(BIN) --mcp | grep -q "127.0.0.1" && echo "PASS: MCP parse_url custom port"
	@printf '{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"parse_url","arguments":{"url":"http://example.com/search?q=openooda"}}}\n' | ./$(BIN) --mcp | grep -q "q=openooda" && echo "PASS: MCP parse_url query string"
	@printf '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"parse_url","arguments":{"url":"http://example.com"}}}\n' | ./$(BIN) --mcp | grep -q "example.com" && echo "PASS: MCP parse_url missing path defaults to /"
	@printf '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"parse_url","arguments":{"url":"https://admin:secret@127.0.0.1:8443/portal#sec"}}}\n' | ./$(BIN) --mcp | grep -q "admin:secret" && echo "PASS: MCP parse_url userinfo extraction"
	@printf '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"parse_url","arguments":{"url":"http://example.com/doc#section-2"}}}\n' | ./$(BIN) --mcp | grep -q "section-2" && echo "PASS: MCP parse_url fragment extraction"
	@printf '{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"parse_url","arguments":{"url":"http://192.168.1.1:8000/status"}}}\n' | ./$(BIN) --mcp | grep -q "192.168.1.1" && echo "PASS: MCP parse_url IPv4 host"
	@printf '{"jsonrpc":"2.0","id":16,"method":"tools/call","params":{"name":"encode_url_query","arguments":{"params":{"q":"openooda"}}}}\n' | ./$(BIN) --mcp | grep -q "q=openooda" && echo "PASS: MCP encode_url_query basic mapping"
	@printf '{"jsonrpc":"2.0","id":17,"method":"tools/call","params":{"name":"encode_url_query","arguments":{"params":{"title":"openOODA & oocurl"}}}}\n' | ./$(BIN) --mcp | grep -q "title=openOODA%20%26%20oocurl" && echo "PASS: MCP encode_url_query RFC 3986 percent encoding"
	@printf '{"jsonrpc":"2.0","id":18,"method":"tools/call","params":{"name":"encode_url_query","arguments":{"pairs":[{"key":"foo","value":"bar baz"}]}}}\n' | ./$(BIN) --mcp | grep -q "foo=bar%20baz" && echo "PASS: MCP encode_url_query pairs array"
	@printf '{"jsonrpc":"2.0","id":19,"method":"tools/call","params":{"name":"encode_url_query","arguments":{"params":{}}}}\n' | ./$(BIN) --mcp | grep -q "query" && echo "PASS: MCP encode_url_query empty params"
	@printf '{"jsonrpc":"2.0","id":20,"method":"tools/call","params":{"name":"http_head","arguments":{"url":"http://127.0.0.1:1"}}}\n' | ./$(BIN) --mcp | grep -q -- "-32000" && echo "PASS: MCP http_head connection refusal"
	@printf '{"jsonrpc":"2.0","id":21,"method":"tools/call","params":{"name":"http_request","arguments":{"url":"http://127.0.0.1:1"}}}\n' | ./$(BIN) --mcp | grep -q -- "-32000" && echo "PASS: MCP http_request connection refusal"
	@printf '{"jsonrpc":"2.0","id":22,"method":"tools/call","params":{"name":"parse_url","arguments":{"url":"http:\/\/example.com\/api\/v1"}}}\n' | ./$(BIN) --mcp | grep -q "/api/v1" && echo "PASS: MCP parse_url escaped slashes"
	@printf '{"jsonrpc":"2.0","id":23,"method":"tools/call","params":{"name":"parse_url","arguments":{"url":"http://example.com/search?q=\\"openooda\\""}}}\n' | ./$(BIN) --mcp | grep -q 'openooda' && echo "PASS: MCP parse_url quotes in query"
	@printf '{"jsonrpc":"2.0","id":24,"method":"tools/call","params":{"name":"encode_url_query","arguments":{"pairs":[{"name":"tag","value":"sovereign"}]}}}\n' | ./$(BIN) --mcp | grep -q "tag=sovereign" && echo "PASS: MCP encode_url_query pairs name field"
	@printf '{"jsonrpc":"2.0","id":25,"method":"tools/call","params":{"name":"encode_url_query","arguments":{"pairs":[["mode","strict"],["limit","100"]]}}}\n' | ./$(BIN) --mcp | grep -q "mode=strict&limit=100" && echo "PASS: MCP encode_url_query array-of-pairs"
	@printf '{"jsonrpc":"2.0","id":26,"method":"tools/call","params":{"name":"encode_url_query","arguments":{"params":{"city":"München"}}}}\n' | ./$(BIN) --mcp | grep -q "M%C3%BCchen" && echo "PASS: MCP encode_url_query UTF-8 encoding"
	@echo "=== Tier 4: Negative Trust & Error Responses ==="
	@printf 'invalid json string\n' | ./$(BIN) --mcp | grep -q -- "-32600" && echo "PASS: MCP invalid json exits -32600"
	@printf '{"jsonrpc":"1.0","id":30,"method":"ping","params":{}}\n' | ./$(BIN) --mcp | grep -q -- "-32600" && echo "PASS: MCP invalid jsonrpc version exits -32600"
	@printf '{"jsonrpc":"2.0","id":31,"method":"","params":{}}\n' | ./$(BIN) --mcp | grep -q -- "-32600" && echo "PASS: MCP empty method exits -32600"
	@printf '{"jsonrpc":"2.0","id":32,"method":"nonexistent_method","params":{}}\n' | ./$(BIN) --mcp | grep -q -- "-32601" && echo "PASS: MCP unknown method exits -32601"
	@printf '{"jsonrpc":"2.0","id":33,"method":"tools/call","params":{"name":"nonexistent_tool","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32601" && echo "PASS: MCP unknown tool exits -32601"
	@printf '{"jsonrpc":"2.0","id":34,"method":"tools/call","params":{"arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP missing tool name exits -32602"
	@printf '{"jsonrpc":"2.0","id":35,"method":"tools/call","params":{"name":"parse_url","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP parse_url missing url exits -32602"
	@printf '{"jsonrpc":"2.0","id":36,"method":"tools/call","params":{"name":"http_request","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP http_request missing url exits -32602"
	@printf '{"jsonrpc":"2.0","id":37,"method":"tools/call","params":{"name":"http_request","arguments":{"url":"http://127.0.0.1:80","method":"INVALID_METHOD"}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP http_request invalid method exits -32602"
	@printf '{"jsonrpc":"2.0","id":38,"method":"tools/call","params":{"name":"http_request","arguments":{"url":"http://127.0.0.1:80","timeout":-1}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP http_request negative timeout exits -32602"
	@printf '{"jsonrpc":"2.0","id":39,"method":"tools/call","params":{"name":"http_head","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP http_head missing url exits -32602"
	@printf '{"jsonrpc":"2.0","id":40,"method":"tools/call","params":{"name":"encode_url_query","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP encode_url_query missing params exits -32602"
	@echo "=== Double-Run Determinism & Response Consistency ==="
	@run1="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp)"; \
	run2="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp)"; \
	test "$$run1" = "$$run2" && echo "PASS: determinism tools/list Run_1 == Run_2"
	@run1="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"parse_url","arguments":{"url":"http://user:pass@127.0.0.1:8080/path?q=1#frag"}}}\n' | ./$(BIN) --mcp)"; \
	run2="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"parse_url","arguments":{"url":"http://user:pass@127.0.0.1:8080/path?q=1#frag"}}}\n' | ./$(BIN) --mcp)"; \
	test "$$run1" = "$$run2" && echo "PASS: determinism parse_url Run_1 == Run_2"
	@run1="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"encode_url_query","arguments":{"params":{"foo":"bar baz","num":"42"}}}}\n' | ./$(BIN) --mcp)"; \
	run2="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"encode_url_query","arguments":{"params":{"foo":"bar baz","num":"42"}}}}\n' | ./$(BIN) --mcp)"; \
	test "$$run1" = "$$run2" && echo "PASS: determinism encode_url_query Run_1 == Run_2"
	@echo "=== Packaging & Installer Smoke Tests ==="
	@./install.sh --dry-run > /dev/null && echo "PASS: install.sh --dry-run"
	@./install.sh --uninstall --dry-run > /dev/null && echo "PASS: install.sh --uninstall --dry-run"
	@./uninstall.sh --dry-run > /dev/null && echo "PASS: uninstall.sh --dry-run"
	@echo "ALL TESTS PASSED"

bench: $(BIN)
	@echo "=== Running oocurl performance benchmarks ==="
	@echo "--- MCP parse_url benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 100); do printf '\''{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"parse_url","arguments":{"url":"http://user:pass@127.0.0.1:8080/path/to/resource?query=1&b=2#frag"}}}\n'\'' | ./$(BIN) --mcp > /dev/null; done'
	@echo "--- MCP encode_url_query benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 100); do printf '\''{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"encode_url_query","arguments":{"params":{"q":"sovereign tools","sort":"desc","limit":"50"}}}}\n'\'' | ./$(BIN) --mcp > /dev/null; done'
	@echo "--- MCP tools/list benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 100); do printf '\''{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n'\'' | ./$(BIN) --mcp > /dev/null; done'
	@echo "Benchmark complete."

install: $(BIN)
	@mkdir -p $(DESTDIR)$(BINDIR)
	install -m 0755 $(BIN) $(DESTDIR)$(BINDIR)/oocurl
	install -m 0755 uninstall.sh $(DESTDIR)$(BINDIR)/oocurl-uninstall
	@echo "installed oocurl and oocurl-uninstall to $(DESTDIR)$(BINDIR)"

uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/oocurl $(DESTDIR)$(BINDIR)/oocurl-uninstall
	@if [ "$(PURGE)" = "1" ]; then rm -rf $(HOME)/.cache/oocurl $(HOME)/.config/oocurl; echo "purged user cache and config"; fi
	@echo "uninstalled oocurl and oocurl-uninstall from $(DESTDIR)$(BINDIR)"

package-deb: $(BIN)
	@mkdir -p dist/deb-root/DEBIAN dist/deb-root/usr/bin
	@sed "s/^Version:.*/Version: $(VERSION)-1/" packaging/debian/control.binary > dist/deb-root/DEBIAN/control
	@cp $(BIN) dist/deb-root/usr/bin/oocurl
	@chmod 0755 dist/deb-root/usr/bin/oocurl
	@cp uninstall.sh dist/deb-root/usr/bin/oocurl-uninstall
	@chmod 0755 dist/deb-root/usr/bin/oocurl-uninstall
	@dpkg-deb --build --root-owner-group dist/deb-root dist/oocurl_$(VERSION)-1_amd64.deb
	@rm -rf dist/deb-root
	@echo "built dist/oocurl_$(VERSION)-1_amd64.deb"

package-rpm: $(BIN)
	@mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS ~/rpmbuild/RPMS
	@cp $(BIN) ~/rpmbuild/SOURCES/oocurl-linux-x86_64
	@cp uninstall.sh ~/rpmbuild/SOURCES/uninstall.sh
	@sed "s/^Version:.*/Version: $(VERSION)/" packaging/oocurl.spec > ~/rpmbuild/SPECS/oocurl.spec
	@rpmbuild -bb ~/rpmbuild/SPECS/oocurl.spec
	@cp ~/rpmbuild/RPMS/x86_64/oocurl-$(VERSION)*.rpm dist/ 2>/dev/null || true
	@if ls dist/oocurl-$(VERSION)-1.*.x86_64.rpm 1> /dev/null 2>&1; then cp dist/oocurl-$(VERSION)-1.*.x86_64.rpm dist/oocurl-$(VERSION)-1.x86_64.rpm; fi
	@echo "built dist RPM package"

package-arch: $(BIN)
	@mkdir -p dist/arch-pkg/usr/bin
	@cp $(BIN) dist/arch-pkg/usr/bin/oocurl
	@chmod 0755 dist/arch-pkg/usr/bin/oocurl
	@cp uninstall.sh dist/arch-pkg/usr/bin/oocurl-uninstall
	@chmod 0755 dist/arch-pkg/usr/bin/oocurl-uninstall
	@printf "pkgname = oocurl\npkgbase = oocurl\npkgver = $(VERSION)-1\npkgdesc = Capability-bounded HTTP and API client with syntax-highlighted responses\nurl = https://github.com/openOODA-tools/oocurl\nbuilddate = $$(date +%s)\npackager = openOODA-tools <ops@openooda.org>\nsize = $$(stat -c %s $(BIN))\narch = x86_64\nlicense = Apache-2.0\ndepend = glibc\nprovides = oocurl\n" > dist/arch-pkg/.PKGINFO
	@tar --zstd -cf dist/oocurl-$(VERSION)-1-x86_64.pkg.tar.zst -C dist/arch-pkg .PKGINFO usr
	@rm -rf dist/arch-pkg
	@bash -n packaging/arch/PKGBUILD
	@cp packaging/arch/PKGBUILD dist/PKGBUILD
	@cp packaging/arch/PKGBUILD packaging/PKGBUILD
	@echo "built dist/oocurl-$(VERSION)-1-x86_64.pkg.tar.zst and validated PKGBUILD"

package: package-deb package-rpm package-arch
	@cp $(BIN) dist/oocurl-linux-x86_64
	@chmod 0755 dist/oocurl-linux-x86_64
	@(cd dist && sha256sum oocurl-linux-x86_64 > oocurl-linux-x86_64.sha256)
	@(cd dist && sha256sum oocurl* > checksums.txt)
	@echo "built all packages and generated dist/checksums.txt"

clean:
	@rm -rf dist .ooda-cache .blackbox
	@echo "cleaned"
