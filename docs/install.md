## Installing & building

### System requirements

| Requirement                 | Details                                                         |
| --------------------------- | --------------------------------------------------------------- |
| Operating systems           | macOS 12+, Ubuntu 20.04+/Debian 10+, or Windows 11 **via WSL2** |
| Git (optional, recommended) | 2.23+ for built-in PR helpers                                   |
| RAM                         | 4-GB minimum (8-GB recommended)                                 |

### DotSlash

The GitHub Release also contains a [DotSlash](https://dotslash-cli.com/) file for the Codex CLI named `codex`. Using a DotSlash file makes it possible to make a lightweight commit to source control to ensure all contributors use the same version of an executable, regardless of what platform they use for development.

### Windows portable USB install

If you want a self-contained Windows install on a USB drive, use the portable installer instead of a global install:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\install\install-portable.ps1 H:\PortableCodex
```

This creates:

- `H:\PortableCodex\bin\` with `codex.exe`, helper binaries, and `rg.exe`
- `H:\PortableCodex\data\` for `CODEX_HOME`
- `H:\PortableCodex\codex_portable.bat` as the launcher

The launcher sets `CODEX_HOME` to the local `data` directory, so the portable folder keeps Codex state together:

- `data\auth.json` for CLI auth when file-backed auth is enabled
- `data\.credentials.json` for MCP OAuth fallback credentials
- `data\config.toml`
- `data\log\`
- `data\sessions\`
- `data\history.jsonl`

The installer also writes `data\config.toml` with:

```toml
cli_auth_credentials_store_mode = "file"
mcp_oauth_credentials_store_mode = "file"
```

That forces auth to stay in the portable folder instead of the machine keyring, which is usually what you want for a USB install.

### Build from source

```bash
# Clone the repository and navigate to the root of the Cargo workspace.
git clone https://github.com/openai/codex.git
cd codex/codex-rs

# Install the Rust toolchain, if necessary.
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustup component add rustfmt
rustup component add clippy
# Install helper tools used by the workspace justfile:
cargo install --locked just
# Install nextest for the `just test` helper.
cargo install --locked cargo-nextest

# Build Codex.
cargo build

# Launch the TUI with a sample prompt.
cargo run --bin codex -- "explain this codebase to me"

# After making changes, use the root justfile helpers (they default to codex-rs):
just fmt
just fix -p <crate-you-touched>

# Run the relevant tests (project-specific is fastest), for example:
just test -p codex-tui
# `just test` runs the test suite via nextest:
just test
# Avoid `--all-features` for routine local runs because it increases build
# time and `target/` disk usage by compiling additional feature combinations.
```

## Tracing / verbose logging

Codex is written in Rust, so it honors the `RUST_LOG` environment variable to configure its logging behavior.

The TUI records diagnostics in bounded local stores by default. Set `log_dir` explicitly to enable a plaintext TUI log for a run:

```bash
codex -c log_dir=./.codex-log
tail -F ./.codex-log/codex-tui.log
```

The non-interactive mode (`codex exec`) defaults to `RUST_LOG=error`, but messages are printed inline, so there is no need to monitor a separate file.

See the Rust documentation on [`RUST_LOG`](https://docs.rs/env_logger/latest/env_logger/#enabling-logging) for more information on the configuration options.
