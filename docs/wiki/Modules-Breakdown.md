Each module in [`modules/`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/) is a self-contained NixOS configuration unit. A module only activates when listed in [`configuration.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/hosts/legion/default.nix)'s `imports` — removing one line disables the entire service, cleanly, with no orphaned options left behind. This page documents what each module does, why it exists as a separate unit, and what engineering decisions shaped its configuration.

The goal is to keep [`configuration.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/hosts/legion/default.nix) legible. It should read as a declaration of intent — "this machine runs a database, a backup job, a local LLM, and a monitoring stack" — without embedding the implementation details of each. Those details live in their respective module files, where they can be read, modified, or audited independently. A new host in the flake could import a subset of these modules without touching anything else.

![Architectural Scheme](https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/scheme.png)

---

### [`nvidia-prime.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/hardware/nvidia-prime.nix) — Hybrid GPU
<p align="left">
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/nvidia.svg" alt="NVIDIA" width="28" />
</p>

On a laptop with both an Intel iGPU and an NVIDIA discrete GPU, the choice of GPU mode has significant power implications. Running in full NVIDIA mode keeps the discrete GPU active at all times, drawing 10–15W at desktop idle. PRIME Offload mode makes the Intel GPU the primary display device and suspends the NVIDIA GPU until a process explicitly requests it — at which point the GPU wakes, does its work, and returns to D3cold (fully powered off), drawing around 0.5W at rest.

The configuration sets `powerManagement.finegrained = true`, which enables ACPI runtime power management for the GPU. This is the mechanism that allows the GPU to enter D3cold between uses rather than just lowering its clock. Combined with `modesetting = true` (required for Wayland compositors to work correctly with NVIDIA), the setup gives full GPU performance on demand with near-zero idle cost.

Applications that need the discrete GPU use the `nvidia-offload` wrapper — for example `nvidia-offload blender` or `nvidia-offload steam`. Everything else renders on the Intel GPU by default.

---

### [`gdm-wallpaper.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/desktop/gdm-wallpaper.nix) — Custom GDM Login Screen
<p align="left">
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/gnome.svg" alt="GNOME" width="28" />
</p>

This is a custom NixOS module with no upstream equivalent in `nixpkgs`. It patches the GDM login screen wallpaper by extracting the existing `gnome-shell-theme.gresource` binary, injecting CSS that overrides the background selectors, recompiling it with `glib-compile-resources`, and replacing the original via a Nix overlay on the `gnome-shell` package.

Only the theme resource is modified. GNOME Shell itself remains unpatched and continues to update with the rest of `nixpkgs`. The CSS targets `#lockDialogGroup` and `.login-screen` to set a custom wallpaper at the login screen and lock screen.

---

### [`launcher.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/desktop/launcher) — Desktop Integration
<p align="left">
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/rofi.png" alt="Rofi" width="28" />
</p>

This module is intentionally thin. Its only job is to ensure that `gvfs` and `udisks2` run as system services. Without `gvfs`, file managers cannot access SFTP mounts, MTP devices (Android phones), or network shares. Without `udisks2`, USB drives are not automounted and the file manager has no mechanism to eject removable media. These services need to be enabled at the system level regardless of which file manager or desktop environment session is active.

The module also installs Rofi, Waybar, the NetworkManager system tray applet, and Nemo as packages — keeping these tied to the module that declares their service dependencies rather than scattering them across `configuration.nix`.

---

## User App Modules

<p align="left">
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/obsidian.png" alt="Obsidian" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/kicad.png" alt="KiCad" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/freecad.png" alt="FreeCAD" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/arduino.svg" alt="Arduino" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/esptool.png" alt="esptool" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/dbeaver.png" alt="DBeaver" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/influxdb.png" alt="InfluxDB" width="28" />
</p>

The three modules in [`home/tco/modules/apps/`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/packages/) are Home Manager modules, not NixOS modules — they install packages into the user profile rather than the system, and they have no service dependencies.

- [`cad.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/packages/cad.nix) groups Obsidian (notes and knowledge management), KiCad (PCB and schematic design), and FreeCAD (parametric 3D CAD) together.
- [`embedded.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/packages/embedded.nix) provides the Arduino IDE and CLI, esptool for ESP8266/ESP32 firmware flashing, and minicom for serial port monitoring.
- [`data.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/packages/data.nix) installs DBeaver (a universal database GUI), Grafana, and InfluxDB2 for time-series data work.

The grouping reflects how these tools are actually used. They are domain-specific toolchains that are either all needed or none needed for a given project. Enabling or disabling a domain is one import line in [`home/tco/home.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/default.nix).

