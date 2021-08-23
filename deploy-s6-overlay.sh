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

# Determine if gpg is available to verify our download
if which gpg > /dev/null 2>&1; then
  echo "[$APPNAME] Found gpg"
  VERIFY=1
else
  echo "[$APPNAME] WARNING: gpg not available! Cannot verify s6-overlay download!"
  VERIFY=0
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

# If S6 architecture not specified...
if [ -z "${S6OVERLAY_ARCH}" ]; then

  echo "[$APPNAME] Determining architecture of target image"

  #-----
  #
  # This old method of using `uname -m` has been abandoned.
  # If cross-building (ie: building for i386 on amd64),
  # You'd get the wrong architecture, as `uname -m` would return amd64.

  # # Use the architecture of the build platform
  # ARCH=$(uname -m)

  # # Make architecture names match s6 overlay architecture names
  # if [ ${ARCH} = "aarch64" ]; then
  #   S6OVERLAY_ARCH="aarch64"
  # elif [ ${ARCH} = "x86_64" ]; then
  #   S6OVERLAY_ARCH="amd64"
  # elif [ ${ARCH} = "armv7l" ]; then
  #   S6OVERLAY_ARCH="armhf"
  # else
  #   echo "Unknown architecture"
  #   exit 1
  # fi
  #
  #-----

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

# Download S6 Overlay
mkdir -p /tmp
echo "[$APPNAME] Downloading s6-overlay from: https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz"
# Determine which version of s6 overlay to use
if [ "$DOWNLOADER" = "curl" ]
then
  curl -s --location --output /tmp/s6-overlay.tar.gz "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz"
  if [ $VERIFY -eq 1 ]
  then
#     echo "[$APPNAME] Importing justcontainers gpg key from: https://keybase.io/justcontainers/key.asc"
#     curl -s --location https://keybase.io/justcontainers/key.asc | gpg --import
    echo "[$APPNAME] Downloading s6-overlay signature from: https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz.sig"
    curl -s --location --output /tmp/s6-overlay.tar.gz.sig "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz.sig"
  fi
elif [ "$DOWNLOADER" = "wget" ]
then
  wget -q -O /tmp/s6-overlay.tar.gz "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz"
  if [ $VERIFY -eq 1 ]
  then
#     echo "[$APPNAME] Importing justcontainers gpg key from: https://keybase.io/justcontainers/key.asc"
#     wget -q -O - https://keybase.io/justcontainers/key.asc | gpg --import
    echo "[$APPNAME] Downloading s6-overlay signature from: https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz.sig"
    wget -q -O /tmp/s6-overlay.tar.gz.sig "https://github.com/just-containers/s6-overlay/releases/download/${S6OVERLAY_VERSION}/s6-overlay-${S6OVERLAY_ARCH}.tar.gz.sig"
  fi
else
  echo "[$APPNAME] ERROR: could not determine downloader!"
  exit 1
fi

