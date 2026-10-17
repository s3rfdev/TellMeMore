import socket
import subprocess
import sys

def main():
    port = 5005
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(('0.0.0.0', port))
    s.listen(5)
    print(f"Audio streamer listening on port {port}...", flush=True)

    while True:
        try:
            conn, addr = s.accept()
            print(f"Client connected: {addr}", flush=True)
            proc = subprocess.Popen(
                [
                    "/usr/local/bin/ffmpeg",
                    "-nostdin",
                    "-loglevel", "error",
                    "-f", "avfoundation",
                    "-i", ":BlackHole 2ch",
                    "-ar", "16000",
                    "-ac", "1",
                    "-f", "s16le",
                    "-"
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL
            )
            try:
                while True:
                    chunk = proc.stdout.read(3200)
                    if not chunk:
                        break
                    conn.sendall(chunk)
            except (BrokenPipeError, ConnectionResetError):
                pass
            finally:
                proc.terminate()
                try:
                    proc.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    proc.kill()
                conn.close()
                print(f"Client disconnected: {addr}", flush=True)
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error: {e}", flush=True)

if __name__ == '__main__':
    main()
