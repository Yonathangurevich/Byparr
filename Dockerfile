# syntax=docker/dockerfile:1
FROM debian:bookworm-slim AS base
ENV HOME=/root

ARG GITHUB_BUILD=false \
    VERSION

ENV GITHUB_BUILD=${GITHUB_BUILD} \
    VERSION=${VERSION} \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DISPLAY=:0 \
    PATH="${HOME}/.local/bin:$PATH"

WORKDIR /app

# מערכת + Chromium + chromedriver + tini
RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
      python3 python3-venv python3-pip \
      xauth xvfb scrot curl chromium chromium-driver ca-certificates tini && \
    rm -rf /var/lib/apt/lists/*

# התקנת uv
ADD https://astral.sh/uv/install.sh install.sh
RUN sh install.sh && uv --version

# התקנת תלויות ה-Python מתוך pyproject/uv.lock
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

# SeleniumBase לא מספק uc_driver ל-arm64; נוודא לינק ל-chromedriver
RUN cd .venv/lib/*/site-packages/seleniumbase/drivers && rm -f uc_driver && ln -s /usr/bin/chromedriver uc_driver

# קוד האפליקציה
COPY . .

EXPOSE 8191
# healthcheck פנימי של Byparr
HEALTHCHECK --interval=5m --timeout=30s --start-period=30s --retries=3 \
  CMD curl -fsS http://localhost:8191/health || exit 1

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["uv","run","main.py","--host","0.0.0.0","--port","8191"]
