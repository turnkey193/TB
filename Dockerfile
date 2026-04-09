FROM node:20-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npx vite build
EXPOSE 3001
ENV PORT=3001
CMD ["node", "server.js"]
