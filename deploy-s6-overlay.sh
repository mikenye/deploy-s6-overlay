#!/usr/bin/env sh
#shellcheck shell=sh

echo "s6-overlay deployment started."

# Determine which downloader to use
# Check if curl is available
which curl > /dev/null 2>&1
if [ $? -eq 0 ]
then
  echo "cURL available, using"
  DOWNLOADER=curl
else
  echo "cURL not available"
  # If no curl available, check if wget is available
  which wget > /dev/null 2>&1
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

# Determine if gpg is available to verify our download
which gpg > /dev/null 2>&1
if [ $? -eq 0 ]
then
  echo "gpg available, will verify s6-overlay download"
  VERIFY=1
else
  echo "WARNING: gpg not available! Cannot verify s6-overlay download!"
  VERIFY=0
fi

# If S6 version not specified...
if [ -z "${S6OVERLAY_VERSION}" ]; then
  # Determine which version of s6 overlay to use
  if [ "$DOWNLOADER" = "curl" ]
  then
    S6OVERLAY_VERSION=$(curl -s https://api.github.com/repos/just-containers/s6-overlay/releases/latest | grep '"name"' | head -1 | cut -d ":" -f 2 | tr -d " " | tr -d '"' | tr -d ",")
  elif [ "$DOWNLOADER" = "wget" ]
  then
    S6OVERLAY_VERSION=$(wget -O - -q https://api.github.com/repos/just-containers/s6-overlay/releases/latest | grep '"name"' | head -1 | cut -d ":" -f 2 | tr -d " " | tr -d '"' | tr -d ",")
  else
    echo "ERROR: could not determine downloader!"
    exit 1
  fi
fi

# If S6 architecture not specified...
if [ -z "${S6OVERLAY_ARCH}" ]; then
  # Use the architecture of the build platform
  ARCH=$(uname -m)

  # Make architecture names match s6 overlay architecture names
  if [ ${ARCH} = "aarch64" ]; then
    S6OVERLAY_ARCH="aarch64"
  elif [ ${ARCH} = "x86_64" ]; then

    # If cross-building for 32-bit, we have no way to determine this without looking at the installed binaries using libmagic/file
    # Do we have libmagic/file installed
    FILEBINARY=$(which file)
    if [ $? -eq 0 ]; then

      # if so, check platform that /bin/cp is compiled for

      # 80386 = x86
      $FILEBINARY -L /bin/cp | grep 80386
      if [ $? -eq 0 ]; then
        S6OVERLAY_ARCH="x86"
      fi

      # x86-64 = amd64
      $FILEBINARY -L /bin/cp | grep x86-64
      if [ $? -eq 0 ]; then
        S6OVERLAY_ARCH="amd64"
      fi

    else

      # if not, then warn that we can't detect (and thus may have incorrect s6-overlay architecture if cross-building)

      echo "WARNING: 'file' utility not available, cannot detect if cross-building!"
      S6OVERLAY_ARCH="amd64"
      
    fi

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
  if [ $VERIFY -eq 1 ]
  then
    curl -s --location https://keybase.io/justcontainers/key.asc | gpg --import
    curl -s --location --output /tmp/s6-overlay.tar.gz.sig https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz.sig
  fi
elif [ "$DOWNLOADER" = "wget" ]
then
  wget -q -O /tmp/s6-overlay.tar.gz https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz
  if [ $VERIFY -eq 1 ]
  then
    wget -q -O - https://keybase.io/justcontainers/key.asc | gpg --import
    wget -q -O /tmp/s6-overlay.tar.gz.sig https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz.sig
  fi
else
  echo "ERROR: could not determine downloader!"
  exit 1
fi

# Verify the download
if [ $VERIFY -eq 1 ]
then
  #cat /tmp/s6-overlay.key | gpg --import
  gpg --verify /tmp/s6-overlay.tar.gz.sig /tmp/s6-overlay.tar.gz
  if [ $? -eq 0 ]
  then
    echo "s6-overlay.tar.gz verified ok!"
  else
    echo "ERROR: s6-overlay.tar.gz did not verify ok."
    exit 1
  fi
fi

# Install s6-overlay
echo "Unpacking s6-overlay"
tar -xzf /tmp/s6-overlay.tar.gz -C /

# Clean up
echo "Cleaning up temp file"
rm /tmp/s6-overlay.tar.gz
if [ $VERIFY -eq 1 ]
then
  rm /tmp/s6-overlay.tar.gz.sig
fi

echo "s6-overlay deployment finished ok!"
