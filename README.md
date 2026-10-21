# Haku Mac

A native Mac companion for [Haku](https://github.com/JackLee992/haku) and [haku-server](https://github.com/JackLee992/haku-server), with a chestnut mascot, manga-inspired cream/ink panels, searchable device applications, live capture progress, and verified artifact retrieval.

Haku Mac runs the installed Haku engine **on the iPhone over SSH**. It does not transplant the iOS capture engine onto macOS. The dedicated Haku server stays on the phone's loopback interface, normally port **57042**; your original Frida service remains separate.

## Requirements

- macOS 14 or newer; the supplied local package is built for the host architecture.
- A jailbroken iPhone with compatible Haku iOS CLI and haku-server installed. Haku 0.2.2 with signal cancellation support is the intended companion.
- OpenSSH on the phone, reachable by LAN or a USB forwarding port; a working SSH key or agent and a trusted host-key entry.
- Optional USB discovery/forwarding: `idevice_id` and `iproxy` installed in `/opt/homebrew/bin`, `/usr/local/bin`, or another supported tool path. These are not bundled.
- Building from source requires Xcode Command Line Tools with Swift 5.9 or later.

## Start

1. Open **Haku Mac.app**.
2. Open **Connection settings**. Enter the SSH host, SSH port, user, identity-file path if needed, and known_hosts file. The separate **Haku server port** defaults to 57042. The phone's Haku executable defaults to `/var/jb/Applications/Haku.app/Haku`.
3. For USB, discover and select the phone, then start forwarding. For an existing tunnel or LAN, use its host and port directly.
4. Check connection to load the real application list, search and select an app, choose a local export folder, then export.
5. Read the verification result and reveal the retained report/IPA in Finder. **Cancel** signals the active remote Haku command; connectivity failures cannot confirm cleanup.

No app allowlist or install-path filter is imposed by this companion. Available apps come from the installed on-device engine. A capture may stop/relaunch its selected target according to that engine's lifecycle behavior.

### SSH trust

The app uses `BatchMode=yes` and `StrictHostKeyChecking=yes`. It never accepts unknown host keys automatically or stores passwords. Establish SSH access first using the endpoint you intend to use, verify the phone's host-key fingerprint, and authenticate using your key or SSH agent. For example, for a pre-existing local USB tunnel:

```sh
ssh -p 2222 -i ~/.ssh/iphone_ed25519 mobile@127.0.0.1
```

Use the matching known_hosts file in the app. A LAN hostname and a local forwarded port have separate OpenSSH host-key entries. Encrypted keys should be available through your SSH agent before opening the app.

## Build and test

```sh
git clone --recurse-submodules git@github.com:JackLee992/haku-mac.git
cd haku-mac
swift test
./script/build_and_run.sh --verify
```

The script stages `dist/Haku Mac.app` and opens it as a normal foreground Mac app. It also supports `--build`, `--debug`, `--logs`, and `--telemetry`. The Codex Run button calls the same script.

Create an optimized local package:

```sh
HAKU_BUILD_CONFIGURATION=release ./script/build_and_run.sh --package
```

The ZIP and probe executable are written into `dist/`. The app is ad-hoc signed for local use, **not Developer ID signed or notarized**. Build on the intended architecture; the current packaging script does not create a universal binary.

## Verification and retained artifacts

The phone produces `report.json` and, for successful or partial capture, `export.ipa`. The Mac retains a unique local run directory, downloads the artifacts, checks the IPA's SHA256 against the report, and performs an independent ZIP integrity check. Full native capture verification, partial capture, transport verification, and failures remain distinct.

A valid archive does not prove app signing, installation, ordinary launch, or functional behavior. The report preserves those boundaries. Failed/cancelled output remains available for investigation, and remote output is retained rather than deleted automatically. Keep outputs outside this source repository; artifact extensions are ignored by Git as an additional guard.

See [architecture](docs/ARCHITECTURE.md), [validation](docs/VALIDATION.md), and [third-party notices](THIRD_PARTY_NOTICES.md). The public server source is pinned under `upstream/haku-server` as a Git submodule and is not needed to compile the Mac app.

### Diagnostic probe

`swift run haku-mac-probe check` uses the same core transport as the GUI. Supported commands are `check`, `list`, `usb`, `export BUNDLE DESTINATION`, and `cancel-test BUNDLE DESTINATION [SECONDS]`. Export commands are explicit operations; read-only checks do not capture a target. Configure `HAKU_HOST`, `HAKU_USER`, `HAKU_SSH_PORT`, `HAKU_SERVER_PORT`, `HAKU_IDENTITY`, `HAKU_KNOWN_HOSTS`, `HAKU_PATH`, and `HAKU_REMOTE_ROOT` as needed. These variables contain connection metadata and paths, never key contents.
