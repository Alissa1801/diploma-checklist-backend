# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.2.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim

WORKDIR /rails

# 1. Установка системных пакетов
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl libjemalloc2 libvips postgresql-client \
    python3 python3-pip python3-setuptools \
    libgl1 libglib2.0-0 build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 2. Переменные окружения
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development test"

# 3. Установка Ruby-гемов
COPY Gemfile Gemfile.lock ./
RUN sed -i '/BUNDLED WITH/,+1d' Gemfile.lock && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache

# 4. Копируем всё приложение
COPY . .

# 5. УСТАНОВКА ML (Исправленный поиск пакетов)
RUN pip3 install --no-cache-dir --upgrade pip --break-system-packages && \
    pip3 install --no-cache-dir --break-system-packages \
    # Сначала указываем основной репозиторий, затем дополнительный для Torch
    --extra-index-url https://download.pytorch.org/whl/cpu \
    numpy==1.26.4 \
    torch==2.2.0+cpu \
    torchvision==0.17.0+cpu \
    ultralytics \
    opencv-python-headless

# 6. Подготовка папок и прав
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p storage public/analysis db log tmp && \
    chown -R rails:rails /rails storage public/analysis db log tmp && \
    chmod -R 775 /rails storage public/analysis db log tmp

RUN bundle exec bootsnap precompile -j 1 app/ lib/

USER 1000:1000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]