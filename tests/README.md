# Metal Quake Tests

Minimal test harness for the Metal Quake engine. Tests live as plain C
programs in this directory rather than a linked XCTest bundle, because
the engine itself is not a static library — it compiles into the
executable. Each test file declares its own `main()` and exercises a
narrow slice of engine behavior by linking against the same sources.

## Running

```sh
./tests/run.sh
```

## What's covered

- `test_settings.c` — round-trip `MQ_SaveSettings` / `MQ_LoadSettings`
  across every struct field, verifying defaults + persistence.
- `test_net_parse.c` — `UDP_StringToAddr` / `UDP_AddrToString` /
  `UDP_AddrCompare` semantics against reference BSD sockaddr_in values.
- `test_circbuf.c` — `CircleBuffer` producer/consumer correctness
  under contention.

## What's not covered

- Graphics / Metal pipeline — requires a live Metal device
- PHASE spatial audio — requires PHASE framework at runtime
- Game-loop / Host_Frame — requires mocked BSP data

Those would need the harness to pull in the whole `src/macos/` stack,
which we avoid to keep tests fast and hermetic.
