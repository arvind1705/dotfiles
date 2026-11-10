#!/usr/bin/env python3
"""
Devbox System Metrics Exporter
A lightweight, zero-dependency telemetry daemon providing real-time CPU, memory,
disk, network, and process metrics inspired by btop.
Listens on 127.0.0.1:9108 for Caddy reverse-proxying.
"""

import os
import sys
import time
import json
import shutil
import subprocess
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 9108
HOST = "127.0.0.1"

class MetricsCollector:
    def __init__(self):
        self.lock = threading.Lock()
        self.last_cpu_time = 0
        self.last_cpu_stat = self._read_cpu_stat()
        self.last_net_time = 0
        self.last_net_bytes = self._read_net_bytes()
        self.cpu_name = self._get_cpu_name()
        self.cores = os.cpu_count() or 1
        self.cached_metrics = None
        self.last_sample_time = 0

    def _get_cpu_name(self):
        try:
            with open("/proc/cpuinfo", "r") as f:
                for line in f:
                    if "model name" in line:
                        return line.split(":", 1)[1].strip()
        except Exception:
            pass
        return "Generic x86_64 CPU"

    def _read_cpu_stat(self):
        try:
            with open("/proc/stat", "r") as f:
                for line in f:
                    if line.startswith("cpu "):
                        parts = [int(x) for x in line.split()[1:]]
                        idle = parts[3] + (parts[4] if len(parts) > 4 else 0)
                        total = sum(parts)
                        return {"idle": idle, "total": total}
        except Exception:
            pass
        return {"idle": 0, "total": 0}

    def _read_net_bytes(self):
        rx, tx = 0, 0
        try:
            with open("/proc/net/dev", "r") as f:
                for line in f:
                    if ":" in line:
                        iface, data = line.split(":", 1)
                        iface = iface.strip()
                        if iface == "lo":
                            continue
                        cols = data.split()
                        rx += int(cols[0])
                        tx += int(cols[8])
        except Exception:
            pass
        return {"rx": rx, "tx": tx}

    def _read_temperature(self):
        sensor_paths = [
            "/sys/class/hwmon/hwmon5/temp1_input",
            "/sys/class/thermal/thermal_zone0/temp",
            "/sys/class/thermal/thermal_zone3/temp",
            "/sys/class/hwmon/hwmon1/temp1_input",
            "/sys/class/hwmon/hwmon4/temp1_input",
        ]
        for p in sensor_paths:
            if os.path.exists(p):
                try:
                    with open(p, "r") as f:
                        val = int(f.read().strip())
                        if val > 0:
                            return round(val / 1000.0, 1)
                except Exception:
                    pass
        return None

    def sample(self):
        with self.lock:
            now = time.time()
            # Throttle samples to at most once per 0.5s to avoid duplicate expensive calls
            if self.cached_metrics and (now - self.last_sample_time < 0.5):
                return self.cached_metrics

            # CPU calculation
            curr_cpu = self._read_cpu_stat()
            diff_total = curr_cpu["total"] - self.last_cpu_stat["total"]
            diff_idle = curr_cpu["idle"] - self.last_cpu_stat["idle"]
            if diff_total > 0:
                cpu_pct = round((1.0 - (diff_idle / diff_total)) * 100.0, 1)
            else:
                cpu_pct = 0.0
            self.last_cpu_stat = curr_cpu
            self.last_cpu_time = now

            # Network rate calculation
            curr_net = self._read_net_bytes()
            net_dt = (now - self.last_net_time) if self.last_net_time else 1.0
            rx_rate = max(0, int((curr_net["rx"] - self.last_net_bytes["rx"]) / net_dt)) if self.last_net_time else 0
            tx_rate = max(0, int((curr_net["tx"] - self.last_net_bytes["tx"]) / net_dt)) if self.last_net_time else 0
            self.last_net_bytes = curr_net
            self.last_net_time = now

            # Memory information
            mem = {}
            try:
                with open("/proc/meminfo", "r") as f:
                    for line in f:
                        parts = line.split(":")
                        if len(parts) == 2:
                            k = parts[0].strip()
                            v = parts[1].strip().split()[0]
                            mem[k] = int(v) * 1024
            except Exception:
                pass

            mem_total = mem.get("MemTotal", 1)
            mem_avail = mem.get("MemAvailable", 0)
            mem_used = max(0, mem_total - mem_avail)
            swap_total = mem.get("SwapTotal", 0)
            swap_free = mem.get("SwapFree", 0)
            swap_used = max(0, swap_total - swap_free)

            # Disk usage
            try:
                du = shutil.disk_usage("/")
                disk_info = {
                    "total": du.total,
                    "used": du.used,
                    "free": du.free,
                    "percent": round(du.used / du.total * 100.0, 1)
                }
            except Exception:
                disk_info = {"total": 0, "used": 0, "free": 0, "percent": 0.0}

            # Temperature
            temp = self._read_temperature()

            # Load averages
            loads = [0.0, 0.0, 0.0]
            try:
                with open("/proc/loadavg", "r") as f:
                    loads = [float(x) for x in f.read().split()[:3]]
            except Exception:
                pass

            # Uptime
            uptime_sec = 0
            try:
                with open("/proc/uptime", "r") as f:
                    uptime_sec = int(float(f.read().split()[0]))
            except Exception:
                pass

            # Top processes by CPU
            procs = []
            try:
                out = subprocess.check_output(
                    ["ps", "-eo", "pid,comm,%cpu,%mem", "--sort=-%cpu"],
                    text=True,
                    timeout=1
                )
                lines = out.strip().split("\n")[1:6]
                for l in lines:
                    parts = l.split(None, 3)
                    if len(parts) >= 4:
                        procs.append({
                            "pid": parts[0],
                            "name": parts[1],
                            "cpu": float(parts[2]),
                            "mem": float(parts[3])
                        })
            except Exception:
                pass

            self.cached_metrics = {
                "cpu": {
                    "name": self.cpu_name,
                    "cores": self.cores,
                    "percent": cpu_pct,
                    "temp": temp,
                    "load": loads
                },
                "memory": {
                    "total": mem_total,
                    "used": mem_used,
                    "available": mem_avail,
                    "percent": round(mem_used / mem_total * 100.0, 1) if mem_total else 0.0,
                    "swap_total": swap_total,
                    "swap_used": swap_used,
                    "swap_percent": round(swap_used / swap_total * 100.0, 1) if swap_total else 0.0
                },
                "disk": disk_info,
                "network": {
                    "rx_rate": rx_rate,
                    "tx_rate": tx_rate
                },
                "uptime_seconds": uptime_sec,
                "top_processes": procs,
                "timestamp": int(now)
            }
            self.last_sample_time = now
            return self.cached_metrics

collector = MetricsCollector()

class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/api/system", "/api/system/"):
            data = collector.sample()
            body = json.dumps(data).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body)
        elif self.path in ("/health", "/api/system/health"):
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Silence access logs to keep systemd journal clean
        pass

def background_sampler():
    """Background thread to keep CPU counters fresh even if requests are sporadic."""
    while True:
        try:
            collector.sample()
        except Exception:
            pass
        time.sleep(2.0)

def main():
    # Warm up first sample
    collector._read_cpu_stat()
    collector._read_net_bytes()
    time.sleep(0.2)
    collector.sample()

    # Start background sampling thread
    t = threading.Thread(target=background_sampler, daemon=True)
    t.start()

    server = HTTPServer((HOST, PORT), MetricsHandler)
    print(f"Devbox metrics listening on http://{HOST}:{PORT}/api/system", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()

if __name__ == "__main__":
    main()
