# Patches

Applied to the qBittorrent source by `build.sh` when needed. Each is checked
against the sources being built before it is used, so a patch that has become
unnecessary (because upstream adapted) is skipped rather than failing.

## qbittorrent-async_check_files-lt-master.patch

libtorrent master commit `b64a59d` (2026-10-19) added a third parameter to the
completion handler of `disk_interface::async_check_files()`. qBittorrent's
`CustomDiskIOThread` implements that interface and passes the call straight
through to libtorrent's own disk I/O, so the fix is to forward the new parameter.
Needed for qBittorrent 5.3.0 and master (as of 2026-10-20) when building against
libtorrent master. Not needed for libtorrent RC_2_1 or any release.

Applied when: libtorrent's `disk_interface.hpp` at `LT_TAG` contains the new
signature AND qBittorrent's `customstorage.h` at `QBT_TAG` still has the old one.
