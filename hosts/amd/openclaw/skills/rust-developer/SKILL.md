---
name: rust-developer
description: Write idiomatic, production-grade Rust. Use when writing Rust code for backends, Tauri command logic, CLIs, or any system-level code. Improves ownership/borrowing correctness, error handling (Result/anyhow/thiserror), async with tokio, serde serialization, traits/generics, and project structure (Cargo). Trigger terms: Rust, rust, Cargo, borrow checker, ownership, Result, tokio, serde, enum, trait, async, clippy, profile, cargo build.
license: MIT
compatibility: opencode
metadata:
  version: "1.0.0"
  domain: systems
  role: specialist
  scope: implementation
  triggers: Rust, rust, cargo, borrow, ownership, Result, tokio, serde, trait, async, lifetimes, clippy
  related-skills: tauri-developer, golang-pro, secure-code-guardian, typescript-pro
  output-format: code
---

# Rust Developer

Senior Rust specialist. Focus on writing code that compiles the first time and is idiomatic: correct ownership/borrowing, clean error handling, sensible async, and efficient data modeling. Strongly complements the `tauri-developer` skill for desktop apps.

## When to Use This Skill

- Writing Rust business logic, backends, CLIs, or Tauri commands beyond trivial examples.
- Fighting the borrow checker / lifetime errors.
- Choosing error-handling style (thiserror for libraries, anyhow for apps).
- Setting up async with tokio (or feature-gated runtimes).
- Deserializing/serializing JSON or config with serde.
- Organizing a Cargo workspace and modules.
- Optimizing with the right profiles, unsafe blocks, or ownership patterns.

## Core Idioms

### Ownership & borrowing (the classic errors)
- There is only one owner; references (`&T`) are read-only borrows, `&mut T` exclusive.
- Cannot borrow as mutable more than once, or combine `&T` and `&mut T` in the same scope (use scoping `{}` or clone).
- To move data out of a struct/option/result, destructure or use `Option::take`/`mem::replace` — not a direct move.

### Error handling
```rust
// App: anyhow for simple contexts
use anyhow::{Result, Context};
fn do_thing() -> Result<()> {
    let f = std::fs::read_to_string("x.txt").context("reading x.txt")?;
    Ok(())
}

// Library: thiserror for typed domain errors
#[derive(thiserror::Error, Debug)]
enum AppError {
    #[error("not found: {0}")]
    NotFound(String),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}
```
- Prefer `?` over manual `match` on `Result`/`Option` whenever possible.
- Custom error enums implement `std::error::Error` (use thiserror).

### Async with tokio
```rust
#[tokio::main]
async fn main() {
    let handles: Vec<_> = (0..5).map(|i| tokio::spawn(async move { i })).collect();
    for h in handles { let _ = h.await; }
}
```
- `tokio::spawn` requires `Send` futures; move owned data in, don't borrow across await.
- Blocking work on async runtimes → `tokio::task::spawn_blocking`.

### Serialization with serde
```rust
use serde::{Deserialize, Serialize};
#[derive(Debug, Serialize, Deserialize)]
struct Config { name: String, #[serde(default)] retries: u32 }
let cfg: Config = serde_json::from_str(raw)?;
```
- Use `#[serde(default)]` for optional fields, `rename_all = "camelCase"` for frontend interchange.

### Traits & enums (idiomatic modeling)
```rust
trait Area { fn area(&self) -> f64; }
enum Shape { Circle(f64), Rect(f64, f64) }
impl Area for Shape {
    fn area(&self) -> f64 {
        match self {
            Shape::Circle(r) => std::f64::consts::PI * r * r,
            Shape::Rect(w, h) => w * h,
        }
    }
}
```

### Options/Result combinations
- `Option::and_then`, `unwrap_or`, `ok_or`, `Result::map`, `and_then`, `transpose`.

## Common Gotchas
- **`&str` vs `String`**: use `&str` for function args (borrow), `String` for owned storage.
- **Generics with lifetimes**: when returning `&` from a function, the lifetime ties to the input — use `'a`.
- **Mutex poisoning**: `lock().unwrap()` panics if another thread panicked while holding; handle or use `parking_lot::Mutex`.
- **Integer overflow** in debug panics; use `checked_add`/`saturating_add` when needed.
- **Performance**: prefer `Vec` over `LinkedList`, avoid `clone()` in hot loops, use `Cow`/references when possible.
- **Unsafe**: avoid; if truly needed, wrap in a safe API with a safety comment.

## Project Structure (Cargo)
```
src/main.rs        # binary entry
src/lib.rs         # shared library (for tests + reuse)
src/models.rs      # data types (serde structs/enums)
src/error.rs       # error enum + From impls
tests/             # integration tests (use the public API)
```

## Verification
- Run `cargo check` for fast compile validation.
- Run `cargo clippy -- -D warnings` for idiomatic lints (treat as required for production code).
- Run `cargo test` for unit + integration tests.
- `cargo fmt --check` to keep formatting consistent.

## Rules
- Favor idiomatic Rust over clever one-liners; readability > brevity.
- Follow the borrow checker rather than fighting it (restructure instead of `unsafe`/`clone` spam).
- Use established crates (tokio, serde, anyhow/thiserror, clap for CLIs) over hand-rolled wheels.
- Answer in Spanish unless the user works in English.
