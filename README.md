## deploy-s6-overlay

`deploy-s6-overlay.sh` is a helper script to deploy s6-overlay to multi-architecture containers.

Prevents the need for per-architecture Dockerfiles.

## Using

In your project's `Dockerfile`, add one of the following commands early on within a `RUN` instruction:

```
curl -s https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh
```

or:

```
wget -q -O - https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh
```

Both of the above methods achieve the same thing.

At the end of the `Dockerfile`, you'll also need to include:

```
ENTRYPOINT [ "/init" ]
```

...in order for s6 to be initialised during container start.

## Testing

This script has been tested on the following architectures/distributions:

| Distribution | `linux/amd64` | `linux/arm64` | `linux/arm/v7` | Notes |
| ------------ |:-------------:|:-------------:|:--------------:| ----- |
| alpine:3.8 | ✅  | ✅  | ✅  | |
| alpine:3.9 | ✅ | ✅ | ✅ | |
| alpine:3.10 | ✅ | ✅ | ✅ | |
| alpine:3.11 | ✅ | ✅ | ✅ | |
