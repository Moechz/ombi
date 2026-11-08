#!/bin/sh
# ===========================================================================
# Ombi entrypoint for a non-root container (TOS 7 requirement).
#
# The upstream LinuxServer.io image starts s6-overlay as root and then drops to
# its internal "abc" user. Inside a container that already runs as uid 1000
# that init cannot work ("s6-applyuidgid: unable to set supplementary group
# list"), so this script starts the Ombi binary directly - with exactly the
# arguments the upstream s6 service uses (svc-ombi/run):
#
#     cd /app/ombi && Ombi --storage /config --host http://*:3579
#
# Only the writable locations change: HOME goes to the persistent data folder
# and the temporary directory to /tmp (the image's /run/ombi-temp is
# root-owned). The image itself is not modified.
# ===========================================================================
set -e
set -u

APP_DIR=/app/ombi
STORAGE=/config

# The platform creates and chowns the mounted data folder to the application
# user; fail with a readable message instead of a silent .NET crash if not.
mkdir -p "$STORAGE" 2>/dev/null || true
if ! ( : > "$STORAGE/.write-test" ) 2>/dev/null; then
  echo "ombi: $STORAGE is not writable by uid $(id -u)" >&2
  exit 1
fi
rm -f "$STORAGE/.write-test"

export HOME="$STORAGE"
export TMPDIR=/tmp
export DOTNET_CLI_TELEMETRY_OPTOUT=1

cd "$APP_DIR"

# BASE_URL hosts Ombi below a path prefix. It is passed through for parity with
# the upstream image, but note that Ombi rewrites wwwroot/index.html for it,
# which a non-root container cannot write - use a dedicated host name instead.
set -- --storage "$STORAGE" --host "http://*:3579"
if [ -n "${BASE_URL-}" ]; then
  set -- "$@" --baseurl "$BASE_URL"
fi

exec ./Ombi "$@"
