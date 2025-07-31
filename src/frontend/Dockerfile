FROM node:18 AS builder
WORKDIR /app
COPY . .
RUN npm install
RUN npm run build

FROM nginx:alpine
# Add the exercise.txt file into the final image
COPY --from=builder /app/build /usr/share/nginx/html
RUN echo "This is my exercise file" > /usr/share/nginx/html/exercise.txt
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

