FROM python:3.12-slim-bookworm

ENV TZ=Asia/Tokyo

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    postgresql-client \
    tzdata \
    && ln -snf /usr/share/zoneinfo/"$TZ" /etc/localtime \
    && echo "$TZ" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir \
    "dbt-core==1.12.6" \
    "dbt-postgres==1.11.0" \
    "dbt-osmosis==1.5.0" \
    "sqlfluff==4.5.0" \
    "sqlfluff-templater-dbt==4.5.0" \
    "pre-commit==4.7.0" \
    "ruff==0.14.10"

WORKDIR /workspaces/SmallDataAnalyticsPlatform2
