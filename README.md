# `nginx_certbot`

Reverse proxy or host a website with [nginx](https://nginx.org/) while getting certificates from [Let's Encrypt](https://letsencrypt.org/) via [certbot](http://certbot.eff.org/). This project is built around using [podman](https://podman.io/) and [podman-compose](https://github.com/containers/podman-compose) to start and run the `nginx` server.

## Goals

Other solutions were not able to meet my desired setup so I went about creating my own setup. These were my goals:
* Avoid exposing the docker socket.
* Ability to run rootless.
* Secure as possible.
* Avoid losing client source IP.
* Automatically renew certificates.
* Simple and easy to add new sites.
* Learn `podman` and `nginx`.

## Configuration

### [`config.env`](config.env)

This file contains the domains and some configuration, primarily used in the bootstrapping of the initial certificates.
* `CERTBOT_DOMAINS`: List of domains to use with `certbot`. The bootstrap will run `certbot` with each of these domains to get individual certificates.
* `CERTBOT_EMAIL`: E-mail to use with `-m` when calling `certbot`. It's used by Let's Encrypt for things like certificate expiration notification.
* `CERTBOT_TEST_CERT`: Set to a non-empty string to use `--test-cert` with `certbot`.

### [`conf.d`](conf.d)

This directory contains the `nginx` configurations for each server. `nginx` can support multiple domains via each `server` block.

For each `server` block, you may want to re-use some useful configuration snippets:
* [`/opt/www/conf/nginx_ssl.conf`](nginx_certbot/nginx_ssl.conf): Contains SSL port (443) and other suggested SSL params for a `server` block context. **Mandatory for using HTTPS**.
* [`/opt/certbot/www/conf/nginx_webroot.conf`](nginx_certbot/nginx_webroot.conf): Contains the configuration for serving the [HTTP-01 challenge](https://letsencrypt.org/docs/challenge-types/#http-01-challenge) for ACME. **Mandatory for using HTTPS**.
* [`/opt/www/conf/nginx_proxy.conf`](nginx_certbot/nginx_proxy.conf): Contains proxy headers for a `location` context. **Optional for proxying**.

Each `server` block should `include` [`/opt/www/conf/nginx_ssl.conf`](nginx_certbot/nginx_ssl.conf) and [`/opt/certbot/www/conf/nginx_webroot.conf`](nginx_certbot/nginx_webroot) and define a [`server_name`](https://nginx.org/en/docs/http/ngx_http_core_module.html#server_name). [`ssl_certificate`](https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_certificate) and [`ssl_certificate_key`](https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_certificate_key) determines the certificate to use. These paths should point to the files in `/etc/letsencrypt/live/your.domain.com/`. **Do not use the `$server_name` since these files are owned by root in the docker and variable resolution is done by `nginx` on the HTTP request after privileges have been dropped.**

## Running

1. Configure according to [Configuration](#Configuration).
2. Run the bootstrap script to get the initial certificates:
```
$ ./bootstrap_nginx.sh
```
3. Start the container using the [`docker-compose.yml`](docker-compose.yml):
```
$ podman compose up -d
```

### Adding additional sites

1. Add the new domain to [`config.env`](#configenv)
2. Bootstrap to get new certificates for all domains:
```
$ ./bootstrap_running_nginx.sh
```
Note: This uses `--keep` with `certbot` to avoid getting certificates for existing domains.

3. Add the new domain's `server` block to a configuration in [`conf.d`](#confd)
4. Reload the `nginx` configuration:
```
$ ./reconfig_nginx.sh
```

## Implementation

### Docker Compose Project

The `nginx_certbot` [docker image](nginx_certbot/Dockerfile) is based on `nginx` and primarily contains these components:
* `nginx`: Serving content and reverse proxying.
* `certbot`: For automatically generating and fetching certificates.
* `cron`: For automatically renewing certificates.

A volume (`cert`) is used to store the generated certificates and mounted to `/etc/letsencrypt`.

[`slip4netns`](https://github.com/rootless-containers/slirp4netns) is used as the `port_handler` in the `network_mode` to avoid losing the source IP address. **The default `rootlesskit` translates to the host container address**. `allow_host_loopback` allows the `nginx_certbot` container to reach the back-end services with exposed ports on the host using `10.0.2.2`.


### `nginx` notes

`/etc/nginx/conf.d/default.conf` is replaced to redirect HTTP to HTTPS and set the modern configuration for SSL. This is based on the [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/). It includes the configurations in [`/opt/www/conf.d`](#confd).

### `certbot` notes

The [`bootstrap_nginx.sh`](bootstrap_nginx.sh) for certificates is performed using `podman compose run` to spin up a container just to run `certbot certonly --webroot` with a default `nginx` configuration. This avoids the configuration failing due to missing certificates.

### `cron` notes

The `cron` job for renewal occurs at 0000 and 1200. The `--deploy-hook` will signal `nginx` to reload.
