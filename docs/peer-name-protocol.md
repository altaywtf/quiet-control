# Peer-name investigation

QC35 II peer aliases remain local. No supported write path was found in Bose
Connect 25.2's device-management packet factory. A single authorized SET_GET
probe of peer Info on firmware 4.8.1 returned error 5 (unsupported operator).
This rules out that tested path, not every possible undocumented setter.

## Sources

- [Bose Connect 25.2 APK listing](https://apkpure.net/bose-connect/com.bose.monet/download/25.2),
  package `com.bose.monet`, version code `215`.
  Download SHA-256:
  `433358d0d4ea934ba4a44b2c8d9b24d2c1cb85aec611f24e69c6973a400f8683`.
  Inspected statically using JADX 1.5.6; the APK was not executed. The mirror's
  publisher identity was not independently authenticated. Decompiled source and
  the APK are temporary research inputs, not distributed with this project.
- Classes under `io.intrepid.bose_bmap.model`: factories
  `DeviceManagementPackets` and `ProductInfoPackets`; parsers `i` (original source
  name `DeviceManagementBmapPacketParser.java`) and `z`; model `k`
  (`FunctionBlocksBitSet.java`), and `hc.c` (`BitSetUtil.java`).
- [Independent device-management catalog](https://github.com/iclemens/bose/blob/fed1311fc84aa53e59053abfc001e5fedade2ef7/wireshark/bose.lua)
  corroborates function IDs, but targets NC700.
- [Newer BMAP research](https://github.com/aaronsb/bosectl/blob/c46a1f607ee717b958dd9f880f7dbb2344b2f543/NOTES.md)
  corroborates the factory names. Its newer-device authentication conclusions
  must not be assumed to apply to QC35 II.

## App implementation findings

| Function | Request | Finding |
| --- | --- | --- |
| Peer info | `04 05 01 06` + six-byte address | Only GET builder present; no name writer |
| Extended peer info | Function `04 06` | Enum exists, but no builder or response parser |
| Headphone name | Function `01 02` | Separate from saved peer names |
| Get all functions | `00 04 05 00` | START, no payload; not a GET with a block selector |
| Supported function blocks | `00 02 01 00` | Big-endian bitset; bit N denotes block N |

Peer-info response payload:

- Bytes 0–5: Bluetooth address, display order.
- Byte 6: bit 0 connected, bit 1 local/controller, bit 2 Bose product.
- Normal peer: UTF-8 name starts at byte 9.
- Bose peer: product ID in bytes 7–8, variant in byte 9; name starts at byte 10.

Connection actions emit PROCESSING (7) before terminal RESULT (6). Receiving a
processing acknowledgement is insufficient evidence that the action completed.
An ERROR (4) response must be surfaced directly, without waiting for timeout.
Error 5 means unsupported operator; it does not by itself prove authentication
is required.

## Hardware observations

The connected product identified as QC35 II (`4020`), firmware `4.8.1`.
Device-management block info returned ASCII `1.0.4`.

| Request | Response |
| --- | --- |
| `00 05 01 00` | `00 05 03 05 34 2E 38 2E 31` |
| `00 02 01 00` | `00 02 03 03 01 03 3F` |
| `04 00 01 00` | `04 00 03 05 31 2E 30 2E 34` |
| Initial hypothesis `00 04 01 01 04` | ERROR 5 |
| App-derived `00 04 05 00` | PROCESSING then RESULT, both empty |
| `04 06 01 06` + current-host address | STATUS: six-byte address, then `07 07` |

Between the GetAllFunctions markers, responses were product firmware (`0.5`),
MAC (`0.6`), and serial (`0.7`). Their identifying payloads were omitted from the
diagnostic output. No writable-function or operator mask was returned.
The two extended-info trailing bytes remain unidentified; this response does
not contain the peer's UTF-8 name.

The observations above came from read operations. No alias-write capability or
power-cycle persistence has been established. Use `--inspect-protocol` to repeat
the bounded read-only diagnostic; it omits peer names, addresses, and serials.

## Authorized peer-info write probe

One SET_GET was sent to the current controlling Mac's entry, with the entire
freshly read 17-byte Info payload unchanged: `04 05 02 11` followed by that
payload. The headphones rejected function `4.5` with ERROR payload `05`.

Subsequent GETs verified:

- The set of paired addresses was unchanged (two entries).
- The full current-host Info payload was byte-for-byte unchanged.
- Its name was unchanged, and connected/local flags remained set.

The write probe is not included in the app. The normal diagnostic remains
read-only. Further undocumented writes require separate authorization; do not
sweep opcodes or probe firmware/debug writes.
