# syntax=docker/dockerfile:1
# check=error=true

ARG RUBY_VERSION=3.2.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Устанавливаем базовые переменные окружения
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# 1. СИСТЕМНЫЕ ПАКЕТЫ
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl libjemalloc2 libvips postgresql-client \
    python3 python3-pip python3-setuptools \
    libgl1 libglib2.0-0 && \
    ln -sf /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 2. ML & Зависимости: Устанавливаем стабильную комбинацию
RUN pip3 install --no-cache-dir --upgrade pip --break-system-packages && \
    pip3 install --no-cache-dir \
    numpy==1.24.3 \
    torch==2.2.0+cpu \
    torchvision==0.17.0+cpu \
    --index-url https://download.pytorch.org/whl/cpu --break-system-packages

# 3. YOLO & OpenCV: Устанавливаем ultralytics БЕЗ принудительного обновления numpy
RUN pip3 install --no-cache-dir ultralytics==8.1.0 opencv-python-headless --break-system-packages

# --- Build Stage ---
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libpq-dev \
    libyaml-dev \
    pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .

RUN bundle exec bootsnap precompile -j 1 app/ lib/

# --- Final Stage ---
FROM base

# Настройка пользователя
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# Настройка прав (сначала создаем структуру под root)
USER root
RUN mkdir -p /rails/storage /rails/public/analysis /rails/db /rails/log /rails/tmp && \
    chown -R rails:rails /rails && \
    chmod -R 775 /rails

# 1. Копируем гемы
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"

# 2. Копируем код (используем /. чтобы копировать содержимое, а не саму папку как файл)
COPY --chown=rails:rails --from=build /rails/. /rails/

# Возвращаемся к пользователю rails
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80
# Рекомендуется использовать полный путь для надежности
CMD ["./bin/thrust", "./bin/rails", "server"]