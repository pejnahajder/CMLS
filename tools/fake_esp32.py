"""
Fake ESP32 — sends the 5 sensor streams to JUCE at 127.0.0.1:9001 over OSC.

Sweep mode (default): 4 floats vary sinusoidally in [0, 1] with independent
periods; 1 int variometer cycles in [-5, +5] with a slower period.

Run from Windows:  python tools\\fake_esp32.py
Stop:              Ctrl+C

Requires: python-osc  (pip install python-osc)
"""

from pythonosc.udp_client import SimpleUDPClient
import time
import math

TARGET_IP   = "127.0.0.1"
TARGET_PORT = 9001
RATE_HZ     = 30          # update rate per stream
MAX_RUN_S   = 600         # safety cap on run length


def main():
    client = SimpleUDPClient(TARGET_IP, TARGET_PORT)
    print(f"Fake ESP32 -> {TARGET_IP}:{TARGET_PORT}  ({RATE_HZ} Hz, Ctrl+C to stop)")

    t0 = time.monotonic()
    period = 1.0 / RATE_HZ

    try:
        while True:
            t = time.monotonic() - t0
            if t > MAX_RUN_S:
                print("Max run length reached.")
                break

            # 4 floats in [0, 1], each with a different period -> visually independent
            front = 0.5 + 0.5 * math.sin(2 * math.pi * t /  3.0)
            left  = 0.5 + 0.5 * math.sin(2 * math.pi * t /  5.0)
            right = 0.5 + 0.5 * math.sin(2 * math.pi * t /  7.0)
            accel = 0.5 + 0.5 * math.sin(2 * math.pi * t / 11.0)

            # variometer: int [-5, +5], slow period
            vario = int(round(5 * math.sin(2 * math.pi * t / 13.0)))

            client.send_message("/in/sonar/front", front)
            client.send_message("/in/sonar/left",  left)
            client.send_message("/in/sonar/right", right)
            client.send_message("/in/accel",       accel)
            client.send_message("/in/vario",       vario)

            time.sleep(period)
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
