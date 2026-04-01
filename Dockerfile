# syntax=docker/dockerfile:1
FROM ultralytics/ultralytics:latest-cpu AS base

USER root
WORKDIR /rails

# 1. Системные пакеты (добавляем ruby-dev для компиляции гемов)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    ruby ruby-dev build-essential libpq-dev git curl postgresql-client libvips libjemalloc2 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 2. Установка Bundler (БЕЗ обновления системы)
# Используем --no-document для скорости и обходим APT
RUN gem install bundler -v 2.4.10 --no-document

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libjemalloc.so.2"

# --- Build Stage ---
FROM base AS build

# Копируем только гемфайлы
COPY Gemfile Gemfile.lock ./

# 3. КРИТИЧЕСКИЙ ХАК: Очистка Lock-файла перед установкой
# Удаляем секцию BUNDLED WITH и лишние платформы, чтобы не путать старый RubyGems
RUN sed -i '/BUNDLED WITH/,+1d' Gemfile.lock && \
    bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache

COPY . .
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# --- Final Stage ---
FROM base
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

RUN mkdir -p storage public/analysis db log tmp && \
    chown -R rails:rails /rails storage public/analysis db log tmp && \
    chmod -R 775 /rails storage public/analysis db log tmp

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

USER 1000:1000
EXPOSE 80
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["./bin/thrust", "./bin/rails", "server"]