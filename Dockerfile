# Fluxo — static web app served by nginx
FROM nginx:stable-alpine

LABEL org.opencontainers.image.title="Fluxo" \
      org.opencontainers.image.description="Personal expense tracker with a liquid-glass UI" \
      org.opencontainers.image.source="https://github.com/sigmadev21/fluxo"

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=3s --start-period=2s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz >/dev/null || exit 1
