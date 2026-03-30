# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.2.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# 1. СИСТЕМНЫЕ ПАКЕТЫ
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl libjemalloc2 libvips postgresql-client \
    python3 python3-pip python3-setuptools \
    libgl1 libglib2.0-0 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 2. ML ФИНАЛЬНЫЙ РЫВОК: Очистка и установка фундамента
RUN pip3 install --no-cache-dir --upgrade pip --break-system-packages && \
    pip3 uninstall -y numpy opencv-python opencv-python-headless --break-system-packages || true

## 3. ML: Установка PyTorch, YOLO и ВСЕХ системных зависимостей
RUN pip3 install --no-cache-dir \
    torch==2.2.0+cpu \
    torchvision==0.17.0+cpu \
    --index-url https://download.pytorch.org/whl/cpu --break-system-packages

# Добавляем hub-sdk и ultralytics-hub в список
RUN pip3 install --no-cache-dir \
    ultralytics==8.1.0 \
    opencv-python-headless==4.8.1.78 \
    psutil pyyaml tqdm matplotlib packaging pandas scipy pyparsing \
    cycler kiwisolver python-dateutil six \
    hub-sdk ultralytics-hub py-cpuinfo requests timm \
    --no-deps --break-system-packages

# Устанавливаем NumPy ПЕРВЫМ и СТРОГО фиксируем
RUN pip3 install --no-cache-dir numpy==1.26.4 --break-system-packages

# Устанавливаем OpenCV и YOLO БЕЗ зависимостей, чтобы они не тронули NumPy
RUN pip3 install --no-cache-dir \
    opencv-python-headless==4.8.1.78 \
    ultralytics==8.1.0 \
    psutil pyyaml tqdm matplotlib packaging pandas scipy pyparsing cycler kiwisolver python-dateutil six ultralytics-hub timm py-cpuinfo requests \
    --no-deps --break-system-packages

# --- Build Stage ---
FROM base AS build
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# --- Final Stage ---
FROM base
RUN groupadd --system --gid 1000 rails && useradd rails --uid 1000 --gid 1000 --create-home
USER root
RUN mkdir -p /rails/storage /rails/public/analysis /rails/db /rails/log /rails/tmp && \
    chown -R rails:rails /rails && chmod -R 775 /rails
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails/. /rails/
USER 1000:1000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]