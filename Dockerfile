# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.2.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# 1. СИСТЕМНЫЕ ПАКЕТЫ (включая Python для YOLO)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl libjemalloc2 libvips postgresql-client \
    python3 python3-pip python3-setuptools \
    libgl1 libglib2.0-0 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 2. УСТАНОВКА ML (YOLO) В СИСТЕМУ
# Ставим строго те версии, которые "дружат" с Ruby и не ломают Numpy
RUN pip3 install --no-cache-dir --upgrade pip --break-system-packages && \
    pip3 install --no-cache-dir \
    torch==2.2.0+cpu \
    torchvision==0.17.0+cpu \
    --index-url https://download.pytorch.org/whl/cpu --break-system-packages && \
    pip3 install --no-cache-dir \
    ultralytics==8.1.0 \
    numpy==1.26.4 \
    opencv-python-headless==4.8.1.78 \
    --break-system-packages

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development test"

# --- Build Stage ---
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config

COPY Gemfile Gemfile.lock ./

# Хак для Bundler, чтобы он не искал версию 4.0.8
RUN sed -i '/BUNDLED WITH/,+1d' Gemfile.lock && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache

COPY . .
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# --- Final Stage ---
FROM base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

USER root
RUN mkdir -p storage public/analysis db log tmp && \
    chown -R rails:rails /rails storage public/analysis db log tmp && \
    chmod -R 775 /rails storage public/analysis db log tmp

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

USER 1000:1000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]