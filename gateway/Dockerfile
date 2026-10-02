FROM caddy:2.11.4-alpine@sha256:6aeddd44c3078b0f9a35206472a11420648a79c184603ef95957d0a20044cb2b
RUN setcap -r /usr/bin/caddy && chown -R 10001:10001 /data /config
COPY Caddyfile /etc/caddy/Caddyfile
COPY legal /srv/legal
USER 10001:10001
