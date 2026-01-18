# Minimalistic container for Zola site building from metadata
# Contains: PowerShell, Zola, AWS CLI (S3), Git

FROM alpine:3.20 AS builder

ARG ZOLA_VERSION=0.22.0

# Download and extract Zola
RUN apk add --no-cache curl tar \
    && curl -L "https://github.com/getzola/zola/releases/download/v${ZOLA_VERSION}/zola-v${ZOLA_VERSION}-x86_64-unknown-linux-musl.tar.gz" | tar xz -C /usr/local/bin

# Final image based on PowerShell Alpine
FROM mcr.microsoft.com/powershell:lts-alpine-3.20

# Copy Zola from builder
COPY --from=builder /usr/local/bin/zola /usr/local/bin/zola

# Install minimal dependencies: git, aws-cli (for S3), ca-certificates
RUN apk add --no-cache \
    git \
    aws-cli \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Verify installations
RUN pwsh -Version \
    && zola --version \
    && aws --version \
    && git --version

WORKDIR /workspace

ENTRYPOINT ["/bin/sh", "-c"]
