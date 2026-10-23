#!/bin/sh
set -eu

QBT_TAG="${QBT_TAG:-release-5.3.0}"
LT_TAG="${LT_TAG:-master}"
CXX_STANDARD="${CXX_STANDARD:-}"
DEPRECATED_FUNCTIONS="${DEPRECATED_FUNCTIONS:-ON}"
WEBTORRENT="${WEBTORRENT:-ON}"
OPENSSL_TAG="${OPENSSL_TAG:-}"

export qbt_use_lto="${USE_LTO:-yes}"

SCRIPT_URL="https://raw.githubusercontent.com/userdocs/qbittorrent-nox-static/master/qbt-nox-static.bash"
BUILD=/qbt/qbt-build
BIN=$BUILD/completed/qbittorrent-nox
OWNER="$(stat -c '%u:%g' /bundle)"

say()  { printf '\n==> %s\n' "$*"; }
fail() { printf '\n!!  %s\n' "$*" >&2; exit 1; }

finish() {
    if [ -d $BUILD/logs ]; then
        rm -rf /output/logs
        cp -r $BUILD/logs /output/logs
    fi
    chown -R "$OWNER" /output 2>/dev/null || true
    chown -R "$OWNER" $BUILD 2>/dev/null || true
}
trap finish EXIT

cd /qbt

if [ -d "$BUILD" ] && grep -rqs "^prefix=/root/qbt-build" "$BUILD/lib/pkgconfig" 2>/dev/null; then
    fail "work/ holds a build made under the old /root path. Delete the work folder and run again."
fi

say "Installing bash and curl"
apk add -q --no-cache bash curl file

say "Preparing build script"
if [ -f /bundle/qbt.bash ]; then
    cp /bundle/qbt.bash /qbt/qbt.bash
    echo "using qbt.bash from the bundle"
else
    curl -sSL "$SCRIPT_URL" -o /qbt/qbt.bash
    echo "downloaded upstream qbt-nox-static.bash"
fi
chmod +x /qbt/qbt.bash
grep -q '^script_version=' qbt.bash || fail "qbt.bash does not look like the userdocs build script"

# Patch 1: libtorrent deprecated functions. The script hard-codes OFF; libtorrent
# master needs ON because qBittorrent still calls lt::create_smart_ban_plugin.
sed -i "s|-D deprecated-functions=[A-Z]*|-D deprecated-functions=${DEPRECATED_FUNCTIONS}|" qbt.bash
grep -q -- "-D deprecated-functions=${DEPRECATED_FUNCTIONS}" qbt.bash \
    || fail "patch 1 (deprecated-functions) did not apply; the upstream script may have changed"
echo "deprecated-functions=${DEPRECATED_FUNCTIONS}"

# Patch 2 (optional): WebTorrent off, for when libtorrent's libdatachannel dependency fails.
if [ "$WEBTORRENT" = "OFF" ] && ! grep -q -- "-D webtorrent=OFF" qbt.bash; then
    sed -i "s|\(-D deprecated-functions=[A-Z]*\)|\1 -D webtorrent=OFF|" qbt.bash
    grep -q -- "-D webtorrent=OFF" qbt.bash || fail "patch 2 (webtorrent) did not apply"
    echo "webtorrent=OFF"
fi

# Patch 3 (optional): force C++20. The script picks C++23 for new versions.
if [ "$CXX_STANDARD" = "20" ]; then
    sed -i 's|999.999.999.999"\]=23|999.999.999.999"]=20|g' qbt.bash
    [ "$(grep -c '999.999.999.999"\]=23' qbt.bash)" = "0" ] || fail "patch 3 (C++20) did not apply"
    echo "C++ standard forced to 20"
elif [ -n "$CXX_STANDARD" ]; then
    fail "CXX_STANDARD must be empty or 20"
fi

say "Installing build dependencies (a few minutes)"
./qbt.bash bootstrap_deps

say "Checking versions"
./qbt.bash -qt "$QBT_TAG" -lt "$LT_TAG" ${OPENSSL_TAG:+-ot "$OPENSSL_TAG"} | tee /tmp/settings.txt
grep -q 'not valid' /tmp/settings.txt && fail "a version tag was rejected; check QBT_TAG and LT_TAG in settings.env"

say "Building qBittorrent ${QBT_TAG} against libtorrent ${LT_TAG} (30 min to several hours)"
./qbt.bash all -qt "$QBT_TAG" -lt "$LT_TAG" ${OPENSSL_TAG:+-ot "$OPENSSL_TAG"}

[ -f "$BIN" ] || fail "no binary was produced; see output/logs"

say "Checking the result"
file "$BIN"
"$BIN" --version 2>/dev/null || true
if strings "$BIN" | grep -q disable_tracker_connection_reuse; then
    echo "libtorrent with tracker connection reuse: YES"
else
    echo "libtorrent with tracker connection reuse: NO (a release libtorrent was used)"
fi

OUT="/output/qbittorrent-nox-${QBT_TAG#release-}-libtorrent-${LT_TAG}"
cp "$BIN" "$OUT"
chmod +x "$OUT"
{
    echo "built:        $(date -u +%Y-%m-%dT%H:%MZ)"
    echo "qbittorrent:  ${QBT_TAG}"
    echo "libtorrent:   ${LT_TAG} $(git -C "$BUILD/libtorrent" rev-parse --short HEAD 2>/dev/null || true)"
    echo "deprecated-functions=${DEPRECATED_FUNCTIONS} webtorrent=${WEBTORRENT} cxx=${CXX_STANDARD:-auto} lto=${qbt_use_lto}"
    echo "sha256:       $(sha256sum "$OUT" | cut -d' ' -f1)"
} > /output/build-info.txt
cat /output/build-info.txt
say "Done. Binary: output/$(basename "$OUT")"
