########################################################################
## Ground Control
########################################################################

FROM ghcr.io/malyn/groundcontrol AS groundcontrol


########################################################################
## Ktra
########################################################################

FROM rust:1.68.2-alpine3.17 as ktra

RUN apk update && \
    apk add --no-cache \
        musl-dev \
        zlib-dev \
        openssl-dev \
        libgit2-dev libssh2-dev

# ktra 0.7.0
ADD https://github.com/moriturus/ktra/archive/07ffd100bcddc4cf37f969b35f1a33dbf22e986c.tar.gz /tmp/ktra.tar.gz
RUN tar -xzf /tmp/ktra.tar.gz --strip-components=1

# Need to upgrade git2 to 0.14, since 0.13 has a bug that affects Ktra:
# https://github.com/rust-lang/git2-rs/issues/824
RUN CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse cargo add git2@0.14

# Build the Rust binary. Need to tell Rust *not* to link statically with
# musl, otherwise openssl-sys will crash during initialization. More
# info here:
# https://github.com/sfackler/rust-openssl/issues/1620#issuecomment-1100288444
RUN CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse RUSTFLAGS="-C target-feature=-crt-static" \
    cargo build --release --target-dir ./build && \
    cp ./build/release/ktra /ktra


########################################################################
## Tailscale
########################################################################

FROM tailscale/tailscale:v1.38.1 AS tailscale


########################################################################
## Final Image
########################################################################

FROM alpine:3.17.2

# Install required tools.
RUN apk update && \
    apk add --no-cache \
        nginx \
        spawn-fcgi fcgiwrap git-daemon \
        libgit2 libssh2 libssl1.1 ca-certificates libgcc

# Create the `git` and `ktra` users.
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "10001" \
    "git"

RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "10002" \
    "ktra"

# Copy binaries, scripts, and config.
WORKDIR /app

COPY --from=groundcontrol /groundcontrol ./
COPY --from=ktra /ktra ./
COPY --from=tailscale /usr/local/bin/tailscaled ./
COPY --from=tailscale /usr/local/bin/tailscale ./

COPY git-init.sh ./

COPY groundcontrol.toml ./
COPY ktra.toml ./
COPY nginx.conf /etc/nginx/nginx.conf

# Run Ground Control to monitor all of the processes.
ENTRYPOINT ["/app/groundcontrol", "/app/groundcontrol.toml"]