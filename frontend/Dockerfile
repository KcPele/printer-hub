# Multi-stage production Dockerfile for PrinterHub TanStack Start / Nitro frontend

# Stage 1: Build stage
FROM node:22-alpine AS builder

WORKDIR /app

# Install build dependencies
COPY package.json ./
RUN npm install

# Copy configuration and source files
COPY tsconfig.json tsr.config.json vite.config.ts biome.json ./
COPY src ./src

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
COPY --from=builder --chown=nitrojs:nodejs /app/.output ./.output

USER nitrojs

EXPOSE 3000

CMD ["node", ".output/server/index.mjs"]
