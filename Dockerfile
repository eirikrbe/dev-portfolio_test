# Build stage
FROM golang:1.22-bookworm AS builder

WORKDIR /app

# Install Hugo Extended and build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    curl \
    build-essential \
    python3 && \
    ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then \
      wget -qO /tmp/hugo.tar.gz https://github.com/gohugoio/hugo/releases/download/v0.162.0/hugo_extended_0.162.0_linux-arm64.tar.gz; \
    else \
      wget -qO /tmp/hugo.tar.gz https://github.com/gohugoio/hugo/releases/download/v0.162.0/hugo_extended_0.162.0_linux-amd64.tar.gz; \
    fi && \
    tar -xzf /tmp/hugo.tar.gz -C /usr/local/bin && \
    rm /tmp/hugo.tar.gz && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js (for pnpm/npm build tools and Tailwind CSS)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# Copy package files and install dependencies
COPY package.json pnpm-lock.yaml ./
RUN corepack enable pnpm && \
    corepack prepare pnpm@10.14.0 --activate && \
    pnpm install --frozen-lockfile && \
    pnpm rebuild

# Copy source code
COPY . .

# Build the site (skip pagefind if it fails; site will build without search index)
RUN pnpm run build || hugo --minify || true

# Runtime stage
FROM alpine:3.20

WORKDIR /app

# Install minimal server
RUN apk add --no-cache \
    ca-certificates \
    curl

# Copy built site from builder
COPY --from=builder /app/public ./public

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/index.html || exit 1

# Expose port
EXPOSE 8080

# Start a simple HTTP server
CMD ["sh", "-c", "cd /app/public && busybox httpd -f -p 8080"]