---

### [`backup.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/services/backup.nix) — Restic + Backblaze B2
<p align="left">
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/restic.png" alt="Restic" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/backblaze.png" alt="Backblaze B2" width="28" />
</p>

This is the most operationally critical module. It runs two independent systemd timer and service pairs, each targeting a different category of data with different retention requirements.

The separation between jobs is deliberate. Configuration files, SSH keys, and GPG keychains are small, change rarely, and would be catastrophic to lose — they get backed up nightly at 02:00 with 14-day daily retention and 6-month monthly retention. User data (documents, images, desktop files) is larger, changes more often, and is less immediately critical — it runs at 03:00 with a shorter retention window. Keeping the jobs independent means a large `~/Documents` tree never delays or fails the config backup.

Credentials are injected via `EnvironmentFile` rather than passed as CLI arguments. A restic invocation with credentials in the argument list would expose them in `ps` output, shell history, and the systemd journal. The environment file approach keeps them out of all three. The file itself is an ephemeral SOPS-decrypted secret in `/run/secrets/` — see [Security & Secrets](https://github.com/RomeoCavazza/nixos-config/wiki/Security-&-Secrets) for the full model.

Both timers use `RandomizedDelaySec` to add a random offset to their start time, preventing them from hitting the Backblaze B2 API simultaneously and avoiding predictable backup windows.

---

### [`observability.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/observability) — Prometheus, Loki, Grafana
<p align="left">
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/prometheus.png" alt="Prometheus" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/loki.png" alt="Loki" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/graphana.png" alt="Grafana" width="28" />
</p>

The observability stack mirrors what a production SRE environment looks like: Prometheus scrapes metrics from Node Exporter and from itself, Promtail ships the systemd journal to Loki, and Grafana provides a unified dashboard interface pre-wired to both sources.

Running observability on the workstation provides a baseline for normal host behavior: CPU steal, memory pressure, journal events, and NVIDIA driver activity can be inspected under real workloads.

Promtail runs as a raw systemd service rather than through the NixOS module, because the module version on `nixos-unstable` has an option conflict with the current Loki module. Rather than pinning Loki to an older version, the solution is to run Promtail's binary (sourced from `nixpkgs-stable` via the custom overlay) with its configuration serialized as JSON and inlined directly in the systemd service definition. It is more verbose than the NixOS module abstraction, but it works with the current stack and avoids introducing a second stable-channel Loki alongside the unstable one.

---

### [`databases.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/services/databases.nix) — PostgreSQL, Redis, Qdrant
<p align="left">
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/postgresql.png" alt="PostgreSQL" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/redis.webp" alt="Redis" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/qdrant.png" alt="Qdrant" width="28" />
</p>

Three data services are configured as local development services, each bound to localhost only.

PostgreSQL 17 runs with the PostGIS extension enabled. PostGIS is included by default because spatial queries come up often enough in data work that having to re-enable it per project is friction. The extension is loaded on demand, so there is no overhead when it is not used.

Redis is configured for dual use. The eviction policy is `allkeys-lru`, which makes it behave correctly as a session cache — the least recently used keys are evicted when memory reaches the 2 GB limit. But persistence is also enabled (both AOF and RDB snapshots), so Redis survives a service restart, which is what a message queue or task queue requires. Keyspace notifications are enabled for patterns that subscribe to key expiration events. The 2 GB memory limit is a guard against Redis consuming unbounded memory when used carelessly during development.

Qdrant is the vector database of this stack. It listens on `localhost:6333` and stores data at `/var/lib/qdrant`. It pairs with Ollama to form a local RAG pipeline: Ollama handles embedding generation and inference, while Qdrant handles the nearest-neighbour search over those embeddings. The combination provides a fully self-hosted semantic search capability.

---

### [`virtualisation.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/services/virtualisation.nix) — Containers, VMs, and ARM Emulation
<p align="left">
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/docker.png" alt="Docker" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/kvm.png" alt="KVM" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/qemu.png" alt="QEMU" width="28" />
</p>

This module handles three distinct layers of virtualisation that are used for different purposes.

Docker is configured with auto-pruning enabled, which removes dangling images, stopped containers, and unused volumes on a weekly schedule. Without this, the Docker data directory grows without bound on a machine used for active development. `lazydocker` is included as a TUI alternative to the Docker CLI for inspecting running containers and logs.

The libvirt and KVM stack provides full hardware virtualisation through `virt-manager`. `quickemu` is also installed, which wraps QEMU to provide one-command creation of pre-configured VMs for common operating systems — useful for quickly spinning up a Windows or Ubuntu environment without manually configuring disk images and boot parameters.

The third layer is `binfmt` emulation for `aarch64-linux`. This registers the ARM64 ELF binary format in the kernel with QEMU user-mode as the interpreter, so ARM64 binaries run transparently on the x86_64 host. In practice this means Raspberry Pi NixOS images can be built with `nix build` without a physical ARM machine, `docker buildx` multi-architecture builds work locally, and cross-compilation targets that produce ARM64 executables can be tested directly.

---

### [`nginx.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/services/nginx.nix) — Local Reverse Proxy
<p align="left">
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/nginx.webp" alt="Nginx" width="28" />
</p>

Nginx runs three virtual hosts on localhost, routing traffic from named ports to local development services. The reason for a reverse proxy on localhost is that named virtual hosts allow multiple projects to run as distinct browser origins. Without this, every development server is `localhost:some-port`, and testing anything that is sensitive to origin — CORS policy, cookies with `SameSite` restrictions, OAuth redirect URIs — requires either faking the origin in some other way or manually reconfiguring headers.

WebSocket proxying is enabled on all virtual hosts, which is required for development servers that use hot module replacement or live reload over WebSocket connections.

---

## Optional Modules

<p align="left">
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/apache.png" alt="Apache" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/php.png" alt="PHP" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/mariadb.svg" alt="MariaDB" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/streamlit.webp" alt="Streamlit" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/edex-ui.png" alt="eDEX-UI" width="28" />
</p>

Three modules exist in [`modules/`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/) but are not active by default. They are ready to use but represent services that are not always needed.


- [`edex.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/pkgs/apps/edex.nix) builds an FHS environment for eDEX-UI, which requires a traditional Linux filesystem layout that NixOS's `/nix/store`-based approach does not provide by default.

Any of these can be activated by adding the corresponding `./modules/filename.nix` line to [`configuration.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/hosts/legion/default.nix)'s `imports` list and running a rebuild.

---

### [`ollama.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/services/ollama.nix) — Local LLM Daemon (AI Stack)
<p align="left">
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/n8n.png" alt="n8n" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/ollama.png" alt="Ollama" width="28" />
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/qdrant.png" alt="Qdrant" width="28" />
</p>

Ollama runs as a system daemon using the CUDA-enabled package, which uses NVIDIA cuBLAS for matrix operations instead of falling back to CPU. GPU inference is typically several times faster than CPU-only execution for interactive local models.

Two configuration choices are worth explaining. `OLLAMA_KEEP_ALIVE` is set to 24 hours, which keeps a loaded model in VRAM between requests. Without this, Ollama unloads the model after 5 minutes of inactivity, and the next request pays a cold-start cost of 2 to 10 seconds depending on model size. The tradeoff is 4 to 8 GB of VRAM reserved while a model is loaded. `OLLAMA_KV_CACHE_TYPE` is set to `q8_0`, which quantizes the key-value cache to 8-bit integers, reducing VRAM usage with a negligible quality impact on most tasks.

Ollama is paired with Qdrant (for vector search — declared in [`databases.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/modules/services/databases.nix)) and [`aider-chat`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/default.nix) (installed in [`home.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/default.nix)) to form a self-contained local AI development environment with no external API dependency.

Ollama + Qdrant form a local RAG pipeline: Ollama handles embedding generation and inference at `localhost:11434`, Qdrant handles nearest-neighbour search over those embeddings at `localhost:6333`.

---

### [`emacs.nix`](https://github.com/RomeoCavazza/nixos-config/blob/main/home/tco/emacs.nix) — Emacs Daemon
<p align="left">
	<img src="https://raw.githubusercontent.com/RomeoCavazza/nixos-config/main/docs/assets/logo/emacs.png" alt="Emacs" width="28" />
</p>

Emacs runs as a systemd user service using the `emacs-pgtk` build — Pure GTK, which renders natively on Wayland without requiring XWayland. The daemon approach means the editor process starts at login and remains running. Connecting via `emacsclient` takes around 50ms regardless of configuration complexity, compared to 2 to 5 seconds for a cold Emacs start with Doom Emacs loaded.

The module also installs the LSP tooling that Doom Emacs expects to find on PATH: `nil` for Nix, `bash-language-server` for shell scripts, and the build tools (`clang`, `cmake`, `gnumake`, `libtool`) that some Doom packages compile during `doom sync`. LaTeX support comes from a `texlive` medium scheme install, which covers the packages needed for org-mode PDF export without pulling in the full TeXLive distribution.
