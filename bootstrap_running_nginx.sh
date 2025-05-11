#!/bin/bash

source config.env

if [ -z "${CERTBOT_DOMAINS:-}" ] || [ -z "${CERTBOT_EMAIL}" ]; then
    echo "certbot parameters not specified!"
    exit 0
fi

if [ -n "${CERTBOT_TEST_CERT:-}" ]; then
    use_test_cert="--test-cert"
fi

echo "Bootstrapping ${CERTBOT_DOMAINS[*]}"

for domain in "${CERTBOT_DOMAINS[@]}"; do
    echo "Getting certificate for ${domain}"
    podman compose exec nginx \
        certbot certonly ${use_test_cert} --webroot -w /opt/certbot/www/html --keep -d ${domain} -m ${CERTBOT_EMAIL} --agree-tos -n
done
