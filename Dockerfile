# syntax=docker/dockerfile:1
# check=error=true

ARG RUBY_VERSION=3.2.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# 1. СИСТЕМНЫЕ ПАКЕТЫ: Добавлены libgl1 и libglib2.0-0 для работы OpenCV
# Флаг -sf для ln гарантирует отсутствие ошибки "File exists"
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl libjemalloc2 libvips postgresql-client \
    python3 python3-pip python3-setuptools \
    libgl1 libglib2.0-0 && \
    ln -sf /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 2. ML: Устанавливаем CPU-версию PyTorch
RUN pip3 install --no-cache-dir \
    torch==2.2.0+cpu \
    torchvision==0.17.0+cpu \
    --index-url https://download.pytorch.org/whl/cpu --break-system-packages

# 3. YOLO: Устанавливаем нейросеть и OpenCV-headless
RUN pip3 install --no-cache-dir ultralytics opencv-python-headless --break-system-packages

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# --- Build Stage ---
FROM base AS build

# Устанавливаем инструменты сборки для компиляции гемов (build-essential)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libpq-dev \
    libyaml-dev \
    pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./

# Установка гемов
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .

# Предкомпиляция Bootsnap
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# --- Final Stage ---
FROM base

# Настройка пользователя
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# Настройка прав на папку для сохранения результатов анализа
USER root
RUN mkdir -p /rails/storage /rails/public/analysis && \
    chown -R rails:rails /rails/storage /rails/public/analysis && \
    chmod -R 775 /rails/storage /rails/public/analysis

USER 1000:1000

# Копируем установленные гемы и код из стадии сборки
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]