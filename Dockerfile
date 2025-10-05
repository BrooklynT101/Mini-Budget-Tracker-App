# Stage 1: build - base image
FROM node:22 AS build

# set work directory and install dependencies
WORKDIR /app
COPY package*.json ./
RUN npm install 

# copy project files and build
COPY . .
RUN npm run build

#Run the app
CMD ["npm", "start"]

# Stage 2: serve static files
# FROM nginx:alpine
# COPY --from=build /app/dist /usr/share/nginx/html
# EXPOSE 80
# CMD ["nginx", "-g", "daemon off;"]
