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
import glob
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
        self.last_cpu_stats = self._read_all_cpus()
        self.last_net_time = 0
        self.last_net_bytes = self._read_net_bytes()
        self.cpu_name = self._get_cpu_name()
        self.physical_cores, self.threads = self._detect_cores_and_threads()
        self.cached_metrics = None
        self.last_sample_time = 0

    def _get_cpu_name(self):
        try:
            with open("/proc/cpuinfo", "r") as f:
                for line in f:
                    if "model name" in line:
                        name = line.split(":", 1)[1].strip()
                        # Clean up common redundant strings if desired
                        return name
        except Exception:
            pass
        return "Intel Core Processor"

    def _detect_cores_and_threads(self):
        """Detect accurate physical cores vs logical threads (Hyper-Threading / SMT)."""
        physical_cores = set()
        threads = 0
        try:
            for p in sorted(glob.glob("/sys/devices/system/cpu/cpu[0-9]*")):
                threads += 1
                pkg, core = "0", "0"
                pkg_file = f"{p}/topology/physical_package_id"
                core_file = f"{p}/topology/core_id"
                if os.path.exists(pkg_file):
                    with open(pkg_file) as f:
                        pkg = f.read().strip()
                if os.path.exists(core_file):
                    with open(core_file) as f:
                        core = f.read().strip()
                physical_cores.add((pkg, core))
            return len(physical_cores) or 1, threads or 1
        except Exception:
            pass
        logical = os.cpu_count() or 1
        return max(1, logical // 2), logical

    def _read_all_cpus(self):
        """Read overall 'cpu' and per-thread 'cpu0', 'cpu1', ... from /proc/stat."""
        stats = {}
        try:
            with open("/proc/stat", "r") as f:
                for line in f:
                    if line.startswith("cpu"):
                        parts = line.split()
                        name = parts[0]
                        vals = [int(x) for x in parts[1:]]
                        idle = vals[3] + (vals[4] if len(vals) > 4 else 0)
                        total = sum(vals)
                        stats[name] = {"idle": idle, "total": total}
        except Exception:
            pass
        return stats

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
        """Find coretemp Package id 0 temperature, or fallback to thermal zone."""
        try:
            for hw in glob.glob("/sys/class/hwmon/hwmon*"):
                name_file = f"{hw}/name"
                if os.path.exists(name_file):
                    with open(name_file) as fn:
                        if "coretemp" in fn.read():
                            for tf in glob.glob(f"{hw}/temp*_input"):
                                lbl_file = tf.replace("_input", "_label")
                                lbl = ""
                                if os.path.exists(lbl_file):
                                    with open(lbl_file) as fl:
                                        lbl = fl.read().strip()
                                if "Package" in lbl:
                                    with open(tf) as fv:
                                        return round(int(fv.read().strip()) / 1000.0, 1)
                            # If no Package label found, use temp1
                            first_temp = f"{hw}/temp1_input"
                            if os.path.exists(first_temp):
                                with open(first_temp) as fv:
                                    return round(int(fv.read().strip()) / 1000.0, 1)
        except Exception:
            pass

        # Fallback paths
        sensor_paths = [
            "/sys/class/thermal/thermal_zone0/temp",
            "/sys/class/thermal/thermal_zone3/temp",
            "/sys/class/hwmon/hwmon1/temp1_input",
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
            if self.cached_metrics and (now - self.last_sample_time < 0.5):
                return self.cached_metrics

            # CPU calculations (overall & per-core)
            curr_cpus = self._read_all_cpus()
            per_cpu_pcts = {}
            for k, curr in curr_cpus.items():
                prev = self.last_cpu_stats.get(k)
                if prev:
                    dt = curr["total"] - prev["total"]
                    di = curr["idle"] - prev["idle"]
                    pct = round((1.0 - (di / dt)) * 100.0, 1) if dt > 0 else 0.0
                    per_cpu_pcts[k] = max(0.0, min(100.0, pct))
                else:
                    per_cpu_pcts[k] = 0.0

            overall_cpu = per_cpu_pcts.get("cpu", 0.0)
            per_core_list = [
                per_cpu_pcts[f"cpu{i}"]
                for i in range(self.threads)
                if f"cpu{i}" in per_cpu_pcts
            ]

            self.last_cpu_stats = curr_cpus
            self.last_cpu_time = now

            # Network rate calculation
            curr_net = self._read_net_bytes()
            net_dt = (now - self.last_net_time) if self.last_net_time else 1.0
            rx_rate = max(0, int((curr_net["rx"] - self.last_net_bytes["rx"]) / net_dt)) if self.last_net_time else 0
            tx_rate = max(0, int((curr_net["tx"] - self.last_net_bytes["tx"]) / net_dt)) if self.last_net_time else 0
            self.last_net_bytes = curr_net
            self.last_net_time = now

            # Memory information from /proc/meminfo
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

            # Disk usage via statvfs matching 'df -h'
            try:
                statv = os.statvfs("/")
                disk_total = statv.f_blocks * statv.f_frsize
                disk_free = statv.f_bavail * statv.f_frsize
                disk_used = (statv.f_blocks - statv.f_bfree) * statv.f_frsize
                disk_pct = round(disk_used / (disk_used + disk_free) * 100.0, 1) if (disk_used + disk_free) > 0 else 0.0
                disk_info = {
                    "total": disk_total,
                    "used": disk_used,
                    "free": disk_free,
                    "percent": disk_pct
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
                        raw_cpu = float(parts[2])
                        # Normalize total CPU by number of threads so 100% = full machine
                        total_cpu_pct = round(raw_cpu / self.threads, 1)
                        procs.append({
                            "pid": parts[0],
                            "name": parts[1],
                            "cpu": total_cpu_pct,
                            "raw_cpu": raw_cpu,
                            "mem": float(parts[3])
                        })
            except Exception:
                pass

            self.cached_metrics = {
                "cpu": {
                    "name": self.cpu_name,
                    "physical_cores": self.physical_cores,
                    "threads": self.threads,
                    "percent": overall_cpu,
                    "per_cpu": per_core_list,
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
        pass

def background_sampler():
    """Background thread to keep sampling fresh."""
    while True:
        try:
            collector.sample()
        except Exception:
            pass
        time.sleep(2.0)

def main():
    collector._read_all_cpus()
    collector._read_net_bytes()
    time.sleep(0.2)
    collector.sample()

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
