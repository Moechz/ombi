# ombi-for-tos

> TerraMaster TOS 7 App Center — **Docker application** package for
> [Ombi](https://github.com/Ombi-app/Ombi).

## What this is

A four-file TOS Docker application archive (`ombidocker.tar.gz`) that installs
Ombi on TOS 7 through the App Center:

- `config.ini` — TOS application metadata (`application_type: docker`, id `ombidocker`)
- `ombidocker.lang` — 23-language superset (TOS requires 14)
- `ombidocker.svg` — application icon (1805 bytes, 2 SVG elements)
- `docker-compose.yml` — one service, image `linuxserver/ombi:4.53.10`

## How it works

| | |
|---|---|
| Container image | `linuxserver/ombi:4.53.10` (Docker Hub, used unmodified) |
| Open | `http://<NAS-IP>:8005/` (container port 3579) |
| Runs as | non-root, `user: "1000:1000"` |
| Persistent data | `/config` → `/Volume1/DockerAppData/ombidocker/config` |
| Logs | `docker logs ombidocker` (stdout/stderr) |

Everything Ombi writes lives in `/config`, mounted from `/Volume1/DockerAppData/ombidocker/config`: `Ombi.db` (users, requests), `OmbiSettings.db` (settings), `.aspnet/` (login keys) and `Logs/`. The container filesystem itself is disposable, and the image never needs to be modified.

## Design highlights

- **Non-root.** `user: "1000:1000"`; verified on real hardware (the container reports uid 1000).
- **Entrypoint wrapper**: the LinuxServer.io image starts s6-overlay as root, which cannot run inside a non-root container, so the compose file replaces the entrypoint with `src/entrypoint.sh`. It starts the Ombi binary directly with the upstream service's arguments (`--storage /config --host http://*:3579`) and only keeps using writable paths for `HOME` and `TMPDIR`.
- **Fixed image tag, never `:latest`**, Docker Hub only, no `privileged`, no `network_mode: host`, and no Docker socket, no `cap_add`.
- **Health check** probing the service on container port 3579.
- **Deterministic build**: GNU tar with uid/gid 0 and zeroed timestamps, gzip without a timestamp, plus the review-standards self-check above.
- **The LinuxServer.io s6 init cannot run unprivileged.** The upstream image starts s6-overlay as root and drops to its `abc` user; inside a container that already runs as uid 1000 that init aborts (`s6-applyuidgid: unable to set supplementary group list`). `src/entrypoint.sh` therefore starts the Ombi binary directly with the same arguments as the upstream s6 service (`--storage /config --host http://*:3579`) and keeps `HOME`, `TMPDIR` on writable paths.
- **One volume, one port, no extra privileges.** Only `/config` is persistent and only container port 3579 is published; no Docker socket, no camera or USB passthrough, no `privileged`, no host networking.
- **Base URL / reverse-proxy sub-path is not supported.** Ombi writes its base URL into `wwwroot/index.html`, which is root-owned inside the image and stays read-only for a non-root container; serve it from a dedicated host name or sub-domain instead of a path prefix.

## Runtime file manifest

Everything the application writes on the NAS lives inside its own data
directory; the container-internal `/tmp` is discarded with the container. The
table lists what is created and how it behaves. Nothing else is written.

| Path | Purpose | Created when | Growth bound | Lifecycle |
|---|---|---|---|---|
| `config/Ombi.db` | SQLite database with users, requests and history | first start (migrations) | grows with the number of requests | persistent; include it in every backup |
| `config/OmbiSettings.db` | SQLite database with application settings | first start | small, changes only when settings change | persistent; include it in every backup |
| `config/.aspnet` | ASP.NET Core data-protection keys (keep them to stay logged in) | first start | constant | persistent |
| `config/Logs` | Ombi application logs | first start | rotated by Ombi itself | persistent, safe to delete while stopped |
| `/Volume1/DockerAppData/ombidocker/config` | Ombi application data (everything the container writes outside /tmp) | on first start / on demand | bounded by your own data | persistent; kept on uninstall unless you ask to delete it |

## Build

```bash
scripts/build-dual.sh             # DEFAULT: out/ombidocker_x86_64.tar.gz + out/ombidocker_aarch64.tar.gz
scripts/build.sh                  # single arch -> out/ombidocker.tar.gz + .sha256
scripts/build.sh 4.53.10-3        # packaging iteration bump
scripts/build.sh 4.53.10-2 aarch64
```

The build stages the four files, substitutes the version/platform placeholders,
embeds `src/entrypoint.sh` into the compose file (escaping every `$` as `$$`), removes CRLF/BOM/AppleDouble, then runs
`tools/verify.py`, a review-standards self-check (archive layout, JSON validity,
required fields, 14+ language coverage, version consistency, Docker-Hub-only
images, fixed tag, reserved/recommended host ports, non-root user, per-service
healthcheck/TZ/restart, data path below the application data root, never the
`/Volume*` wildcard, comment-free sequence blocks, `x-app-meta` position, no
literal secrets and the SVG size/element limits).

## Architectures

Both store architectures are built and submitted (`x86_64` + `aarch64`) as two
App records with the same `appid`, different `platform`:

| Package | `config.ini.platform` | Submitted for |
|---|---|---|
| `ombidocker_x86_64.tar.gz` | `x86_64` | x86_64 NAS |
| `ombidocker_aarch64.tar.gz` | `aarch64` | ARM NAS |

The two archives differ only in `config.ini.platform`. The upstream image is a
multi-arch Docker Hub image (`linux/amd64` + `linux/arm64`), so Docker pulls the
variant matching the NAS; nothing else in the package changes.

## Local verification

```bash
./TOSAppSelfTestingTool -c out/ombidocker.tar.gz   # official spec check
bash test/install-and-verify.sh                  # on-device E2E (needs root)
```

> Docker applications cannot be side-loaded through the App Center's manual
> install page (it accepts `.deb` only); the official self-testing tool's `-i`
> mode or `docker compose` are the only ways to install one for testing.

## Store submission checklist

1. Public GitHub repo (code + README only).
2. Release **tag `v4.53.10-1`**, assets `ombidocker.tar.gz` +
   `ombidocker.tar.gz.sha256` (Docker asset naming: `<app_id>.tar.gz`, **no
   platform suffix**).
3. Developer platform → Add Application: ID `ombidocker`, package type Docker,
   repository URL, architecture `x86_64`.
4. Version Management → Add Version `4.53.10-1` → automated validation → review.

## License / branding

Ombi is distributed by its upstream authors under **GPL-3.0**. The container image is the official image from Docker Hub (`linuxserver/ombi:4.53.10`) and is used unmodified; no upstream source code is redistributed here. This packaging is an independent community submission by Moechz and is not affiliated with the upstream project or TerraMaster.

## Limitations

- Ombi is a request front end only: a Plex, Emby or Jellyfin server and (for automatic fulfilment) Sonarr/Radarr must already exist on your network.
- The web interface is served over plain HTTP on the published port; use a TLS reverse proxy if you expose it outside your LAN.
- Sub-path hosting (Ombi `Base URL`) is not supported by this package because the image stores it in a file the non-root container cannot write; use a dedicated host name.
- Email notifications and newsletters require an SMTP account configured under Settings; no mail server is bundled.
- The data folder is not visible in TOS File Manager; back it up over SMB/SSH or add it to a TOS backup task by path.

---

Packaged for TOS 7 by Moechz. Upstream image used unmodified from Docker Hub.
