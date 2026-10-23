# qbittorrent-nox static builder

Builds a single-file, fully static `qbittorrent-nox` for 64-bit Linux: qBittorrent
5.3.0 linked against the libtorrent `master` toconnection reuse.

Essentially a wrapper of [userdocs/qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static).

## Option A: build on your own Linux machine

1. Get this folder: press the green **Code** button on GitHub and choose
   **Download ZIP**, then unzip it. Or `git clone` the repository.

2. Open a terminal in the folder. Optionally edit `settings.env`; the defaults
   build 5.3.0 against libtorrent master.

3. Run:

       docker compose run --rm builder

4. The last lines should read:

       libtorrent with tracker connection reuse: YES
       ...
       Done. Binary: output/qbittorrent-nox-5.3.0-libtorrent-master

5. Your binary is in the `output` folder, next to `build-info.txt` (versions,
   libtorrent commit, checksum). Copy it anywhere and run it:

       chmod +x output/qbittorrent-nox-*
       ./output/qbittorrent-nox-5.3.0-libtorrent-master --version

## Option B: build on GitHub's servers (no Docker needed)

1. Fork this repository on GitHub.
2. Open the **Actions** tab of your fork and enable workflows if asked.
3. Choose **Build qbittorrent-nox** in the left column, press **Run workflow**,
   adjust the two version fields if you like, and confirm.
4. After one to three hours the run turns green. Open it and download the
   artifact named `qbittorrent-nox-...`; it is a zip containing the binary and
   `build-info.txt`.

## Using the binary in a hotio container

If you run `ghcr.io/hotio/qbittorrent`, you can swap its bundled binary for this
one without touching your config or re-checking torrents. Put the binary next to
your compose file, make it executable (`chmod 755`), set `LIBTORRENT=v2`, and add
one volume line:

    volumes:
      - ./qbittorrent-nox-5.3.0-libtorrent-master:/app/qbittorrent-nox-lib2:ro
      - ./config:/config
      ...

Stop the container cleanly first and back up `./config`; 5.3 upgrades the config
and resume-data format, and going back to 5.2.x afterwards is not guaranteed.

Don't blame me for losing your seed (pause).

## If something goes wrong

- Logs are in `output/logs/`
- Run the same command again. The build resumes from the last component that
  finished, so a retry should be faster than the initial run.
- To start completely fresh, delete the `work` folder.
- If the build stops at once with "work/ holds a build made under the old /root
  path", delete the `work` folder.
- Common fixes, all set in `settings.env`:

  | Symptom | Fix |
  |---|---|
  | Build dies with no error, or "Killed" | `USE_LTO=no` (and check RAM) |
  | libtorrent fails mentioning libdatachannel, usrsctp or juice | `WEBTORRENT=OFF` |
  | qBittorrent fails mentioning std::expected or get_unexpected | `CXX_STANDARD=20` |
  | Any step fails mentioning openssl/ or SSL_ | `OPENSSL_TAG=lts` |
  | qBittorrent fails mentioning `lt::` or `libtorrent/` | libtorrent master moved ahead of qBittorrent; try `LT_TAG=RC_2_1` (no connection reuse) |

## What `build.sh` changes and why

The userdocs script is used as-is apart from small edits:

- **`deprecated-functions=ON`** for libtorrent (the script's default is OFF).
  libtorrent master made the smart-ban feature built in and turned
  `create_smart_ban_plugin` into a deprecated stub, but qBittorrent 5.3.0 still
  calls that function. OFF removes the stub and the build fails; ON keeps it and
  the call is no-op but we can complete the build.
- **Optional `webtorrent=OFF` and C++20** edits, only when enabled in `settings.env`.

To pin the upstream build script, drop a copy of `qbt-nox-static.bash` in this folder
 as `qbt.bash`; it is then used instead of downloading the newest upstream version.

## Files

- `compose.yaml` – the container definition
- `settings.env` – versions and options (the only file you normally edit)
- `build.sh` – runs inside the container; patches the script before building
- `.github/workflows/build.yml` – GitHub Actions build
- `work/` – where the magic happens
- `output/` – location for the binary, `build-info.txt` and logs
