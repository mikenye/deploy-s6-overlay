#!/bin/sh

# Determine which downloader to use
# Check if curl is available
CURLBINARY=`which curl`
if [ $? -eq 0 ]
then
  echo "cURL available, using"
  DOWNLOADER=curl
else
  echo "cURL not available"
  # If no curl available, check if wget is available
  WGETBINARY=`which wget`
  if [ $? -eq 0 ]
  then
    echo "wget available, using"
    DOWNLOADER=wget
  else
    echo "wget not available"
    echo ""
    echo "ERROR: no downloaders available! Install curl or wget."
    exit 1
  fi
fi

# If S6 version not specified...
if [ -z "${S6OVERLAY_VERSION}" ]; then
  # Determine which version of s6 overlay to use
  if [ "$DOWNLOADER" = "curl" ]
  then
    S6OVERLAY_VERSION=`curl -s https://api.github.com/repos/just-containers/s6-overlay/releases/latest | grep '"name"' | head -1 | cut -d ":" -f 2 | tr -d " " | tr -d '"' | tr -d ","`
  elif [ "$DOWNLOADER" = "wget" ]
  then
    S6OVERLAY_VERSION=`wget -O - -q https://api.github.com/repos/just-containers/s6-overlay/releases/latest | grep '"name"' | head -1 | cut -d ":" -f 2 | tr -d " " | tr -d '"' | tr -d ","`
  else
    echo "ERROR: could not determine downloader!"
    exit 1
  fi
fi

# If S6 architecture not specified...
if [ -z "${S6OVERLAY_ARCH}" ]; then
  # Use the architecture of the build platform
  ARCH=`uname -m`
  
  # Make architecture names match s6 overlay architecture names
  if [ ${ARCH} = "aarch64" ]; then
    S6OVERLAY_ARCH="aarch64"
  elif [ ${ARCH} = "x86_64" ]; then
    S6OVERLAY_ARCH="amd64"
  elif [ ${ARCH} = "armv7l" ]; then
    S6OVERLAY_ARCH="armhf"
  else
    echo "Unknown architecture"
    exit 1
  fi
fi
  
echo "Will deploy s6-overlay version ${S6OVERLAY_VERSION} for architecture ${S6OVERLAY_ARCH}"

# Download S6 Overlay
mkdir -p /tmp
echo "Getting s6-overlay from: https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz"
# Determine which version of s6 overlay to use
if [ "$DOWNLOADER" = "curl" ]
then
  curl -s --location --output /tmp/s6-overlay.tar.gz https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz
elif [ "$DOWNLOADER" = "wget" ]
then
  wget -q -O /tmp/s6-overlay.tar.gz -q https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz
else
  echo "ERROR: could not determine downloader!"
  exit 1
fi

# Install s6-overlay
echo "Unpacking s6-overlay"
tar -xzf /tmp/s6-overlay.tar.gz -C /

# Clean up
echo "Cleaning up temp file"
rm /tmp/s6-overlay.tar.gz

