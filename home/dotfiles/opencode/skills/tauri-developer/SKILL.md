---
name: tauri-developer
description: Build cross-platform desktop apps with Tauri 2 — the Rust + web framework. Use when working on a Tauri project, writing Rust commands (tauri::command), setting up IPC between the Rust backend and the web frontend, using tauri events/emit/listen, managing Rust state, calling invoke from JS/TS, or troubleshooting the Rust <-> frontend bridge. Trigger terms: Tauri, tauri, rust backend, invoke, tauri command, tauri state, window events, Tauri 2, tauri IPC.
license: MIT
compatibility: opencode
metadata:
  version: "1.0.0"
  domain: desktop
  role: specialist
  scope: implementation
  triggers: Tauri, tauri, rust, invoke, tauri::command, tauri state, IPC, emit, listen, Tauri 2, desktop app
  related-skills: react-expert, typescript-pro, javascript-pro, rust-expert, secure-code-guardian
  output-format: code
---

# Tauri 2 Developer

Senior specialist in building production desktop apps with Tauri 2 (the Rust + web framework). Covers the Rust backend, the IPC bridge, events, state management, and how the web frontend talks to it — the parts that are Tauri-specific (the frontend framework itself is covered by react-expert/vue-expert).

## When to Use This Skill

- Setting up or structuring a Tauri 2 project (Rust + frontend).
- Writing `tauri::command` functions in Rust and exposing them.
- Calling Rust commands from the frontend via the `invoke` API.
- Sharing data between Rust and the frontend / managing state.
- Emitting and listening to events (frontend <-> Rust).
- Working with `tauri.conf.json` (capabilities, plugins, windows, bundles).
- Debugging "Command X not found", permission errors, or invoke failures.

## Key Concepts

### Project structure (Tauri 2)
```
src-tauri/
  src/
    main.rs        # entrypoint, calls tauri::Builder
    lib.rs         # the run() function and builder setup
    commands/      # your #[tauri::command] functions (organize here)
  tauri.conf.json  # app config: identifier, windows, plugins, bundles
  capabilities/    # permission files (json), e.g. default.json
  Cargo.toml
src/               # the web frontend (React/Vue/etc + Vite)
```
- The Rust binary lives entirely under `src-tauri/`; it is NOT a GUI-only thing — it is the whole backend.
- `tauri.conf.json` `identifier` must be unique and set (e.g. `com.yourname.app`); used for bundling/paths.

### Rust entry point (main.rs / lib.rs)
```rust
// main.rs usually just calls the run fn in lib.rs
// lib.rs:
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![greet])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

### Defining a command (Rust)
```rust
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}!", name)
}

// async commands for heavy work (use tokio runtime provided by Tauri)
#[tauri::command]
async fn fetch_data(url: String) -> Result<String, String> {
    // blocking work should NOT block the main thread; use spawn_blocking
    let body = tauri::async_runtime::spawn_blocking(move || {
        // heavy/blocking IO here
        std::thread::sleep(std::time::Duration::from_secs(1));
        "done".to_string()
    })
    .await
    .map_err(|e| e.to_string())?;
    Ok(body)
}
```

### Registering commands
```rust
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![greet, fetch_data])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

### Calling a command from the frontend (JS/TS)
```ts
import { invoke } from "@tauri-apps/api/core";

// simple
const msg = await invoke<string>("greet", { name: "World" });

// with error handling — Rust Result maps to rejected promise
try {
  const data = await invoke<string>("fetch_data", { url: "..." });
} catch (e) {
  console.error("Command failed:", e);
}
```

### Managing state (Rust State + managed)
```rust
struct AppState { /* ... */ }

#[tauri::command]
fn use_state(state: tauri::State<'_, AppState>) -> String {
    // state is read-only by default; use Mutex/MutexGuard inside for mutation
    format!("app state ready")
}

pub fn run() {
    tauri::Builder::default()
        .manage(AppState { /* init */ })
        .invoke_handler(tauri::generate_handler![use_state])
        .run(tauri::generate_context!())
        .expect("...");
}
```
- Use `tauri::State<'_, T>` to inject managed state into commands.
- For mutable state use `Mutex<T>` (or `RwLock`) inside `State`.

### Events (frontend <-> Rust)
```rust
// Rust: emit to frontend
app_handle.emit("progress", 42).unwrap();

// Rust: listen from frontend (returns a channel)
use tauri::Emitter;
app_handle.emit("download-progress", payload).unwrap();
```
```ts
// Frontend: listen
import { listen } from "@tauri-apps/api/event";

const unlisten = await listen<number>("progress", (event) => {
  console.log("progress:", event.payload);
});
// unlisten() when no longer needed
```

### Important gotchas
- **Permissions/capabilities**: a command may fail with a permission error if not allowed in `src-tauri/capabilities/*.json`. Plugins & core commands need `permissions` entries (e.g. `"core:default"`, `"shell:allow-open"`). Add them before calling.
- **CSP**: `tauri.conf.json` `app.security.csp` — add trusted sources; keep it strict to avoid XSS.
- **Invoke arg naming**: JS object keys must match Rust snake_case args exactly (`{ filePath }` -> `file_path`). Mismatch = "unknown variant" errors.
- **Async vs blocking**: never block the main thread with heavy sync work; use `tauri::async_runtime::spawn_blocking`.
- **Serialization**: return `serde::Serialize` types; for results either return the value directly or `Result<T, String>` (Error type that implements `Into<String>`).

## Verification
- After adding a command, run `cargo check` (inside `src-tauri/`) to validate Rust compiles.
- Test invoke from the frontend devtools; check the console for "Command ... not found" (usually a missing registration or permission).
- Confirm `tauri.conf.json` identifier is set before bundling.

## Rules
- Always place business logic in Rust commands; keep the frontend as the view layer.
- Use `tauri::command` for anything that needs system access; do NOT use the webview's native APIs for filesystem/shell when Tauri plugins exist.
- Keep permissions minimal (principle of least privilege) and document why each is needed.
- Answer in Spanish unless the user works in English.
