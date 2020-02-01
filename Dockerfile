FROM caddy/caddy:scratch as caddy_builder

FROM trojangfw/trojan:latest
LABEL TROJAN_VER='1.14.1'
LABEL CADDY_VER='2.0.13'

#FROM alpine:latest
ARG TC_VERSION='0.01'

# 定义相关参数
ARG CONF_DIR="/root/.config"
ARG WWWSRC="/root/caddy/www"
ARG Caddy_conf="/root/.config/caddy"
ARG Trojan_conf="/root/.config/trojan"

ENV WWWSRC=${WWWSRC}
ENV Caddy_conf=${Caddy_conf}
ENV Trojan_conf=${Trojan_conf}

# 安装caddy
COPY --from=caddy_builder /usr/bin/caddy /usr/local/bin/
COPY --from=caddy_builder /etc/ssl/certs /etc/ssl/certs/ca-certificates.crt 

ARG TZ='Asia/Shanghai'
ENV TZ=${TZ}
RUN apk upgrade --update \
    && apk add --no-cache \
        tzdata \
        curl \
        openssl \
        zip \
    && cp -f /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && apk del \
        tzdata \
    && rm -rf /var/cache/apk/*

COPY caddy.sh /root/caddy.sh
COPY index.html ${WWWSRC}/
RUN chmod +x /root/caddy.sh

COPY Caddyfile ${Caddy_conf}/Caddyfile.bak
COPY trojan.json ${Trojan_conf}/trojan.json

# 维护版本信息
LABEL maintainer="jxinran janboo.one@gmail.com" \
    image.version=${TC_VERSION} \
    description="Auto depoy trojan + caddy2 in Docker!"

EXPOSE 443 80 2019

VOLUME /root/.acme.sh
VOLUME ${WWWSRC}

WORKDIR /root
ENTRYPOINT ["/root/caddy.sh"]