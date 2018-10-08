FROM mcr.microsoft.com/powershell:6.1.0-rc.1-alpine-3.8 as powershell-alpine

ENV USER powershell
ENV TMPDIR=/dev/shm

# Newest UPX not yet in Alpine
RUN apk add xz \
    && wget -qO- https://github.com/upx/upx/releases/download/v3.95/upx-3.95-amd64_linux.tar.xz | tar x -J --strip-components=1 -C /tmp/

# Compress libraries with UPX except musl, libicudata
RUN chmod 755 /lib/libssl.so.1.0.0 /lib/libcrypto.so.1.0.0 \
    && chmod +x /usr/lib/libgcc_s.so.1 \
    && /tmp/upx --brute --best \
    $(realpath \
        /usr/lib/liburcu-bp.so.6 \
        /usr/lib/liburcu-cds.so.6 \
        /usr/lib/libgcc_s.so.1 \
        /usr/lib/libintl.so.8 \
        "/usr/lib/libstdc++.so.6" \
        /usr/lib/libicui18n.so.60 \
        /usr/lib/libicuuc.so.60 \
        /usr/lib/liblttng-ust.so.0 \
        /usr/lib/liblttng-ust-tracepoint.so.0 \
        /lib/libssl.so.1.0.0 \
        /lib/libcrypto.so.1.0.0 \
        /lib/libz.so.1 \
        /opt/microsoft/powershell/6-preview/libmi.so \
        /opt/microsoft/powershell/6-preview/libdbgshim.so \
        /opt/microsoft/powershell/6-preview/libpsrpclient.so \
        /opt/microsoft/powershell/6-preview/System.Native.so \
        /opt/microsoft/powershell/6-preview/libhostfxr.so \
        /opt/microsoft/powershell/6-preview/System.Globalization.Native.so \
        /opt/microsoft/powershell/6-preview/System.IO.Compression.Native.so \
        /opt/microsoft/powershell/6-preview/libcoreclrtraceptprovider.so \
        /opt/microsoft/powershell/6-preview/System.Security.Cryptography.Native.OpenSsl.so \
        /opt/microsoft/powershell/6-preview/libhostpolicy.so \
        /opt/microsoft/powershell/6-preview/libmscordbi.so \
        /opt/microsoft/powershell/6-preview/libmscordaccore.so \
        /opt/microsoft/powershell/6-preview/libclrjit.so \
        /opt/microsoft/powershell/6-preview/libpsl-native.so \
        /opt/microsoft/powershell/6-preview/libsosplugin.so \
        /opt/microsoft/powershell/6-preview/libsos.so \
        /opt/microsoft/powershell/6-preview/pwsh \
        /opt/microsoft/powershell/6-preview/createdump \
    )

# Add user
RUN addgroup -S ${USER} \
    && adduser -h /dev/shm -S ${USER}

######################################################
# BUILD MINIMAL POWERSHELL IMAGE
######################################################
FROM scratch
LABEL maintainer="Wilmar den Ouden <wilmaro@intermax.nl>"

ENV USER powershell

# Needed to fix: Failed to initialize CoreCLR, HRESULT: 0x80004005
ENV COMPlus_EnableDiagnostics=0
# Needed for hacky dotnet case_sensitive test
# https://github.com/dotnet/corefx/blob/master/src/Common/src/System/IO/PathInternal.CaseSensitivity.cs
ENV TMPDIR=/dev/shm

# Copy users from builder
COPY --from=powershell-alpine \
    /etc/passwd \
    /etc/group \
    /etc/

# Adds sh to container
COPY --from=powershell-alpine /bin/sh /bin/sh

# Copy Powershell binary and files
# TODO: Fix some dynamic user chown, not possible now due https://github.com/moby/moby/issues/35018
COPY --from=powershell-alpine --chown=powershell:powershell \
    /opt/microsoft/powershell/6-preview/ /opt/microsoft/powershell/6-preview/

# Copy all needed libraries
COPY --from=powershell-alpine \
    /usr/lib/liburcu-bp.so.6 \
    /usr/lib/liburcu-cds.so.6 \
    /usr/lib/libgcc_s.so.1 \
    /usr/lib/libintl.so.8 \
    "/usr/lib/libstdc++.so.6" \
    /usr/lib/libicudata.so.60 \
    /usr/lib/libicui18n.so.60 \
    /usr/lib/libicuuc.so.60 \
    /usr/lib/liblttng-ust.so.0 \
    /usr/lib/liblttng-ust-tracepoint.so.0 \
    /usr/lib/

COPY --from=powershell-alpine \
    /lib/libssl.so.1.0.0 \
    /lib/libcrypto.so.1.0.0 \
    /lib/libz.so.1 \
    "/lib/ld-musl-x86_64.so.1" \
    /lib/

# Copy ncurses-terminfo-base
COPY --from=powershell-alpine /etc/terminfo/x/xterm /etc/terminfo/x/xterm

# Timezone info from tzdata
COPY --from=powershell-alpine /usr/share/zoneinfo/ /usr/share/zoneinfo/

# Copy SSL
COPY --from=powershell-alpine /etc/ssl/ /etc/ssl/

USER ${USER}
ENTRYPOINT ["/opt/microsoft/powershell/6-preview/pwsh"]