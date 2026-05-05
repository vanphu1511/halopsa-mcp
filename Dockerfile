# Stage 1: Builder
FROM node:22-alpine AS builder
WORKDIR /app

# We no longer need .npmrc or GITHUB_TOKEN because we use public libraries
COPY package*.json ./

# Standard install for public packages
RUN npm ci

COPY . .
RUN npm run build

# Stage 2: Runner
FROM node:22-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
# These environment variables align with your Azure Container App setup
ENV MCP_TRANSPORT=http
ENV MCP_HTTP_PORT=8080
ENV MCP_HTTP_HOST=0.0.0.0

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 mcp

# Copy only what is necessary for production to keep the image slim
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

USER mcp
EXPOSE 8080

# Healthcheck for Azure Container App stability
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

CMD ["node", "dist/index.js"]
