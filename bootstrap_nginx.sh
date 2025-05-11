#!/bin/bash

source config.env

bootstrap_container_name=${NGINX_BOOTSTRAP_NAME:-nginx_bootstrap}

if [ -z "${CERTBOT_DOMAINS:-}" ] || [ -z "${CERTBOT_EMAIL}" ]; then
    echo "certbot parameters not specified!"
    exit 0
fi

if [ -n "${CERTBOT_TEST_CERT:-}" ]; then
    use_test_cert="--test-cert"
fi

echo "Bootstrapping ${CERTBOT_DOMAINS[*]} with ${bootstrap_container_name}"

echo "Starting nginx"
podman compose run --name ${bootstrap_container_name}  --service-ports --no-deps -d nginx \
    nginx -g "daemon off;" -c /opt/certbot/www/conf/nginx_bootstrap_cert.conf

for domain in "${CERTBOT_DOMAINS[@]}"; do
    echo "Getting certificate for ${domain}"
    podman container exec ${bootstrap_container_name} \
        certbot certonly ${use_test_cert} --webroot -w /opt/certbot/www/html --keep -d ${domain} -m ${CERTBOT_EMAIL} --agree-tos -n
done

echo "Killing and cleaning"
podman container kill ${bootstrap_container_name}
podman container rm ${bootstrap_container_name} --volumes
