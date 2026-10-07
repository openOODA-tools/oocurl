# oocurl

> **Capability-bounded HTTP and API client with syntax-highlighted responses for the openOODA era.**  
> *A drop-in `curl` alternative written in pure openOODA, featuring capability security (`TcpCap`), status code classification, header inspection, syntax-highlighted response payloads, and a first-class Model Context Protocol (MCP) surface.*

Part of [openOODA-tools](https://github.com/openOODA-tools).

---

## 1. Installation

`oocurl` has zero runtime dependencies. It compiles to a standalone native binary linked directly with libc.

### Universal Web Installer
Installs the standalone native binary to `/usr/local/bin` (or `~/.local/bin`):

```bash
curl -fsSL https://openooda-tools.github.io/oocurl/install.sh | bash
```

### Debian / Ubuntu (APT)
```bash
# Automated via installer
curl -fsSL https://openooda-tools.github.io/oocurl/install.sh | bash -s -- --apt

# Or manual package install
sudo dpkg -i oocurl_0.2.0-1_amd64.deb
```

### Fedora / RHEL / CentOS (DNF)
```bash
# Automated via installer
curl -fsSL https://openooda-tools.github.io/oocurl/install.sh | bash -s -- --dnf

# Or manual RPM install
sudo dnf install ./oocurl-0.2.0-1.fc44.x86_64.rpm
```

### Arch Linux (PKGBUILD)
```bash
# Automated via installer
curl -fsSL https://openooda-tools.github.io/oocurl/install.sh | bash -s -- --arch

# Or manual build via packaging/PKGBUILD
cd packaging && makepkg -si
```

### Clean Uninstaller
To cleanly remove `oocurl` and any installed package manager entries:

```bash
# Automated via standalone uninstaller
curl -fsSL https://openooda-tools.github.io/oocurl/uninstall.sh | bash

# Or via installer flag
curl -fsSL https://openooda-tools.github.io/oocurl/install.sh | bash -s -- --uninstall

# Or preview removal without making changes (dry-run)
curl -fsSL https://openooda-tools.github.io/oocurl/uninstall.sh | bash -s -- --dry-run
```

---

## 2. Usage & Features

### HTTP Requests & Payload Inspection
Perform capability-bounded HTTP requests:

```bash
# Standard GET request
oocurl http://127.0.0.1:8080/api/status

# Document info (headers) only
oocurl -I http://127.0.0.1:8080/api/status

# Include HTTP response status and headers
oocurl -i http://127.0.0.1:8080/health

# POST request with custom header and data
oocurl -X POST -H "Content-Type: application/json" -d '{"query":"test"}' http://127.0.0.1:8080/search

# Save response body directly to file
oocurl -o output.json http://127.0.0.1:8080/data
```

### Model Context Protocol (MCP) Server
`oocurl` features a native Model Context Protocol (MCP) stdio server allowing AI pair programmers and LLM coding assistants to execute and inspect network transactions:

```bash
oocurl --mcp
```

#### Exposed MCP Tools:
- `parse_url`: Parse URL, extract scheme, userinfo, host, port, path, query, fragment, and validate.
- `http_request`: Execute HTTP request under explicit `&TcpCap` with method (GET, POST, PUT, DELETE, HEAD), headers, body, and timeout.
- `http_head`: Lightweight headers-only inspection tool.
- `encode_url_query`: Construct RFC 3986 percent-encoded query strings from key-value pairs.

---

## 3. License

Apache License 2.0. See [LICENSE](LICENSE) for details.