# Use minimal Node.js Alpine base image
FROM node:18-alpine

# Set non-root working directory
WORKDIR /usr/src/app

# Copy application source file
COPY server.js .

# Expose port 8080
EXPOSE 8080

# Run container as non-root node user for security
USER node

# Start the HTTP server
CMD ["node", "server.js"]