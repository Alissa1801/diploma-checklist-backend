# syntax=docker/dockerfile:1

# 1. БАЗОВЫЙ ОБРАЗ: Используем официальную среду Ultralytics (CPU-версия)
# В ней УЖЕ установлены Python, PyTorch, OpenCV и ПРАВИЛЬНЫЙ NumPy.
FROM ultralytics/ultralytics:latest-cpu AS base

WORKDIR /rails

# 2. УСТАНОВКА RUBY И ЗАВИСИМОСТЕЙ
# Устанавливаем Ruby и системные пакеты прямо в среду Ultralytics
USER root
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    ruby-full \
    build-essential \
    libpq-dev \
    git \
    curl \
    postgresql-client \
    libvips \
    libjemalloc2 && \
    gem install bundler:2.4.10 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Настройка переменных окружения для Rails
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libjemalloc.so.2"

# --- Build Stage (Сборка гемов) ---
FROM base AS build

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache

COPY . .
# Предкомпиляция bootsnap для ускорения запуска
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# --- Final Stage (Финальный образ) ---
FROM base

# Создаем пользователя rails (хотя в этом образе можно работать и под root, сделаем по стандарту)
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# Создаем необходимые директории
RUN mkdir -p storage public/analysis db log tmp && \
    chown -R rails:rails /rails && \
    chmod -R 775 /rails storage public/analysis db log tmp

# Копируем установленные гемы и код приложения
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Проверка NumPy в логах билда (чтобы убедиться, что он на месте)
RUN python3 -c "import numpy; print(f'BUILD_LOG: NumPy version is {numpy.__version__}')"

USER 1000:1000

EXPOSE 80
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["./bin/thrust", "./bin/rails", "server"]