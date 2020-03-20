#!/bin/bash

# This test script will test the deploy-s6-overlay.sh script on many different architectures/distributions

docker context use x86_64
export DOCKER_CLI_EXPERIMENTAL="enabled"
docker buildx use homecluster

echo "========== Testing linux/amd64 distros =========="
docker buildx build --no-cache --progress plain -f Dockerfile.testing.amd64 --platform linux/amd64 . || exit 1

echo "========== Testing linux/arm64 distros =========="
docker buildx build --no-cache --progress plain -f Dockerfile.testing.arm64.v8 --platform linux/arm64 . || exit 1

echo "========== Testing linux/amd/v7 distros =========="
docker buildx build --no-cache --progress plain -f Dockerfile.testing.arm.v7 --platform linux/arm/v7 . || exit 1

echo "========== COMPLETED! =========="
