#!/usr/bin/env sh
#shellcheck shell=sh

APPNAME="deploy-s6-overlay"
echo "[$APPNAME] s6-overlay deployment started"

# If the user has not specified a version to deploy, pin version v3.1.5.0
if [ -z "$S6OVERLAY_VERSION" ]; then
  S6OVERLAY_VERSION="v3.2.0.0"
fi

# Determine which downloader to use
# Check if curl is available
if which curl > /dev/null 2>&1; then
  echo "[$APPNAME] Found curl"
  DOWNLOADER=curl
else
  # If no curl available, check if wget is available
  if which wget > /dev/null 2>&1; then
    echo "[$APPNAME] Found wget"
    DOWNLOADER=wget
  else
    echo "[$APPNAME] ERROR: no downloaders available! Install curl or wget."
    exit 1
  fi
fi

# If S6 architecture not specified...
if [ -z "${S6OVERLAY_ARCH}" ]; then

  echo "[$APPNAME] Determining architecture of target image"

  # If cross-building, we have no way to determine this without looking at the installed binaries using libmagic/file
  # Do we have libmagic/file installed

  # Make sure `file` (libmagic) is available
  FILEBINARY=$(which file)
  if [ -z "$FILEBINARY" ]; then
    echo "[$APPNAME] ERROR: 'file' (libmagic) not available, cannot detect architecture!"
    exit 1
  fi

  FILEOUTPUT=$("${FILEBINARY}" -L "${FILEBINARY}")

  # 32-bit x86
  # Example output:
  # /usr/bin/file: ELF 32-bit LSB shared object, Intel 80386, version 1 (SYSV), dynamically linked, interpreter /lib/ld-musl-i386.so.1, stripped
  # /usr/bin/file: ELF 32-bit LSB shared object, Intel 80386, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux.so.2, for GNU/Linux 3.2.0, BuildID[sha1]=d48e1d621e9b833b5d33ede3b4673535df181fe0, stripped
  if echo "${FILEOUTPUT}" | grep "Intel 80386" > /dev/null; then
    echo "[$APPNAME] Detected 32-bit x86 architecture. Intel i386 is not supported!"
    exit 1
  fi

  # x86-64
  # Example output:
  # /usr/bin/file: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-musl-x86_64.so.1, stripped
  # /usr/bin/file: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, for GNU/Linux 3.2.0, BuildID[sha1]=6b0b86f64e36f977d088b3e7046f70a586dd60e7, stripped
  if echo "${FILEOUTPUT}" | grep "x86-64" > /dev/null; then
    S6OVERLAY_ARCH="x86_64"
  fi

  # armel
  # /usr/bin/file: ELF 32-bit LSB shared object, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux.so.3, for GNU/Linux 3.2.0, BuildID[sha1]=f57b617d0d6cd9d483dcf847b03614809e5cd8a9, stripped
  if echo "${FILEOUTPUT}" | grep "ARM" > /dev/null; then

    S6OVERLAY_ARCH="arm"

    # armhf
    # Example outputs:
    # /usr/bin/file: ELF 32-bit LSB shared object, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-musl-armhf.so.1, stripped  # /usr/bin/file: ELF 32-bit LSB shared object, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-armhf.so.3, for GNU/Linux 3.2.0, BuildID[sha1]=921490a07eade98430e10735d69858e714113c56, stripped
    # /usr/bin/file: ELF 32-bit LSB shared object, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-armhf.so.3, for GNU/Linux 3.2.0, BuildID[sha1]=921490a07eade98430e10735d69858e714113c56, stripped
    if echo "${FILEOUTPUT}" | grep "armhf" > /dev/null; then
      S6OVERLAY_ARCH="armhf"
    fi

    # arm64
    # Example output:
    # /usr/bin/file: ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-musl-aarch64.so.1, stripped
    # /usr/bin/file: ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-aarch64.so.1, for GNU/Linux 3.7.0, BuildID[sha1]=a8d6092fd49d8ec9e367ac9d451b3f55c7ae7a78, stripped
    if echo "${FILEOUTPUT}" | grep "aarch64" > /dev/null; then
      S6OVERLAY_ARCH="aarch64"
    fi

  fi

fi

# If we don't have an architecture at this point, there's been a problem and we can't continue
if [ -z "${S6OVERLAY_ARCH}" ]; then
  echo "[$APPNAME] ERROR: Unable to determine architecture or unsupported architecture!"
  exit 1
fi

echo "[$APPNAME] Deploying s6-overlay version ${S6OVERLAY_VERSION} for architecture ${S6OVERLAY_ARCH}"

# grab the noarch tarball

# Download S6 Overlay
mkdir -p /tmp
echo "[$APPNAME] Downloading s6-overlay from: https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/"
echo "[$APPNAME] Downloading s6-overlay-noarch https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-noarch.tar.xz"
if [ "$DOWNLOADER" = "curl" ]
then
    # https://github.com/just-containers/s6-overlay/releases/download/v3.1.5.0/s6-overlay-noarch.tar.xz
    curl -s --location --output /tmp/s6-overlay-noarch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-noarch.tar.xz"
else
    wget -q -O /tmp/s6-overlay-noarch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-noarch.tar.xz"
fi

echo "[$APPNAME] Downloading s6-overlay-${S6OVERLAY_ARCH} https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.xz"

if [ "$DOWNLOADER" = "curl" ]
then
    # https://github.com/just-containers/s6-overlay/releases/download/v3.1.5.0/s6-overlay-x86_64.tar.xz
    curl -s --location --output /tmp/s6-overlay.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.xz"
else
    wget -q -O /tmp/s6-overlay.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.xz"
fi

# extract all the tarballs

echo "[$APPNAME] Extracting s6-overlay-noarch"
tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
echo "[$APPNAME] Extracting s6-overlay-${S6OVERLAY_ARCH}"
tar -C / -Jxpf /tmp/s6-overlay.tar.xz

# Test
echo "[$APPNAME] Testing s6-overlay"
/command/s6-clock > /dev/null || exit 1
/command/s6-echo > /dev/null || exit 1
/command/s6-hostname > /dev/null || exit 1
/command/s6-ls / > /dev/null || exit 1
/command/s6-ps > /dev/null || exit 1

# Clean up
echo "[$APPNAME] Cleaning up temp files"
rm /tmp/s6-overlay*

echo "[$APPNAME] s6-overlay deployment finished ok"