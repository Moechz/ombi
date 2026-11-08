# Changelog

All notable user-visible changes to the Ombi TOS application package.

## 4.53.10-2 — 2026-11-08

### Added
- **Dual-architecture release**: `ombidocker_x86_64.tar.gz` and
  `ombidocker_aarch64.tar.gz` (the only difference between the two packages is
  `config.ini.platform`; the upstream image is multi-arch and Docker pulls the
  matching variant). Both are submitted as two App records with the same
  `appid` and different `platform`.

### Changed
- `scripts/build-dual.sh` builds aarch64 first and then the canonical x86_64
  package, so a local rebuild can never publish an ARM package under the x86_64
  name (a real failure mode found with the official self-testing tool).

## 4.53.10-1 — 2026-11-08

### Added
- First release. Ombi (`linuxserver/ombi:4.53.10`, Docker Hub official image, unmodified)
  packaged as a TOS 7 Docker application, published on port 8005 and running
  as a non-root user (1000:1000).
- Persistent data is kept under `/Volume1/DockerAppData/ombidocker/`.
