FROM mcr.microsoft.com/powershell:6.1.0-rc.1-alpine-3.8 as powershell-alpine

# Newest UPX not yet in Alpine
RUN apk add xz \
    && wget -qO- https://github.com/upx/upx/releases/download/v3.95/upx-3.95-amd64_linux.tar.xz | tar x -J --strip-components=1 -C /tmp/

# Compress libraries and executables with UPX
RUN /tmp/upx --brute --best $(find /usr/lib -path /usr/lib/engines -prune -o -type f -perm +111 -print) || true
RUN chmod 755 /lib/libssl.so.1.0.0 /lib/libcrypto.so.1.0.0 \
    && /tmp/upx --brute --best /lib/libssl.so.1.0.0 /lib/libcrypto.so.1.0.0 /lib/libz.so.1.*

RUN /tmp/upx --brute --best $(find /opt/microsoft/powershell/6-preview/ -type f -not -name "libcoreclr.so" -name *.so -print) || true
RUN /tmp/upx --brute --best /opt/microsoft/powershell/6-preview/pwsh /opt/microsoft/powershell/6-preview/createdump

RUN adduser -h /dev/shm -u 10001 -S user
# COPY profile.ps1 /opt/microsoft/powershell/6-preview/

######################################################
# BUILD MINIMAL POWERSHELL IMAGE
######################################################
FROM scratch
LABEL maintainer="Wilmar den Ouden <wilmaro@intermax.nl>"

# Needed to fix: Failed to initialize CoreCLR, HRESULT: 0x80004005
ENV COMPlus_EnableDiagnostics=0

# Adds sh to container
COPY --from=powershell-alpine /bin/sh /bin/sh

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
# musl cannot be upx'ed
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