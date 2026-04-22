FROM node:20-slim
WORKDIR /app
# 此 Dockerfile 由 Zeabur 從母 repo turnkey193/TB 的根執行 build，context = 母 repo 根
# 所以 COPY 路徑要加 tb-meeting/ 前綴
COPY tb-meeting/package*.json ./
RUN npm ci
COPY tb-meeting/ .
RUN npx vite build
EXPOSE 3001
ENV PORT=3001
CMD ["node", "server.js"]
