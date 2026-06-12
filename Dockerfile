# syntax=docker/dockerfile:1.6

# ───────────────────────────────────────────────────────────────
#  Build stage  (Swift 6.3.2 + jemalloc + persistent caches)
# ───────────────────────────────────────────────────────────────
FROM swift:6.3.2-noble AS build

RUN apt-get -q update \
 && apt-get -q install -y --no-install-recommends libjemalloc-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# 1.  Dependency resolution  ────────────────────────────────────
COPY Package.swift Package.resolved ./
RUN --mount=type=cache,id=swiftpm,target=/root/.cache/swiftpm \
    swift package resolve --force-resolved-versions

# 2.  Application sources  ──────────────────────────────────────
COPY Sources ./Sources
COPY Tests ./Tests

# 3.  Compile and stage artefacts  ──────────────────────────────
RUN --mount=type=cache,id=swift-build,target=/build/.build \
    swift build -c release \
        --product AttestService \
        --static-swift-stdlib \
        -Xlinker -ljemalloc \
 && mkdir -p /stage \
 && cp "$(swift build -c release --show-bin-path)/AttestService" /stage/ \
 && cp /usr/libexec/swift/linux/swift-backtrace-static /stage/ \
 && find -L "$(swift build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} /stage/ \;

# ───────────────────────────────────────────────────────────────
#  Runtime stage  (tiny Ubuntu image)
# ───────────────────────────────────────────────────────────────
FROM ubuntu:noble

RUN apt-get -q update \
 && apt-get -q install -y --no-install-recommends \
        libjemalloc2 \
        ca-certificates \
        tzdata \
 && rm -rf /var/lib/apt/lists/*

RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor
WORKDIR /app

COPY --from=build --chown=vapor:vapor /stage /app

ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static

USER vapor:vapor
EXPOSE 1992

ENTRYPOINT ["./AttestService"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "1992"]
