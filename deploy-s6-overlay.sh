#!/usr/bin/env sh
#shellcheck shell=sh

APPNAME="deploy-s6-overlay"
echo "[$APPNAME] s6-overlay deployment started"

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

# If S6 version not specified...
if [ -z "${S6OVERLAY_VERSION}" ]; then
  echo "[$APPNAME] Determining latest version of s6-overlay"
  # Determine which version of s6 overlay to use
  if [ "$DOWNLOADER" = "curl" ]
  then
    S6OVERLAY_VERSION=$(curl -s https://api.github.com/repos/just-containers/s6-overlay/releases/latest | grep '"name"' | head -1 | cut -d ":" -f 2 | tr -d " " | tr -d '"' | tr -d ",")
  elif [ "$DOWNLOADER" = "wget" ]
  then
    S6OVERLAY_VERSION=$(wget -O - -q https://api.github.com/repos/just-containers/s6-overlay/releases/latest | grep '"name"' | head -1 | cut -d ":" -f 2 | tr -d " " | tr -d '"' | tr -d ",")
  else
    echo "[$APPNAME] ERROR: could not determine downloader!"
    exit 1
  fi
fi

# version variable that has no leading v
S6OVERLAY_VERSION_NO_LEADING_V=$(echo "$S6OVERLAY_VERSION" | tr -d "v")

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
    S6OVERLAY_ARCH="x86"
  fi

  # x86-64
  # Example output:
  # /usr/bin/file: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-musl-x86_64.so.1, stripped
  # /usr/bin/file: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, for GNU/Linux 3.2.0, BuildID[sha1]=6b0b86f64e36f977d088b3e7046f70a586dd60e7, stripped
  if echo "${FILEOUTPUT}" | grep "x86-64" > /dev/null; then
    S6OVERLAY_ARCH="amd64"
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

# Download S6 Overlay binaries/signatures/checksums
mkdir -p /tmp

# Determine which version of s6 overlay to use
if [ "$DOWNLOADER" = "curl" ]; then

  # attempt to download binary tarball with .tar.xz extension (for newer releases)
  if curl -s --location --output /tmp/s6-overlay.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}-${S6OVERLAY_VERSION_NO_LEADING_V}.tar.xz"; then
    echo "[$APPNAME] s6-overlay binaries downloaded OK"

  # if above failed, attempt to download binary tarball with .tar.gz extension (for older releases)
  elif curl -s --location --output /tmp/s6-overlay.tar.gz "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz"; then
    echo "[$APPNAME] s6-overlay binaries downloaded OK"

  # if above downloads all failed, then error
  else
    echo "[$APPNAME] ERROR: could not download s6-overlay binaries!"
    exit 1
  fi

  # attempt to download binary checksum with .tar.xz.sha256 extension (for newer releases)
  if curl -s --location --output /tmp/s6-overlay.tar.xz.sha256 "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}-${S6OVERLAY_VERSION_NO_LEADING_V}.tar.xz.sha256"; then
    echo "[$APPNAME] s6-overlay binaries downloaded OK"

  # if above failed, attempt to download signature with .tar.gz.sig extension (for older releases)
  elif curl -s --location --output /tmp/s6-overlay.tar.gz.sig "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz.sig"; then
    echo "[$APPNAME] s6-overlay binaries downloaded OK"

  # if above downloads all failed, then error
  else
    echo "[$APPNAME] ERROR: could not download s6-overlay checksum/signature!"
    exit 1
  fi

elif [ "$DOWNLOADER" = "wget" ]; then

  # attempt to download binary tarball with .tar.xz extension (for newer releases)
  if wget -q -O /tmp/s6-overlay.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}-${S6OVERLAY_VERSION_NO_LEADING_V}.tar.xz"; then
    echo "[$APPNAME] s6-overlay binaries downloaded OK"

  # if above failed, attempt to download binary tarball with .tar.gz extension (for older releases)
  elif wget -q -O /tmp/s6-overlay.tar.gz "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz"; then
    echo "[$APPNAME] s6-overlay binaries downloaded OK"

  # if above downloads all failed, then error
  else
    echo "[$APPNAME] ERROR: could not download s6-overlay binaries!"
    exit 1
  fi

  # attempt to download binary checksum with .tar.xz.sha256 extension (for newer releases)
  if wget -q -O /tmp/s6-overlay.tar.xz.sha256 "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}-${S6OVERLAY_VERSION_NO_LEADING_V}.tar.xz.sha256"; then
    echo "[$APPNAME] s6-overlay binaries downloaded OK"

  # if above failed, attempt to download signature with .tar.gz.sig extension (for older releases)
  elif wget -q -O /tmp/s6-overlay.tar.gz.sig "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz.sig"; then
    echo "[$APPNAME] s6-overlay binaries downloaded OK"

  # if above downloads all failed, then error
  else
    echo "[$APPNAME] ERROR: could not download s6-overlay checksum/signature!"
    exit 1
  fi

