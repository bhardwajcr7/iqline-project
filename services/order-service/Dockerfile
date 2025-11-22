FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm i
RUN npm ci --production
COPY . .
EXPOSE 3002
CMD ["node", "server.js"]
