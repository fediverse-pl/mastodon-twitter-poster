FROM node:8.11.3-alpine as node
FROM ruby:2.5-alpine

LABEL maintainer="https://github.com/renatolond/mastodon-twitter-poster" \
      description="Crossposter to post statuses between Mastodon and Twitter"

ARG UID=991
ARG GID=991

ENV PATH=/crossposter/bin:$PATH \
    RAILS_SERVE_STATIC_FILES=true \
    RAILS_ENV=production \
    NODE_ENV=production

EXPOSE 3000 4000

WORKDIR /crossposter

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /usr/local/bin/npm /usr/local/bin/npm
COPY --from=node /opt/yarn-* /opt/yarn

RUN apk -U upgrade \
 && apk add -t build-dependencies \
    build-base \
    postgresql-dev \
    python \
    file-dev \
 && apk add \
    ca-certificates \
    git \
 && update-ca-certificates \
 && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn \
 && ln -s /opt/yarn/bin/yarnpkg /usr/local/bin/yarnpkg \
 && mkdir -p /opt \
 && cd /crossposter \
 && rm -rf /tmp/* /var/cache/apk/*

COPY Gemfile Gemfile.lock package.json yarn.lock .yarnclean /crossposter/

RUN bundle config build.nokogiri --with-iconv-lib=/usr/local/lib --with-iconv-include=/usr/local/include \
 && bundle install -j$(getconf _NPROCESSORS_ONLN) --deployment --without test development \
 && yarn install --pure-lockfile --ignore-engines \
 && yarn cache clean

RUN addgroup -g ${GID} crossposter && adduser -h /crossposter -s /bin/sh -D -G crossposter -u ${UID} crossposter \
 && mkdir -p /crossposter/public/system /crossposter/public/assets /crossposter/public/packs \
 && chown -R crossposter:crossposter /crossposter/public

COPY . /crossposter

RUN chown -R crossposter:crossposter /crossposter

VOLUME /crossposter/public/system

USER crossposter

RUN SECRET_KEY_BASE=precompile_placeholder bundle exec rails assets:precompile

ENTRYPOINT ["/sbin/tini", "--"]
