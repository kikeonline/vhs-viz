#!/usr/bin/env python3
"""Deterministic, copyright-free Studio One routing fixtures (no device input)."""
import math
from pathlib import Path
import struct
import wave


def vlq(value):
    result = [value & 127]
    value >>= 7
    while value:
        result.insert(0, 128 | (value & 127))
        value >>= 7
    return bytes(result)


def midi(path, controller):
    events = b'\0\xff\x51\x03\x07\xa1\x20'
    for delay, message in [(0, bytes([0xB0, controller, 32])),
                           (0, bytes([0x90, 60, 96])),
                           (1440, bytes([0xB0, controller, 96])),
                           (1440, bytes([0x80, 60, 0])),
                           (960, bytes([0xB0, controller, 0]))]:
        events += vlq(delay) + message
    events += b'\0\xff\x2f\0'
    path.write_bytes(b'MThd' + struct.pack('>IHHH', 6, 0, 1, 480)
                     + b'MTrk' + struct.pack('>I', len(events)) + events)


root = Path('/tmp')
with wave.open(str(root / 'VHS-phase3a-probe.wav'), 'wb') as output:
    output.setparams((2, 2, 44100, 0, 'NONE', 'not compressed'))
    output.writeframes(b''.join(struct.pack('<hh', *(2 * [int(32767 * .25 * math.sin(2 * math.pi * 220 * i / 44100))]))
                               for i in range(44100 * 4)))
midi(root / 'VHS-phase3a-notes.mid', 1)
midi(root / 'VHS-phase3a-learn.mid', 74)
print('Created /tmp/VHS-phase3a-probe.wav, VHS-phase3a-notes.mid, VHS-phase3a-learn.mid')
