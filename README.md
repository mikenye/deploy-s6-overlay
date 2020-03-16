## deploy-s6-overlay

`deploy-s6-overlay.sh` is a helper script to deploy [s6-overlay](https://github.com/just-containers/s6-overlay) to multi-architecture containers.

Prevents the need for per-architecture Dockerfiles.

## Using

In your project's `Dockerfile`, add one of the following commands early on within a `RUN` instruction:

```bash
curl -s https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh
```

or:

```bash
wget -q -O - https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh
```

Both of the above methods achieve the same thing.

At the end of the `Dockerfile`, you'll also need to include:

```dockerfile
ENTRYPOINT [ "/init" ]
```

...in order for s6 to be initialised during container start.

## GPG Verification

The script supports using gpg to verify the s6-overlay download. Users of this script are strongly encouraged to make gpg available so this can take place.

An example is as follows:

### Example for `alpine`
```dockerfile
...
FROM alpine:3.11
RUN ...
    apk add --no-cache gnupg && \
    wget -q -O - https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh && \
    apk del --no-cache gnupg && \
    ...
ENTRYPOINT [ "/init" ]
...
```

### Example for `debian:stable-slim`
```dockerfile
...
FROM debian:stable-slim
RUN ...
    apt-get install --no-install-recommends -y \
        curl \
        gnupg \
        ca-certificates && \
    wget -q -O - https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh && \
    apt-get remove -y \
        curl \
        gnupg && \
    apt-get autoremove -y
    ...
ENTRYPOINT [ "/init" ]
...
```

In the examples above, `gnupg` (and its dependencies) are added and removed in the same layer, allowing GPG verification to occur with minimal overhead.

## Testing

This script has been tested with `alpine` and `debian:stable-slim` images.
