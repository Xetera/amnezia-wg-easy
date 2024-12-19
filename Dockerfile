# As a workaround we have to build on nodejs 18
# nodejs 20 hangs on build with armv6/armv7
FROM docker.io/library/node:18-alpine AS build_node_modules

# Update npm to latest (actual npm@10.8.2)
# RUN npm install -g npm@latest

# Copy Web UI
COPY src /app
WORKDIR /app
RUN npm ci --omit=dev &&\
    mv node_modules /node_modules

# Copy build result to a new image.
# This saves a lot of disk space.
FROM golang:1.22-alpine3.19 AS builder
RUN apk update && apk add --no-cache git make bash build-base linux-headers

RUN git clone https://github.com/amnezia-vpn/amneziawg-tools.git && \
    (cd amneziawg-tools && git checkout c0b400c6dfc046f5cae8f3051b14cb61686fcf55) && \
    git clone https://github.com/amnezia-vpn/amneziawg-go.git && \
    (cd amneziawg-go && git checkout 2e3f7d122ca8ef61e403fddc48a9db8fccd95dbf)

RUN make -C amneziawg-tools/src WITH_WGQUICK=yes install && \
    make -C amneziawg-go

FROM alpine:latest
COPY --from=builder /go/amneziawg-go/amneziawg-go /usr/bin/amneziawg-go
COPY --from=builder /usr/bin/awg /usr/bin/awg
COPY --from=builder /usr/bin/awg-quick /usr/bin/awg-quick

HEALTHCHECK CMD /usr/bin/timeout 5s /bin/sh -c "/usr/bin/awg show | /bin/grep -q interface || exit 1" --interval=1m --timeout=5s --retries=3
COPY --from=build_node_modules /app /app

# Move node_modules one directory up, so during development
# we don't have to mount it in a volume.
# This results in much faster reloading!
#
# Also, some node_modules might be native, and
# the architecture & OS of your development machine might differ
# than what runs inside of docker.
COPY --from=build_node_modules /node_modules /node_modules

# Copy the needed wg-password scripts
COPY --from=build_node_modules /app/wgpw.sh /bin/wgpw
RUN chmod +x /bin/wgpw

# Install Linux packages
RUN apk add --no-cache \
    dpkg \
    dumb-init \
    iptables \
    iptables-legacy \
    nodejs \
    npm \
    bash

# Use iptables-legacy
RUN update-alternatives --install /sbin/iptables iptables /sbin/iptables-legacy 10 --slave /sbin/iptables-restore iptables-restore /sbin/iptables-legacy-restore --slave /sbin/iptables-save iptables-save /sbin/iptables-legacy-save

# Set Environment
ENV DEBUG=Server,WireGuard

# Run Web UI
WORKDIR /app
CMD ["/usr/bin/dumb-init", "node", "server.js"]
