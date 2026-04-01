# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.2.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# 1. СИСТЕМНЫЕ ПАКЕТЫ + PYTHON (Минимум необходимого)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl libjemalloc2 libvips postgresql-client \
    python3 python3-pip python3-setuptools \
    libgl1 libglib2.0-0 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 2. УСТАНОВКА ML ОДНИМ СЛОЕМ (С зачисткой)
RUN pip3 install --no-cache-dir --upgrade pip --break-system-packages && \
    pip3 install --no-cache-dir --break-system-packages \
    --index-url https://download.pytorch.org/whl/cpu \
    torch==2.2.0+cpu \
    torchvision==0.17.0+cpu \
    ultralytics==8.1.0 \
    numpy==1.26.4 \
    opencv-python-headless==4.8.1.78 && \
    # Удаляем кэши и лишние части библиотек для уменьшения веса
    find /usr/local/lib/python3*/dist-packages -name "tests" -type d -exec rm -rf {} + || true && \
    rm -rf /root/.cache/pip

    RUN apt-get update -qq && apt-get install -y python3-pkg-resources && rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development test"

# --- Build Stage ---
FROM base AS build
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config

COPY Gemfile Gemfile.lock ./
# Чистим лок-файл и ставим гемы
RUN sed -i '/BUNDLED WITH/,+1d' Gemfile.lock && \
    bundle install && \
    # Чистим кэш бандлера
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# --- Final Stage ---
FROM base
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

USER root
# Создаем структуру папок одним слоем
RUN mkdir -p storage public/analysis db log tmp && \
    chown -R rails:rails /rails storage public/analysis db log tmp && \
    chmod -R 775 /rails storage public/analysis db log tmp

# ВАЖНО: Копируем всё ОДНИМ движением, чтобы не было тайм-аута на финализации слоев
COPY --chown=rails:rails --from=build /usr/local/bundle /usr/local/bundle
COPY --chown=rails:rails --from=build /rails /rails

USER 1000:1000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]