# Multi-stage production Dockerfile for PrinterHub TanStack Start / Nitro frontend

# Build it from the repository root, not from frontend/: the admin console
# is built on the typed API client in packages/api-client.
#
#   docker build -f frontend/Dockerfile .
#
# frontend/Dockerfile.dockerignore keeps the rest of the repository out.

# Stage 1: Build stage
FROM node:22-alpine AS builder

# The source of the shared API client. Its one dependency, openapi-fetch,
# is installed with the frontend's own.
WORKDIR /app/packages/api-client
COPY packages/api-client/src ./src

WORKDIR /app/frontend

# Install build dependencies
COPY frontend/package.json ./
RUN npm install

# Copy configuration and source files
COPY frontend/tsconfig.json frontend/tsr.config.json frontend/vite.config.ts frontend/biome.json ./
COPY frontend/src ./src
# Icons, the share image, robots.txt, and the sitemap, served as they are.
COPY frontend/public ./public

# Where the admin console finds the API. Left unset, a production build
# talks to the live backend.
ARG VITE_API_URL
ENV VITE_API_URL=${VITE_API_URL}
# The site's own address, for its canonical link and share image. Left
# unset, https://printerhub.kcpele.com.
ARG VITE_SITE_URL
ENV VITE_SITE_URL=${VITE_SITE_URL}

# Build the application using TanStack Start & Nitro
RUN npm run build

# Stage 2: Minimal production runner
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0 \
    NITRO_PORT=3000 \
    NITRO_HOST=0.0.0.0

# Run as non-root user for security best practices
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nitrojs

# Copy compiled Nitro output (server entry + public assets)
COPY --from=builder --chown=nitrojs:nodejs /app/frontend/.output ./.output

USER nitrojs

EXPOSE 3000

CMD ["node", ".output/server/index.mjs"]
