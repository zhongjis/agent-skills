# Bit-Level Layout in Rust

Part of [zero-cost-safety.md](zero-cost-safety.md).

## 4. Bit-Level Layout — repr, Packed Structs, Bitfields

Zig: `packed struct` with bit-level field control. Rust matches with `#[repr]` attributes and bitfield crates.

### #[repr(C)] — Guaranteed C-Compatible Layout

```rust
#[repr(C)]
struct Header {
    magic: [u8; 4],
    version: u16,
    flags: u16,
    length: u32,
}
// Layout is C ABI: fields in declaration order, C padding rules.
// Safe to transmute from/to byte arrays via zerocopy.
```

### #[repr(C, packed)] — No Padding

```rust
#[repr(C, packed)]
struct WireHeader {
    tag: u8,
    length: u16, // NOT aligned to 2-byte boundary
    checksum: u32,
}
// Total size: exactly 7 bytes. No padding.
// WARNING: taking &self.length is UB if unaligned. Use read_unaligned or zerocopy.
```

**Safe access pattern:**

```rust
use std::ptr;

impl WireHeader {
    fn length(&self) -> u16 {
        // SAFETY: packed field may be unaligned; ptr::read_unaligned handles this.
        unsafe { ptr::read_unaligned(ptr::addr_of!(self.length)) }
    }
}

// Better: use zerocopy to avoid manual unsafe entirely
use zerocopy::{FromBytes, IntoBytes, KnownLayout, Immutable};

#[derive(FromBytes, IntoBytes, KnownLayout, Immutable)]
#[repr(C, packed)]
struct WireHeader {
    tag: u8,
    length: [u8; 2], // manual byte array avoids alignment issues
    checksum: [u8; 4],
}

impl WireHeader {
    fn length(&self) -> u16 { u16::from_le_bytes(self.length) }
    fn checksum(&self) -> u32 { u32::from_le_bytes(self.checksum) }
}
```

### bitfield — Bit-Level Flag Packing

```rust
use bitfield::bitfield;

bitfield! {
    pub struct Permissions(u8);
    impl Debug;
    pub bool, readable,  set_readable:  0;
    pub bool, writable,  set_writable:  1;
    pub bool, executable, set_executable: 2;
    pub u8,   level,     set_level:     5, 3; // bits 3-5
}

let mut p = Permissions(0);
p.set_readable(true);
p.set_level(5);
assert!(p.readable());
assert_eq!(p.level(), 5);
```

### modular-bitfield — Richer Bitfield API

```rust
use modular_bitfield::prelude::*;

#[bitfield(bits = 16)]
#[derive(Debug)]
pub struct StatusWord {
    ready: bool,           // 1 bit
    error_code: B4,        // 4 bits
    #[skip] __: B3,        // 3 bits padding
    priority: B8,          // 8 bits
}
```

### zerocopy — Safe Zero-Copy Parsing

```rust
use zerocopy::{FromBytes, IntoBytes, KnownLayout, Immutable, Ref};

#[derive(FromBytes, IntoBytes, KnownLayout, Immutable)]
#[repr(C)]
struct Packet {
    header: [u8; 4],
    payload_len: u32,
}

fn parse(bytes: &[u8]) -> Option<&Packet> {
    Ref::<_, Packet>::from_prefix(bytes).map(|(pkt, _rest)| pkt.into_ref()).ok()
}
// Zero-copy, zero-allocation, fully safe. No transmute, no pointer cast.
```

### Cargo.toml

```toml
zerocopy = { version = "0.8", features = ["derive"] }
bitfield = "0.17"
modular-bitfield = "0.11"
bytemuck = { version = "1", features = ["derive"] }  # alternative to zerocopy
```

---
