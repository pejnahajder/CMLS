"""
Fake SuperCollider — listens on 127.0.0.1:57120 and prints every OSC message
received from JUCE.

Run from Windows:  python tools\\fake_sc.py
Stop:              Ctrl+C

Requires: python-osc  (pip install python-osc)
"""

from pythonosc.dispatcher import Dispatcher
from pythonosc.osc_server import ThreadingOSCUDPServer

LISTEN_IP   = "127.0.0.1"
LISTEN_PORT = 57120


def handler(address, *args):
    # One-line readable dump per incoming message
    if len(args) == 1:
        print(f"{address:18s}  {args[0]}")
    else:
        print(f"{address:18s}  {args}")


def main():
    disp = Dispatcher()
    disp.set_default_handler(handler)

    server = ThreadingOSCUDPServer((LISTEN_IP, LISTEN_PORT), disp)
    print(f"Fake SC listening on {LISTEN_IP}:{LISTEN_PORT}  (Ctrl+C to stop)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
        server.shutdown()


if __name__ == "__main__":
    main()
