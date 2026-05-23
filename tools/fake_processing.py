"""
Fake Processing UI — sends a single /cfg/apply message to JUCE at 127.0.0.1:9002.
Simulates the APPLY click in the real Processing sketch (ControlPanel.pde).

Wire format (locked 2026-05-21 in Processing):
  /cfg/apply   5 floats positional: (bpmMin, bpmMax, freqMin, freqMax, alarmThr)

Usage:
  python tools\\fake_processing.py                            # defaults (40, 200, 80, 800, 3.0)
  python tools\\fake_processing.py 60 180 100 600 2.5         # custom
  python tools\\fake_processing.py --extreme                  # exaggerated values to make the change audible

Requires: python-osc  (pip install python-osc)
"""

from pythonosc.udp_client import SimpleUDPClient
import sys

TARGET_IP   = "127.0.0.1"
TARGET_PORT = 9002

DEFAULTS = (40.0, 200.0, 80.0, 800.0, 3.0)
EXTREME  = (30.0, 600.0, 200.0, 1200.0, 1.5)   # roughly the SC team's CAVEDIVING ranges


def main():
    args = sys.argv[1:]

    if not args:
        values = DEFAULTS
    elif args == ["--extreme"]:
        values = EXTREME
    elif len(args) == 5:
        try:
            values = tuple(float(a) for a in args)
        except ValueError:
            print(__doc__)
            sys.exit(1)
    else:
        print(__doc__)
        sys.exit(1)

    bpm_min, bpm_max, freq_min, freq_max, alarm_thr = values

    client = SimpleUDPClient(TARGET_IP, TARGET_PORT)
    client.send_message("/cfg/apply", list(values))

    print(f"Sent /cfg/apply -> {TARGET_IP}:{TARGET_PORT}")
    print(f"  bpm    = [{bpm_min}, {bpm_max}]")
    print(f"  freq   = [{freq_min}, {freq_max}]")
    print(f"  alarm  = {alarm_thr}")


if __name__ == "__main__":
    main()
