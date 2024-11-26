#!/bin/bash

# Ensure avahi-utils is installed
if ! command -v avahi-resolve &> /dev/null
then
    echo "avahi-utils could not be found. Please install it first."
    exit 1
fi

# Query umbrel.local via mDNS to obtain the IPv4 address
UMBREL_IP=$(avahi-resolve -4 -n umbrel.local | awk '{print $2}')

# Check if the IP address was obtained successfully
if [ -z "$UMBREL_IP" ]; then
    echo "Failed to resolve umbrel.local. Please check your mDNS configuration."
    exit 1
fi

#docker buildx rm mybuilder
#docker buildx create --name mybuilder --use
#docker buildx inspect --bootstrap

# This is a buildx script which will push docker image in custom registry
docker buildx build --platform linux/amd64,linux/arm64 -t ${UMBREL_IP}:5000/amnezia-wg-easy-decker:latest --output=type=registry,registry.insecure=true --push .
