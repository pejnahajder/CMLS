"""
Fake Arduino MKR — sends the 5 sensor streams to JUCE at 127.0.0.1:9000 over OSC.

Matches the actual Arduino code on branch `arduino` (CMLS_arduino.ino):
  /sensor/space/pan        float [-1, +1]   (= gravity1 - gravity2, low-pass filtered)
  /sensor/space/width      float [0, 1]     (= (gravity1 + gravity2) / 2, low-pass filtered)
  /sensor/space/depth      float [0, 1]     (HCSR04, 0 = wall close, 1 = far)
  /sensor/position/tilt    float [0, 1]     (MMA accel X normalised, neutral ~0.5)
  /sensor/position/speed   float            (joystick discrete, real Arduino sends {0, 2.5, 5, 7.5, 10})

Sweep mode (default): independent sinusoids with different periods so the
streams look visually distinct in JUCE. Speed sweeps continuously in [0, 10]
(not the discrete joystick values) — easier to test the alarm threshold.

Run from Windows:  python tools\\fake_esp32.py
Stop:              Ctrl+C

Requires: python-osc  (pip install python-osc)
"""

from pythonosc.udp_client import SimpleUDPClient
import time
import math

TARGET_IP   = "127.0.0.1"
TARGET_PORT = 9000        # aligned to Arduino's remotePort
RATE_HZ     = 10          # match Arduino's SEND_INTERVAL_MS = 100
MAX_RUN_S   = 600


def main():
    client = SimpleUDPClient(TARGET_IP, TARGET_PORT)
    print(f"Fake Arduino -> {TARGET_IP}:{TARGET_PORT}  ({RATE_HZ} Hz, Ctrl+C to stop)")

    t0 = time.monotonic()
    period = 1.0 / RATE_HZ

    try:
        while True:
            t = time.monotonic() - t0
            if t > MAX_RUN_S:
                print("Max run length reached.")
                break

            # pan in [-1, +1], period 5s
            pan = math.sin(2 * math.pi * t / 5.0)

            # width in [0, 1], period 7s
            width = 0.5 + 0.5 * math.sin(2 * math.pi * t / 7.0)

            # depth in [0, 1], period 3s (frontal sonar oscillation)
            depth = 0.5 + 0.5 * math.sin(2 * math.pi * t / 3.0)

            # tilt in [0, 1], period 11s (head tilt)
            tilt = 0.5 + 0.5 * math.sin(2 * math.pi * t / 11.0)

            # speed in [0, 10], period 13s — continuous sweep crosses the 3.0
            # alarm threshold predictably, useful to verify edge-trigger behaviour.
            speed = 5.0 + 5.0 * math.sin(2 * math.pi * t / 13.0)

            client.send_message("/sensor/space/pan",      pan)
            client.send_message("/sensor/space/width",    width)
            client.send_message("/sensor/space/depth",    depth)
            client.send_message("/sensor/position/tilt",  tilt)
            client.send_message("/sensor/position/speed", speed)

            time.sleep(period)
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
