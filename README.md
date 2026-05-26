# Audi MHS2 NAR Navigation Unlock — Research Notes

## Summary

North American Region (NAR) Audi MHS2 head units ship from the factory without an active navigation option. Through reverse engineering, it has been determined that navigation functionality is fully present in the firmware but deliberately disabled via two missing file components and a software license check. This document describes the findings and the complete procedure to restore navigation.

Navigation files are sourced from EU firmware build **1242** and verified working on US firmware **1242**. Compatibility with US firmware **2037** is expected.

Test result is here --> https://www.youtube.com/watch?v=HYwrvbv5j7o

---

## Background

The MHS2 (Multi-HMI System 2) is the infotainment platform used in several Audi models sold in North America. Factory NAR units lack navigation not due to a hardware limitation, but because Audi ships the units without:

1. The navigation application binaries, shared libraries, and supporting data files.
2. The Java class files that integrate the navigation stack with the HMI (Human-Machine Interface) layer.

Additionally, a software license check in the `SWaP` binary prevents the navigation feature from being activated even when the files are present.

---

## Firmware Compatibility

| Firmware | Region | Status |
|----------|--------|--------|
| 1242 | EU | Source of navigation files |
| 1242 | US/NAR | Verified working |
| 2037 | US/NAR | Expected compatible (not yet formally verified) |

The navigation data is extracted from EU build 1242. Since both EU and US 1242 share the same underlying codebase, the files are confirmed to load correctly. The 2037 build has the same base architecture and is expected to work.

---

## Missing Components

### 1. Navigation Application Data (`app_data.zip`)

Contains the navigation-related binaries, shared libraries (`.so` files), and associated data files.

**Deployment path:**
```
/mnt/app/navigation/
```

### 2. HMI Java Class Files (`Navigation.jar`)

Contains Java `.class` files (packaged as a `.jar`) that provide the HMI-side integration for the navigation stack.

**Deployment path:**
```
/mnt/app/eso/hmi/lsd/jars/
```

---

## Binary Patch — `libPresentationController.so`

After deploying the navigation files, the shared library `/mnt/app/navigation/libPresentationController.so` must be patched to remove an internal file-count limit check.

**Patcher source:** `mhs2_libPresentationController.c` — compiled and deployed as part of the SD card payload. Takes the target `.so` as its first argument and patches it in-place.

### Patch Details

The patch targets an ARM instruction sequence that enforces a conditional limit. The replacement forces the branch to always take the success path.

```c
// Skip file count limit
unsigned char needle[] = {
    0x01, 0x00, 0x70, 0xE2,   // SUBS  r0, r0, #1
    0x00, 0x00, 0xA0, 0x33,   // MOVLO r0, #0   <-- conditional fail
    0x1C, 0xD0, 0x8D, 0xE2,
    0xF0, 0x80, 0xBD, 0xE8
};
unsigned char repl[] = {
    0x01, 0x00, 0x70, 0xE2,
    0x01, 0x00, 0xA0, 0xE3,   // MOV   r0, #1   <-- always succeed
    0x1C, 0xD0, 0x8D, 0xE2,
    0xF0, 0x80, 0xBD, 0xE8
};
```

The patcher loops until no further instances of the sequence are found, making the operation fully idempotent.

---

## License Activation — `SWaP` Patcher

Navigation requires a valid license entry at:

```
/net/rcc/persistence/SWaP/el_dat_S.datsig
```

The stock `SWaP` binary at `/net/rcc/ffs/extbin/apps/bin/SWaP` performs the license verification. The tool **`mhs2_SWaP.c` is a patcher** — it modifies the stock `SWaP` binary in-place. It is not a pre-built drop-in replacement.

### What `mhs2_SWaP.c` Patches

Four patch groups are active. Two additional VCRN patches are present in source but commented out.

#### Patches 200 & 201 — EL (Entitlement List) Checks

Bypass entitlement list validation. Patch 200 forces `r0 = 1` (success) instead of propagating a failure result. Patch 201 clears `r0` and sets `r4 = 1` to pre-condition the subsequent entitlement check branch.

