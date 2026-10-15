# Screen variant set format

Show three variants side by side when they fit; otherwise stack them with clear labels. Use phone width (~32 cols) or desktop width (~70 cols) to match the target device.

```
 A: List first           B: Map first            C: Next-stop focus
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ Route 12    ⟳    │    │ ░░░░ map ░░░░░░  │    │ NEXT STOP        │
│ ─────────────────│    │ ░░░●░░░░░░░░░░░  │    │ Plaza Central    │
│ ● Stop 1  08:10  │    │ ░░░░░░●░░░░░░░░  │    │ ETA 4 min        │
│ ○ Stop 2  08:25  │    │──────────────────│    │                  │
│ ○ Stop 3  08:40  │    │ Next: Stop 2     │    │ [ ARRIVED ]      │
│                  │    │ ETA 08:25        │    │ [ SKIP STOP ]    │
│ [ START ]        │    │ [ START ]        │    │ 3 of 9 stops     │
└──────────────────┘    └──────────────────┘    └──────────────────┘
```

Then ask, in the user's language: "Which one? Mixing is welcome, e.g. 'B with A's list'."

After the pick, show:

**What this UI demands from the backend**

| UI element | Backend demand | New? |
|---|---|---|
| ETA per stop | Per-stop ETA from segment times | yes |
| Map without signal | Offline map tiles cached on device | yes |
| SKIP STOP | `stop_skipped` event with timestamp | yes |

**Data inventory**

| Shown data | Actions | States |
|---|---|---|
| stop name, ETA, progress | arrived, skip | empty: no route assigned; loading; error: sync failed; offline: cached route + queued events |

Rows marked "New?" = yes are added to scope and checked against the deadline.
