# Use Node 20 Slim as the base image
FROM node:20-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    procps \
    build-essential \
    python3 \
    wget \
    vim-tiny \
    net-tools \
    iputils-ping \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install the CLIs
RUN npm install -g jira-ai@0.6.12 opencode-ai@latest @playwright/cli@latest

# Install browsers AND their system dependencies
RUN npx playwright install --with-deps chromium
RUN npx playwright install chrome
RUN playwright-cli install-browser chromium

# Set up the workspace
WORKDIR /root

WORKDIR /app
RUN echo '{"permission": {"*": {"*": "allow"}}}' > opencode.json
RUN mkdir -p .playwright && echo '{"browser": {"browserName": "chromium", "launchOptions": {"args": ["--no-sandbox"]}}}' > .playwright/cli.config.json

# Copy instructions folder
COPY instructions ./instructions
# Copy and set entrypoint script
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy look-for-tasks.sh and make it executable
COPY look-for-tasks.sh /app/
RUN chmod +x /app/look-for-tasks.sh

# Copy Confluence API module
COPY confluence-api.js /app/

ENTRYPOINT ["entrypoint.sh"]
# No CMD — entrypoint.sh starts the webhook/loop when no args are passed.
# For local dev override: docker run -it reviz-revyoos bash
