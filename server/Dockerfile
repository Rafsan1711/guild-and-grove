FROM node:20-alpine

# Create app user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Dependencies আগে copy করো (caching এর জন্য)
COPY package*.json ./
RUN npm ci --only=production

# Source code copy করো
COPY --chown=appuser:appgroup . .

# Logs folder তৈরি করো
RUN mkdir -p logs && chown -R appuser:appgroup logs

USER appuser

# HuggingFace এ port 7860 expose করতে হয়
EXPOSE 7860

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:7860/ || exit 1

CMD ["node", "index.js"]