# if no wget/curl, then error
else
  echo "[$APPNAME] ERROR: could not determine downloader!"
  exit 1
fi

# Verify the download if possible

# verify .tar.xz.sha256 (for newer releases)
if [ -e /tmp/s6-overlay.tar.xz.sha256 ]; then
  SHA256SUM=$(cat /tmp/s6-overlay.tar.xz.sha256 | tr -s " " | cut -d " " -f 1)
  if echo "$SHA256SUM /tmp/s6-overlay.tar.xz" | sha256sum --check; then
    echo "[$APPNAME] checksum verified ok"
  else
    echo "[$APPNAME] ERROR: checksum did not verify ok"
    exit 1
  fi

# verify .tar.gz.sig (for older releases)
elif [ -e /tmp/s6-overlay.tar.gz.sig ]

  # check if gpg is available
  if which gpg > /dev/null 2>&1; then
    echo "[$APPNAME] Found gpg, will attempt to verify"

    # import key   
    gpg --keyserver hkps://keyserver.ubuntu.com --recv 337EE704693C17EF

    # verify signature
    if gpg --verify /tmp/s6-overlay.tar.gz.sig /tmp/s6-overlay.tar.gz;
    then
      echo "[$APPNAME] s6-overlay.tar.gz verified ok"
    else
      echo "[$APPNAME] ERROR: s6-overlay.tar.gz did not verify ok"
      exit 1
    fi

  else
    echo "[$APPNAME] WARNING: gpg not found. Unable to verify download."
  fi

# should never get here, so error
else
  echo "[$APPNAME] WARNING: no checksum/signature file available. Unable to verify download."
fi

# Install s6-overlay
echo "[$APPNAME] Unpacking s6-overlay"

# attempt to unpack .tar.xz
if [ -e /tmp/s6-overlay.tar.xz ]; then
  if tar -hf /tmp/s6-overlay.tar.xz -C /; then
    echo "[$APPNAME] s6-overlay unpacked ok"
  else
    echo "[$APPNAME] ERROR: s6-overlay did not unpack ok!"
    exit 1
  fi

# attempt to unpack .tar.gz
elif [ -e /tmp/s6-overlay.tar.gz ]; then
  if tar -hf /tmp/s6-overlay.tar.gz -C /; then
    echo "[$APPNAME] s6-overlay unpacked ok"
  else
    echo "[$APPNAME] ERROR: s6-overlay did not unpack ok!"
    exit 1
  fi

# should never get here, so error
else
  echo "[$APPNAME] ERROR: no tarball to unpack!"
  exit 1

fi

# Test
echo "[$APPNAME] Testing s6-overlay"
/bin/s6-clock > /dev/null || exit 1
/bin/s6-echo > /dev/null || exit 1
/bin/s6-hostname > /dev/null || exit 1
/bin/s6-ls / > /dev/null || exit 1
/bin/s6-ps > /dev/null || exit 1

# Clean up
echo "[$APPNAME] Cleaning up temp files"

if [ -e /tmp/s6-overlay.tar.xz ]; then
  rm /tmp/s6-overlay.tar.xz
fi

if [ -e /tmp/s6-overlay.tar.gz ]; then
  rm /tmp/s6-overlay.tar.gz
fi

if [ -e /tmp/s6-overlay.tar.xz.sha256 ]; then
  rm /tmp/s6-overlay.tar.xz.sha256
fi

if [ -e /tmp/s6-overlay.tar.gz.sig ]; then
  rm /tmp/s6-overlay.tar.gz.sig
fi

echo "[$APPNAME] s6-overlay deployment finished successfully"
exit 0
