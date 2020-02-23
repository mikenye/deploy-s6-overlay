#!/bin/bash

# This test script will test the deploy-s6-overlay.sh script on many different architectures/distributions

echo "========== Testing linux/amd64 distros ==========" &&
sudo docker buildx build --progress plain -f Dockerfile.testing.amd64 --platform linux/amd64 . &&
echo "========== Testing linux/arm64 distros ==========" &&
sudo docker buildx build --progress plain -f Dockerfile.testing.arm64.v8 --platform linux/arm64 . &&
echo "========== Testing linux/amd/v7 distros ==========" &&
sudo docker buildx build --progress plain -f Dockerfile.testing.arm.v7 --platform linux/arm/v7 . &&
echo "========== COMPLETED! =========="