```c
// Patch 200 — force EL check to return success
needle: {0x05,0x00,0xA0,0xE1, 0x85,0xDF,0x8D,0xE2, 0xF0,0x8F,0xBD,0xE8, 0xA7,0x51,0x00,0xEB}
repl:   {0x01,0x00,0xA0,0xE3, 0x85,0xDF,0x8D,0xE2, 0xF0,0x8F,0xBD,0xE8, 0xA7,0x51,0x00,0xEB}
//  MOV r0,#1 ^^^

// Patch 201 — pre-condition EL check registers
needle: {0x01,0x40,0x70,0xE2, 0x00,0x40,0xA0,0x33, 0x72,0x41,0xFE,0xEB, 0x03,0x10,0xA0,0xE3}
repl:   {0x00,0x00,0xA0,0xE3, 0x01,0x40,0xA0,0xE3, 0x72,0x41,0xFE,0xEB, 0x03,0x10,0xA0,0xE3}
//  MOV r0,#0  MOV r4,#1 ^^^
```

Sets `patch_status |= 0x2`.

#### Patches 100 & 101 — FSC Signature Checks

Two variants covering slight differences between firmware builds. Both force the FSC (Feature Scope Code) signature conditional to always return success by flipping one byte (`0x00 → 0x01`) in the `MOVNE` instruction.

```c
// Patch 100 — FSC variant A
needle: {..., 0x00,0x00,0xA0,0x13, ...}   // MOVNE r0, #0  (fail on mismatch)
repl:   {..., 0x01,0x00,0xA0,0x13, ...}   // MOVNE r0, #1  (always succeed)

// Patch 101 — FSC variant B (same logic, slightly different context bytes)
```

Sets `patch_status |= 0x1`.

### Success Condition

The patcher exits with `EXIT_SUCCESS` only if `patch_status & 0x3` — meaning **at least one EL patch and at least one FSC patch** were successfully applied. If either group fails to match (wrong firmware version, already patched differently), the tool exits with failure and the binary is left unmodified.

### Deployment After Patching

Copy the patched `SWaP` binary to:
```
/net/rcc/ffs/audimib/
```

Modify `/net/rcc/ffs/etc/envsettings` so the system searches `/net/rcc/ffs/audimib/` before other locations when resolving the `SWaP` executable.

### Automation

This procedure is automated by a separate community tool. Reference:

> https://www.a5oc.com/threads/mhs2-navigation-and-firmware-updates-currently-2023-2024.178538/?post_id=1632559

---

## Full Deployment Checklist

| Step | Action | Detail |
|------|--------|--------|
| 1 | Deploy navigation app data | `/mnt/app/navigation/` |
| 2 | Deploy HMI jar | `/mnt/app/eso/hmi/lsd/jars/` |
| 3 | Patch `libPresentationController.so` | Tool: `mhs2_libPresentationController` |
| 4 | Patch stock `SWaP` binary | Tool: `mhs2_SWaP` (input: `/net/rcc/ffs/extbin/apps/bin/SWaP`) |
| 5 | Deploy patched `SWaP` | `/net/rcc/ffs/audimib/SWaP` |
| 6 | Redirect loader | Modify `/net/rcc/ffs/etc/envsettings` |

---

## Ways to make MAP SD
https://github.com/LateAlways/MHI2-to-MHS2
https://github.com/congobg/MHS2_NAR_NAV/blob/main/support_files/delphi_harman_map.php (i used this back in 2022 to make the NAR map, before that in 2021 to make the MHS map from MHI2 map, code is not pretty but it did the job back then)

## Notes

- Navigation files are sourced from EU firmware 1242; verified on US 1242; expected compatible with US 2037.
- All patchers (`mhs2_SWaP`,`mhs2_libPresentationController` and `mhs2_SWaP`) are idempotent.
- All patches target ARM 32-bit instruction encoding (little-endian).
- Delivery is typically via SD card.
