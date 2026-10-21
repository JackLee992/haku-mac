# Third-party notices

Haku Mac's original Swift code and the reused Haku chestnut mascot are provided under the repository MIT license. The mascot originates in JackLee992/haku, Resources/Brand/haku-chestnut.png.

`upstream/haku-server` is a Git submodule of https://github.com/JackLee992/haku-server, tracking its `haku` branch. That project is a Frida Core fork, with its own LGPL license and third-party notices retained in the submodule. Haku Mac does not statically or dynamically link Frida Core, redistribute an iOS server binary, or incorporate the Frida source in its executable; it invokes a separately installed on-device Haku CLI over OpenSSH.

macOS supplies OpenSSH and the ZIP integrity utility. Optional USB discovery/forwarding uses separately installed libimobiledevice/libusbmuxd command-line tools (`idevice_id`, `iproxy`), under their respective licenses. These tools are not bundled.
