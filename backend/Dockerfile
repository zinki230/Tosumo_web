FROM node:22-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src/ ./src/

RUN npm run prisma:generate
RUN npm run build

FROM node:22-alpine AS runner

WORKDIR /app

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 express

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/src/prisma ./src/prisma
COPY package.json ./

RUN mkdir -p /app/uploads && chown -R express:nodejs /app/uploads

USER express

EXPOSE 3000

ENV NODE_ENV=production

CMD ["sh", "-c", "npm run seed:demo && node dist/server.js"]
