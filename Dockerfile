FROM node:22-alpine AS base

RUN apk add --no-cache libc6-compat

WORKDIR /app

# Install dependencies in a separate stage
FROM base AS deps

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

RUN corepack enable && corepack prepare pnpm@9.15.9 --activate
RUN pnpm install --frozen-lockfile

# Build the Next.js app
FROM base AS builder

ENV NODE_ENV=production

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN corepack enable && corepack prepare pnpm@9.15.9 --activate
RUN pnpm run build

# Final runtime image
FROM base AS runner

ENV NODE_ENV=production
ENV PORT=8080

WORKDIR /app

# Only copy what is needed to run `next start`
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/next.config.mjs ./next.config.mjs
COPY --from=builder /app/.next ./.next
COPY --from=deps /app/node_modules ./node_modules

VOLUME ["/app/src/data"]

# Start the Next.js production server on $PORT
CMD ["sh", "-c", "node_modules/.bin/next start -p $PORT"]