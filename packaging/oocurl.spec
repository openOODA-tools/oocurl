Name:           oocurl
Version:        0.1.0
Release:        1%{?dist}
Summary:        Capability-bounded HTTP and API client with syntax-highlighted responses
License:        ASL 2.0
URL:            https://github.com/openOODA-tools/oocurl
Source0:        oocurl-linux-x86_64
Source1:        uninstall.sh
BuildArch:      x86_64
Requires:       glibc

%description
oocurl is a sovereign, capability-bounded HTTP and API client written in pure
openOODA, featuring status classification, header inspection, syntax-highlighted
response payloads via oote themes, safe file writes, and an MCP stdio server.

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 %{SOURCE0} %{buildroot}/usr/bin/oocurl
install -m 0755 %{SOURCE1} %{buildroot}/usr/bin/oocurl-uninstall

%files
/usr/bin/oocurl
/usr/bin/oocurl-uninstall

%changelog
* Wed Oct 07 2026 openOODA-tools <ops@openooda.org> - 0.1.0-1
- Initial sovereign release: capability-bounded HTTP fetch, syntax-highlighted payloads, and MCP stdio surface
