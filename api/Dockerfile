FROM node:22

# set directory and install dependencies
WORKDIR /app
COPY package*.json ./
RUN npm install


RUN npm ci --omit=dev
COPY . .
ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "server.js"]
