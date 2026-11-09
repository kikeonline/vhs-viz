# Initial scan observation

The scanner log was inspected during the initial installed-host scan, before later launches overwrote it. The following lines were returned by the log read on 2026-11-09:

```text
2026/11/09 12:13:46.857 [Info]: UI Status: Scanning 1 of 9: VHS Phase 3A
2026/11/09 12:13:46.858 [Info]: Scan next file in scan process: VHS Phase 3A
2026/11/09 12:13:47.951 [Info]: Scan file completed: scan process result = 0x00000000 class data: YES
```

The current `studio-one-scan.txt` is a later launch's cached-class observation, not that initial log. Subsequent actual instantiation, native editor, simultaneous audio/MIDI/CC, recall and removal were observed separately.
