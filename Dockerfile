# syntax=docker/dockerfile:1
# Используем официальный образ Ultralytics как фундамент
FROM ultralytics/ultralytics:latest-cpu AS base

USER root
WORKDIR /rails

# 1. Установка системных пакетов для Ruby и Rails
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    ruby-full build-essential libpq-dev git curl postgresql-client libvips libjemalloc2 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# 2. Исправление менеджера гемов (Убирает ошибку nil:NilClass)
RUN gem update --system && \
    gem install bundler -v 2.4.10

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libjemalloc.so.2"

# --- Build Stage ---
FROM base AS build

COPY Gemfile Gemfile.lock ./

# 3. ХАК: Удаляем привязку к странной версии 4.0.8 и ставим гемы
RUN sed -i '/BUNDLED WITH/,+1d' Gemfile.lock && \
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