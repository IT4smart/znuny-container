#!/bin/bash
set -e

# Get FQDN from environment variable, default to localhost
FQDN=${ZNUNY_FQDN:-localhost}

# Generate self-signed certificate if it doesn't exist
CERT_DIR="/etc/ssl/znuny"
mkdir -p "$CERT_DIR"

if [ ! -f "$CERT_DIR/znuny.key" ] || [ ! -f "$CERT_DIR/znuny.crt" ]; then
    echo "Generating self-signed certificate for $FQDN..."
    openssl req -x509 -newkey rsa:2048 -nodes \
        -out "$CERT_DIR/znuny.crt" \
        -keyout "$CERT_DIR/znuny.key" \
        -days 365 \
        -subj "/CN=$FQDN"
fi

# Start supervisord
exec supervisord --nodaemon --configuration /etc/supervisor/conf.d/znuny.conf
