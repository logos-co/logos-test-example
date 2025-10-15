# logos-test-example

## Build the aggregated packages

```bash
nix --extra-experimental-features "nix-command flakes" build .
```

## Enter a development shell

```bash
nix --extra-experimental-features "nix-command flakes" develop
```

The flake provides a custom `logos-test-example` binary that properly configures the plugins directory:

```bash
# Run with default module path (../modules relative to binary)
./result/bin/logos-test-example

# Run with custom module path
./result/bin/logos-test-example --module-path ./result/modules

```
