FROM elixir:1.20.2-otp-29-alpine AS build
RUN apk add --no-cache build-base git npm python3 linux-headers
ENV MIX_ENV=prod
WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs ./config/
RUN mix deps.get --only prod && mix deps.compile
COPY assets ./assets
RUN npm ci --prefix assets
COPY lib ./lib
COPY priv ./priv
RUN mix compile && mix assets.deploy
COPY config/runtime.exs ./config/runtime.exs
RUN mix release

FROM erlang:29.0.6-alpine AS runtime
RUN apk add --no-cache libstdc++ ncurses sqlite su-exec \
    && addgroup -S webapp && adduser -S -D -H -G webapp webapp
WORKDIR /app
COPY --from=build /app/_build/prod/rel/source_cat ./
COPY deploy/entrypoint.sh ./entrypoint.sh
ENV PHX_SERVER=true PORT=4000 POOL_SIZE=1 DATABASE_PATH=/data/sourcecat.sqlite RELEASE_TMP=/tmp/sourcecat
EXPOSE 4000
ENTRYPOINT ["/bin/sh", "/app/entrypoint.sh"]
CMD ["/app/bin/source_cat", "start"]
