# deploy-s6-overlay

`deploy-s6-overlay.sh` is a helper script to deploy [s6-overlay](https://github.com/just-containers/s6-overlay) to multi-architecture containers.

Prevents the need for per-architecture Dockerfiles, and allows all s6-overlay deployment tasks to be done within a single layer.

## Prerequisites

* [`file`](https://github.com/file/file)
* [`curl`](https://curl.haxx.se) or [`wget`](https://www.gnu.org/software/wget/) (and also `ca-certificates` if not installed already)
* As of [s6-overlay](https://github.com/just-containers/s6-overlay) version 3.0.0.0, `xz-utils` is required to unpack the tarball (format is now `.tar.xz`)

## How it works

Originally the script would use `uname -m` to determine the container architecture, however this method has been abandoned. If cross-building (ie: building for i386 on amd64), you'd get the wrong architecture, as `uname -m` would return amd64.

Now, `file` is used on itself, which returns the installed architecture of the `file` binary. The returned architecture is then used to determine what architecture of s6 overlay to be installed. See below for examples.

The pre-requisites (`file`, `curl`/`wget`, `xz-utils`) can be installed and removed in the same layer, preventing unnecessary image bloat.

The script also includes testing to make sure the binaries run properly after installation. If there are any problems, the image will exit abnormally, which should cause the `docker build` process to fail (instead of returning a non-working image).

## Using

Ensure you have `file`, `wget`/`curl`, `xz-utils` and `ca-certificates` available.

In your project's `Dockerfile`, add one of the following early on within a `RUN` instruction:

```shell
...
  curl -o /tmp/deploy-s6-overlay.sh -s https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh && \
  sh /tmp/deploy-s6-overlay.sh && \
  rm /tmp/deploy-s6-overlay.sh && \
...
```

or:

```shell
...
  wget -q -O /tmp/deploy-s6-overlay.sh https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh && \
  sh /tmp/deploy-s6-overlay.sh && \
  rm /tmp/deploy-s6-overlay.sh && \
...
```

Both of the above methods achieve the same thing.

After s6-overlay installation, if they are not needed in your image, you may remove `file`, `wget`/`curl`, `xz-utils` and `ca-certificates`.

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
    apk add --no-cache file xz && \
    wget -q -O /tmp/deploy-s6-overlay.sh https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh && \
    sh /tmp/deploy-s6-overlay.sh && \
    rm /tmp/deploy-s6-overlay.sh && \
    apk del --no-cache file xz && \
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
        xz-utils \
        && \
    curl -o /tmp/deploy-s6-overlay.sh https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh && \
    sh /tmp/deploy-s6-overlay.sh && \
    rm /tmp/deploy-s6-overlay.sh && \
    apt-get remove -y \
        ca-certificates \
        curl \
        file \
        xz-utils \
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

I also have a [Discord channel](https://discord.gg/W4zncxj), feel free to [join](https://discord.gg/W4zncxj) and converse.
