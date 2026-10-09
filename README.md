# deb

This repository serves as a factory for creating Debian binary packages (or as I
call them, deb packages) to distribute binaries that I use on my development
machines. These created packages are not intended to pass the muster of being
included in a Debian archive of any Debian distribution.

## How to use this

```shell
make debs
```

### Building packages for multiple sources at once

```shell
make --jobs 2 debs
```

### Building packages for select sources

```shell
make SOURCES="yq talos" debs
```

### Building packages for a source version

```shell
make VERSION="v1.14.2" talos
```

## License

See LICENSE.
