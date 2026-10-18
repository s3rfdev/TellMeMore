#!/usr/bin/env python3
import socket
import subprocess
import threading
import sys
import time

def handle_client(conn, addr, input_device, label):
    print(f"[{label}] Connected from {addr}")
    cmd = [
        "/usr/local/bin/ffmpeg",
        "-nostdin",
        "-loglevel", "error",
        "-f", "avfoundation",
        "-i", input_device,
        "-ar", "16000",
        "-ac", "1",
        "-f", "s16le",
        "-"
    ]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        while True:
            data = proc.stdout.read(3200)
            if not data:
                break
            conn.sendall(data)
    except Exception as e:
        print(f"[{label}] Client disconnected: {e}")
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=1)
        except Exception:
            proc.kill()
        try:
            conn.close()
        except Exception:
            pass
        print(f"[{label}] Closed for {addr}")

def start_server(port, input_device, label):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", port))
    s.listen(5)
    print(f"[{label}] Listening on 0.0.0.0:{port} for device {input_device}...")
    while True:
        try:
            conn, addr = s.accept()
            threading.Thread(target=handle_client, args=(conn, addr, input_device, label), daemon=True).start()
        except Exception as e:
            print(f"[{label}] Accept error: {e}")
            break

if __name__ == "__main__":
    t_bh = threading.Thread(target=start_server, args=(5005, ":BlackHole", "BlackHole:5005"), daemon=True)
    t_mic = threading.Thread(target=start_server, args=(5006, ":0", "Mic:5006"), daemon=True)
    t_bh.start()
    t_mic.start()
    print("Audio relay server is running on ports 5005 (BlackHole) and 5006 (Mic).")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Stopping server.")
