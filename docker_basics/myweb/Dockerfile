# Start from a small, pinned base image (never use "latest")
FROM nginx:1.27-alpine

# Copy our web page into the folder nginx serves
COPY index.html /usr/share/nginx/html/index.html

# Document the port the app listens on (does not publish it)
EXPOSE 80

# nginx base image already has a CMD; shown here for learning
CMD ["nginx", "-g", "daemon off;"]
