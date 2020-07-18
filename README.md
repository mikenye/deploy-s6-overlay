# deploy-s6-overlay

`deploy-s6-overlay.sh` is a helper script to deploy [s6-overlay](https://github.com/just-containers/s6-overlay) to multi-architecture containers.

Prevents the need for per-architecture Dockerfiles, and allows all s6-overlay deployment tasks to be done within a single layer.

## Prerequisites

- [`file`](https://github.com/file/file)
- [`gnupg or gnupg2`](https://www.gnupg.org)
- [`curl`](https://curl.haxx.se) or [`wget`](https://www.gnu.org/software/wget/) (and also `ca-certificates` if not installed already)

## How it works

Originally the script would use `uname -m` to determine the container architecture, however this method has been abandoned. If cross-building (ie: building for i386 on amd64), you'd get the wrong architecture, as `uname -m` would return amd64.

Now, `file` is used on itself, which returns the installed architecture of the `file` binary. The returned architecture is then used to determine what architecture of s6 overlay to be installed. See below for examples.

The pre-requisites (`file`, `gnupg`/`gnupg2`, `curl`/`wget`) can be installed and removed in the same layer, preventing unnecessary image bloat.

The script also includes testing to make sure the binaries run properly after installation. If there are any problems, the image will exit abnormally, which should cause the `docker build` process to fail (instead of returning a non-working image).

### Architecture examples

#### x86

Example output on Alpine:

```
/usr/bin/file: ELF 32-bit LSB shared object, Intel 80386, version 1 (SYSV), dynamically linked, interpreter /lib/ld-musl-i386.so.1, stripped
```

Example output on Debian

```
/usr/bin/file: ELF 32-bit LSB shared object, Intel 80386, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux.so.2, for GNU/Linux 3.2.0, BuildID[sha1]=d48e1d621e9b833b5d33ede3b4673535df181fe0, stripped
```

#### amd64

Example output on Alpine:

```
/usr/bin/file: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-musl-x86_64.so.1, stripped
```

Example output on Debian:

```
/usr/bin/file: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, for GNU/Linux 3.2.0, BuildID[sha1]=6b0b86f64e36f977d088b3e7046f70a586dd60e7, stripped
```

#### arm

Example output on Debian:

```
/usr/bin/file: ELF 32-bit LSB shared object, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux.so.3, for GNU/Linux 3.2.0, BuildID[sha1]=f57b617d0d6cd9d483dcf847b03614809e5cd8a9, stripped
```

#### armhf

Example output on Alpine:

```
/usr/bin/file: ELF 32-bit LSB shared object, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-musl-armhf.so.1, stripped  # /usr/bin/file: ELF 32-bit LSB shared object, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-armhf.so.3, for GNU/Linux 3.2.0, BuildID[sha1]=921490a07eade98430e10735d69858e714113c56, stripped
```

Example output on Debian:

```
/usr/bin/file: ELF 32-bit LSB shared object, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-armhf.so.3, for GNU/Linux 3.2.0, BuildID[sha1]=921490a07eade98430e10735d69858e714113c56, stripped
```

#### aarch64

Example output on Alpine:

```
/usr/bin/file: ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-musl-aarch64.so.1, stripped
```

Example output on Debian:

```
/usr/bin/file: ELF 64-bit LSB shared object, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-aarch64.so.1, for GNU/Linux 3.7.0, BuildID[sha1]=a8d6092fd49d8ec9e367ac9d451b3f55c7ae7a78, stripped
```

## Using

Ensure you have `file`, `gnupg`/`gnugp2`, `wget`/`curl` and `ca-certificates` available.

In your project's `Dockerfile`, add one of the following commands early on within a `RUN` instruction:

```shell
curl -s https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh
```

or:

```shell
wget -q -O - https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh
```

Both of the above methods achieve the same thing.

After s6-overlay installation, if they are not needed in your image, you may remove `file`, `gnupg`/`gnugp2`, `wget`/`curl` and `ca-certificates`.

At the end of the `Dockerfile`, you'll also need to include:

```docker
ENTRYPOINT [ "/init" ]
```

...in order for s6 to be initialised during container start.

Examples follow:

### Example for `alpine`

```docker
...
FROM alpine:latest
RUN ...
    apk add --no-cache file gnupg && \
    wget -q -O - https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh && \
    apk del --no-cache file gnupg && \
    ...
ENTRYPOINT [ "/init" ]
...
```

Note, Alpine includes `wget` so this is not explicitly installed.

### Example for `debian:stable-slim`

```docker
...
FROM debian:stable-slim
RUN ...
    apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
        file \
        gnupg \
        && \
        curl -s https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh && \
    apt-get remove -y \
        ca-certificates \
        curl \
        file \
        gnupg \
        && \
    apt-get autoremove -y
    ...
ENTRYPOINT [ "/init" ]
...
```

## Environment Variables

The default behaviour of the script can be overridden through the use of environment variables.

| Environment Variable | Details |
|-----|-----|
| `S6OVERLAY_ARCH` | If set, overrides architecture detection and will install the architecture specified. Can be set to one of the following: `aarch64`, `amd64`, `arm`, `armhf`, `ppc64le`, `x86`. |
| `S6OVERLAY_VERSION` | If set, will install a specific release of s6-overlay (instead of the latest stable). See [here](https://github.com/just-containers/s6-overlay/releases) for a list of releases.

## Testing

This script has been tested with `alpine` and `debian:stable-slim` images on all supported architectures.

The script is linted with [Shellcheck](https://github.com/koalaman/shellcheck).

## Getting help

Please feel free to [open an issue on the project's GitHub](https://github.com/mikenye/deploy-s6-overlay/issues).
