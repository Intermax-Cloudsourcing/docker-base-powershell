FROM mcr.microsoft.com/powershell:6.1.0-rc.1-alpine-3.8 as powershell-alpine

RUN adduser -h /dev/shm -u 10001 -S user
COPY profile.ps1 /opt/microsoft/powershell/6-preview/

######################################################
# BUILD MINIMAL POWERSHELL IMAGE
######################################################
FROM scratch
LABEL maintainer="Wilmar den Ouden <wilmaro@intermax.nl>"

# Needed to fix: Failed to initialize CoreCLR, HRESULT: 0x80004005
ENV COMPlus_EnableDiagnostics=0

# Copy binary and files
COPY --from=powershell-alpine --chown=10001:10001 /opt/microsoft/powershell/6-preview/ /opt/microsoft/powershell/6-preview/

# krb5-libs
COPY --from=powershell-alpine /usr/lib/liburcu-bp.so.6 /usr/lib/
COPY --from=powershell-alpine /usr/lib/liburcu-cds.so.6 /usr/lib/
# libgcc
COPY --from=powershell-alpine /usr/lib/libgcc_s.so.1 /usr/lib/
# libintl
COPY --from=powershell-alpine /usr/lib/libintl.so.8 /usr/lib
# libssl1.0
COPY --from=powershell-alpine /lib/libssl.so.1.0.0 /lib/
# libcrypto1.0
COPY --from=powershell-alpine /lib/libcrypto.so.1.0.0 /lib/
# libstdc++
COPY --from=powershell-alpine "/usr/lib/libstdc++.so.6" /usr/lib/
# zlib
COPY --from=powershell-alpine /lib/libz.so.1 /lib/
# musl
COPY --from=powershell-alpine "/lib/ld-musl-x86_64.so.1" /lib/

# Copy ncurses-terminfo-base
COPY --from=powershell-alpine /etc/terminfo/x/xterm /etc/terminfo/x/xterm

# ICU needed for globalization (icu-libs)
COPY --from=powershell-alpine /usr/lib/libicudata.so.60 /usr/lib/
COPY --from=powershell-alpine /usr/lib/libicui18n.so.60 /usr/lib/
COPY --from=powershell-alpine /usr/lib/libicuuc.so.60 /usr/lib/

# Timezone info from tzdata
COPY --from=powershell-alpine /usr/share/zoneinfo/ /usr/share/zoneinfo/

# lttng-ust
COPY --from=powershell-alpine /usr/lib/liblttng-ust.so.0 /usr/lib/
COPY --from=powershell-alpine /usr/lib/liblttng-ust-tracepoint.so.0 /usr/lib/

# openssl
COPY --from=powershell-alpine /etc/ssl/ /etc/ssl/

# Copy users from builder
COPY --from=powershell-alpine /etc/passwd /etc/passwd

USER user
ENTRYPOINT ["/opt/microsoft/powershell/6-preview/pwsh"]