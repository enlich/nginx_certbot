FROM nginx

LABEL org.opencontainers.image.source https://github.com/enlich/nginx_certbot

# Install other packages
RUN apt-get update && \
    apt-get install -y \
        python3 \
        python3-venv \
        libaugeas0 \
        cron \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/certbot/venv && \
    /opt/certbot/venv/bin/pip install --upgrade pip && \
    /opt/certbot/venv/bin/pip install \
        certbot \
        && \
    ln -s /opt/certbot/venv/bin/certbot /usr/bin/certbot && \
    mkdir -p /opt/certbot/www/html && \
    mkdir -p /opt/certbot/www/conf

# Simple configuration to bootstrap the first certificate
COPY nginx_bootstrap_cert.conf /opt/certbot/www/conf/nginx_bootstrap_cert.conf

# Configuration for webroot with certbot
COPY nginx_webroot.conf /opt/certbot/www/conf/nginx_webroot.conf

COPY nginx_default.conf /etc/nginx/conf.d/default.conf

RUN mkdir -p /opt/www/conf && \
    mkdir -p /opt/www/conf.d

# SSL configuration options for each server
COPY nginx_ssl.conf /opt/www/conf/nginx_ssl.conf

# Useful proxy parameters
COPY nginx_proxy.conf /opt/www/conf/nginx_proxy.conf
