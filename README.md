# logos-test-example

## Build the aggregated packages

```bash
nix --extra-experimental-features "nix-command flakes" build .
```

This will build the default package which ensures these components are fetched and compiled via their own flakes:
- logos-liblogos
- logos-package-manager
- logos-capability-module

You can also build individual packages directly:

```bash
nix --extra-experimental-features "nix-command flakes" build .#liblogos
nix --extra-experimental-features "nix-command flakes" build .#package-manager
nix --extra-experimental-features "nix-command flakes" build .#capability-module
```

## Enter a development shell

```bash
nix --extra-experimental-features "nix-command flakes" develop
```

The shell exports:
- `LOGOS_LIBLOGOS_ROOT`
- `LOGOS_PACKAGE_MANAGER_ROOT`
- `LOGOS_CAPABILITY_MODULE_ROOT`

pointing to the built outputs for convenience.
