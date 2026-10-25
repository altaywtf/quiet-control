# Peer-name investigation

QC35 II peer aliases remain local. No supported write path was found in Bose
Connect 25.2's device-management packet factory. A single authorized SET_GET
probe of peer Info on firmware 4.8.1 returned error 5 (unsupported operator).
This rules out that tested path, not every possible undocumented setter.

Sources, hardware observations, and the authorized write probe live in the
[Quiet Control peer-name research](https://app.notion.com/p/3e5e75710b5281999cc8c6a31e5a9e5c)
Notion section.

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

## Diagnostics

`--inspect-protocol` repeats the bounded read-only diagnostic; it omits peer
names, addresses, and serials. The write probe is not included in the app.
Further undocumented writes require separate authorization; do not sweep
opcodes or probe firmware/debug writes.
