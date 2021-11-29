# Base image built from Dockerfile.base (Chrome Stable + Node LTS)
FROM judson/chrome-headless:latest

LABEL "com.github.actions.name"="Lighthouse Audit"
LABEL "com.github.actions.description"="Run tests on a webpage via Google's Lighthouse tool"
LABEL "com.github.actions.icon"="check-square"
LABEL "com.github.actions.color"="yellow"

LABEL version="0.3.2"
LABEL repository="https://github.com/jakejarvis/lighthouse-action"
LABEL homepage="https://jarv.is/"
LABEL maintainer="Jake Jarvis <jake@jarv.is>"

# Download latest Lighthouse build from npm
# Cache bust to ensure latest version when building the image
ARG CACHEBUST=1
RUN PUPPETEER_SKIP_DOWNLOAD=1 npm install -g csp_evaluator@1.0.1 lighthouse puppeteer

# Disable Lighthouse error reporting to prevent prompt
ENV CI=true

ADD entrypoint.sh /entrypoint.sh
ADD lighthouse.js /lighthouse.js

ENTRYPOINT ["/entrypoint.sh"]