# Verify the download
if [ $VERIFY -eq 1 ]; then

  echo """
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBFe3YfMBEAC6pERKLjXDcWWrMU9l68ujJkbCjtnKYRKsIjsmvoETHJkCZaHX
X0JoVFth7OEhEh8wQG6PTWb6HPFWJxKJaLTOS6d5xc7i8iMWFjUkssh7jEJY0unO
N8OleggjL4bPz2RaOx5hKJru1A8BjDdT4XyYWk+PFjaJGmll7FyqyVIng2bGRYgR
ah+CjKPjzk1RX5cfz48lO1wgFs4rzd/SrpcbqMW1nv57ZCNK1nPrDpXytrMA2ZaM
xWa5I13NXTQ9hJw0yhCV46f+4vXBvz4l0HrVqlZE16iaiW9rniHHM1FFqH9aOMU6
PWWNzrO4cyMiNBEgLT5jNAFFteKufUKaOlGRT768kyRfvC/uYND3BdZ8EcC+e8Fe
+g7Xj/L85853XeCApDIT+FG4Poiby71SWu/PDk9qm/BJ18kh6f8EJvWJWMBQJCQH
Ys5LWEU0BUSnFucbJhd6wF+47wDC9hByvwSOc+5Q4BIj4WHoOCYjaeX5ET2Kto7+
E4UZjC+38q0G7oH4sOfe7FFHW/R9y/9AUj/AGhNx+lyruKOXKuTZByZlHZKWV4LT
mkey3NIRahYKWWZIBN8ndAkP62QHuMGfWOKDC6VwgFVQGkHGYZ3NuEUNsN35P77X
Y7G7K8dVwlidTS57JZarNpILNJJsYkfMd6zrRZf9a+cZWMxyvgXKgaCx4QARAQAB
tDVKdXN0IENvbnRhaW5lcnMgQm90IDxqdXN0LmNvbnRhaW5lcnMucm9ib3RAZ21h
aWwuY29tPokCNAQTAQoAHgUCV7dh8wIbAwMLCQcDFQoIAh4BAheAAxYCAQIZAQAK
CRBhAbJ4Oy/RYQrJD/49WWEJXgcZClEtBQUTo9KZKehAh9K5+455/lFtUh8YEhiF
+7HAVlOL3KlGbg/ZUXkrXbGMW4Cm91nz99Fr+rZpLPcogZ0Lox5IVPn6zjmxRrWu
aEvH/SlnhjUiBj9/rMgWwzTSV0PLP6bOhMJ0NIteAgW+jzSy4Sf4N+3XE1HAeL3s
UtYex0FXzRTQAjMAnCa6AJS1dCJRc0tuI13XkiZnVnqELF2CCSnaPj6ohn/90/sK
hr7PSGQznagiAjG49nzqOE/9CRVOy8JqNS+1Y8A1PmCVofvgy3uaPKL/yLMRXk2j
+5Fed9aVGXG3JE5lJjWUAyeL3jTEdE336tc+kHVUXrTSza/akvFHTJQfaw+MVuRI
PT2JvZLlePOxHgM+U9eOJ7rwXYoLS/e5KrGvhi+LCMO3r4UfIGL3cgtGkM7rwvfY
3uMCq7hfoA6d4SGwh99J6h3M7O9+UxB4VH8yjQJl6ghY0ruEgp1PpKSo9Ogdz/lo
ZpEExnOzp4zrdFalKcy9ehUhOdy/S79NlKsWOE1DtbM6IQHDxZplT9IJhTxuqrDg
sIaYgwUxipqvA/kEU5k5QIIoJU8u5o6iZLuC6mlqOhjmLst6/ndXuVAG4GwDKrwx
ri3zmctxHRwDzTJXsZsKYOqrheO6HRu+6VVVNAI5Q/nI/vN79vbZGAb8Z5PgZrkB
DQRXt2HzAQgAsrKhLIusc/9dUOPi9f3FN30obwZLZRp8qTNDglqSyAaL5WiiGJII
1erM66s1dIv1qqUbTNd6nAKfb2w5zbgAOTAKsGNEzljFKAApdZm/sAykWx9PTqVQ
ov6PAjzgoWC9yH8UcxhvxPtpw+rqnz1oUVK9paszoZWuPz5jAE/ZhdrEXy/51ckS
jJ/p8T55SFK3p6UzSGDqQRfDwHDgDJMIzPABpnPk+ETf/YYWbJwOx81YrlRKBau8
XdyBkRlKZeZ+SrvDMugn45lWSdjXJZ2BH1U7akuWd7lYP3xI/Vfs2rF3e+7+72W7
5s/3pOVckdbgn13BREgdptgOBX9ILCtpwQARAQABiQNEBBgBCgAPBQJXt2HzBQkP
CZwAAhsiASkJEGEBsng7L9FhwF0gBBkBCgAGBQJXt2HzAAoJECU2yhbfT82iCzoH
/iAw5+zBpXdE3Ju/KrCpZ4JwzSkAw4n7uj4UzTtzYb5KfkXAkIQFq5MTHJ6jpHe6
g6aJf5Z4NV2cbw/4d9W5rAzXkuKnksoo7JbRDt+TadCBCuoz8HvkVT4lgV6TTWx3
kMESGaqz/y0d8P+FRCKhmbv4ayTAZZJM2cdDcqtum8sYPs9Rd6L13x8hZGTSKavL
wus64/GA2tOa334zDDI1+7AoJRRLApqdYZmX/LrQykNoNR7RSzLIn5+SGdCS6JU8
c0oQnJgf+7zililWqagkYRqaHhcBy90XiYOPMdHyKmudcfvpYLE78E0iyHhfmsAj
I+pK3U4MquRA+v8AfL5/PLRKbhAAomTfB2WPI9ea1nN6OfCZZE9bq/PVmeahW0CZ
oBmCQJLnoypbBtMUnOhSFd+QUWekH8+prkvq15s8LdjfhJWlzMRbwourZvffmeHX
8dTuMZwwV+7flnf+AH9OnwcKNg5/T4aRm3gZGSV7fTFh1Regx3136TIyRcwPqjwq
bc9slW6Bg9veE3ayveUKaG0SWDjkPad4wqFWTF84vAD+T6p1hMxBrInkj8ocHXky
xdndQAuVd4dCjdm/dlpFs/ntZFhVQUFGzjqZaSvqQpKIui1x3WDap1RFy7n81B/e
23eO+R8CyJg+upI38FIroR38EGhEFAjgcqKSi+0fWDsXR49XjIO5EX7RkFhnMudv
MA+sW2PsI7yAfIFrTO8VEnevAwsVNIeTpyYnVVFBTUGeRP5u9eNoLO3wHpARvsT4
JtmdVWoTX2XzQA9xXa+6cOmiT4XLnwtIU4a8W1dfINqMUVLBhIJD2zvLTppISqzm
IISugSMiNND0kvkp9moYXz0QodrEHzJDZmzqbTv5IAs+gPER1eNS2BZKJjXJ7Egn
2JDWIRgm2kzS1BaSyL004F39AfsKCBcsBsbsTIUcmpRUwLjMpdkomkGGA3RHnfk0
6odrEEQO72ZOIsIwd1+X5U8tK9pnEH0/RsZONUMPtGrQ4Pe0ZlNZUHCyN6U633MU
O32Wmru5AQ0EV7dh8wEIAOAvY6Wrlp6k/Fknu/wIZLWoGIOTR11iYgHHvVWWeoat
leewsqHbzCMiCQ5txX5RJJv7F5xDURmoqwpKdkjFVqriuCt506MeztBohRqTvDYO
czS/eQJuI+pR9/aGmESErP9+B9AmQ+rNno391Z+HRI75VIP+AnTZGYVMec5fQbFU
wws3Dt9VeXgPIPixfVoXtz5vQPj9EfH3RTQ//9VzzznZkHBPFMroM3VLznwlDb9a
2Z4S4WVgztMMrZnlYmym6tN1sm61TPNK+4KFy+FNFbudcHcgAXXT7H5/rNhUD8aM
MLAQHqNCeg/eXCQO0Sp2TzBs/x90jti9cGmyMfsZDKkAEQEAAYkDRAQYAQoADwUC
V7dh8wUJDwmcAAIbDAEpCRBhAbJ4Oy/RYcBdIAQZAQoABgUCV7dh8wAKCRDZBk7K
WLNt46vQB/0QOlN8vMJNVlJJZ2TD+Es63/bjd/oa1djnBXFhqii/vY1WI7c1lUK+
JPIu7RpEeb3ZwpwnTeHxLe+kJtvEjTdHygM0KtWdq+MHAX+t+5AJA9UyVIQupztH
+/87/GvtxYMIQRwgWY9ExP1HAi8vyLxOxQNmc1A3boYY5GA16L3AOGxtOIn43qDT
z5RwY+s1A1zyUq4zczBA/FmaddqN0N/arjHEkE1cLXEypcYme1xfLE8mpU3/7FSy
HdQxW2o/KqoDkqVj12oKAMuBnKcYoKmrqsmy8eHpmbfMUrRE7frpGeF4II/NgCfE
YOAxysOOq4IRXQClaZpquL4AOXN2EVjz/awQAKU6fpScpzZoNAMJYnbTQrs8YEy4
VUFvUyZWpSVDj5aAhrZApbb7LfGQyBMFxHARnwDGv9AK6Sl+vHp8zvPn9nHE3D9t
LGIWtjCRRhPe/RY1wWyw8ZUmBN6jDZ1LSh/Tqr7J24zsLmxGBUJcDfZ/awv/sabq
Pp0AGbs/qQwjxgWj9en6IS2+mWnWL3sQXOmxdFil/0+Tx5WOrEtCkR35yPLnTSeY
xKP6KKfG7gA8xLxXKxxVMojjAzN0Dxb0+0iQ4RwPygb79OzAsx588Rv2Qo8kf0Qy
vgUZhufvq355qQ248FU4gBEcLc5b2yu1Iz1nToubu74Uwl9t7XzZs+RP/6ZGuItS
HxsqLzVFexmNdcXhoKfu58NnH1Fi9wMKtAKCH31q235wSh/x0YM391cdIvSjxfIt
NXtykR7KDbal7YLOa5dKyRyf2WiYMCEAQSoRVj6A4ylRsqs9hirvYinNSWPa1Zrk
etKz+9g+rj0/pmQjKAPiapYkarp5yT8ddgQ1XuwGCaPZXhByS9s6SonZwvrthrHF
oWfK7JzkepYoBKy/nGUNt+9NDWbCB6sAe2zLAfmAtsOhB7ZO8/AlPRQCIvEGRXcE
tbYkxtB2vMNGPbIoHDv5QvbHP0Foj79SwRg/2a9wiq6i5VwvwGWOhC4ELGF+imX3
5GGbJq0a8A2z5WX6
=VHze
-----END PGP PUBLIC KEY BLOCK-----
""" > /tmp/s6-gpg-pub-key
  gpg --import /tmp/s6-gpg-pub-key
  rm /tmp/s6-gpg-pub-key

  # Verify download
  echo "[$APPNAME] Verifying s6-overlay download with gpg"
  if gpg --verify /tmp/s6-overlay.tar.gz.sig /tmp/s6-overlay.tar.gz;
  then
    echo "[$APPNAME] s6-overlay.tar.gz verified ok"
  else
    echo "[$APPNAME] ERROR: s6-overlay.tar.gz did not verify ok"
    exit 1
  fi
fi

# Install s6-overlay
echo "[$APPNAME] Unpacking s6-overlay"
tar -hxzf /tmp/s6-overlay.tar.gz -C /

# Test
echo "[$APPNAME] Testing s6-overlay"
/bin/s6-clock > /dev/null || exit 1
/bin/s6-echo > /dev/null || exit 1
/bin/s6-hostname > /dev/null || exit 1
/bin/s6-ls / > /dev/null || exit 1
/bin/s6-ps > /dev/null || exit 1

# Clean up
echo "[$APPNAME] Cleaning up temp files"
rm /tmp/s6-overlay.tar.gz
if [ $VERIFY -eq 1 ]
then
  rm /tmp/s6-overlay.tar.gz.sig
fi

echo "[$APPNAME] s6-overlay deployment finished ok"
