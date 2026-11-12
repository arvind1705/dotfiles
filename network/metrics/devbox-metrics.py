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
import socket
import subprocess
import threading
import urllib.error
import urllib.request
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
        self.smoothed_temp = None
        self.last_http_check = 0
        self.cached_http_services = {}
        self.media_transition = None
        self.media_transition_lock = threading.Lock()

    def _is_media_active(self):
        try:
            res = subprocess.run(
                ["systemctl", "is-active", "stack@media-server"],
                capture_output=True,
                text=True,
                timeout=1.5
            )
            if res.stdout.strip() == "active":
                return True
        except Exception:
            pass
        try:
            res = subprocess.run(
                ["docker", "ps", "--filter", "name=jellyfin", "--filter", "name=qbittorrent", "--format", "{{.Names}}"],
                capture_output=True,
                text=True,
                timeout=1.5
            )
            names = res.stdout.strip().split()
            if "jellyfin" in names or "qbittorrent" in names:
                return True
        except Exception:
            pass
        return False

    def get_media_status(self):
        with self.media_transition_lock:
            if self.media_transition:
                state, t0 = self.media_transition
                if time.time() - t0 < 40:
                    is_active = self._is_media_active()
                    if state == "starting" and is_active:
                        self.media_transition = None
                        return "running"
                    elif state == "stopping" and not is_active:
                        self.media_transition = None
                        return "stopped"
                    return state
                else:
                    self.media_transition = None

        return "running" if self._is_media_active() else "stopped"

    def get_media_profile_info(self):
        status = self.get_media_status()
        jellyfin_up = bool(self.cached_http_services.get("jellyfin", {}).get("online", False))
        qbittorrent_up = bool(self.cached_http_services.get("qbittorrent", {}).get("online", False))
        return {
            "name": "media",
            "title": "Media Server",
            "status": status,
            "enabled_on_boot": False,
            "services": {
                "jellyfin": jellyfin_up,
                "qbittorrent": qbittorrent_up
            }
        }

    def trigger_media_action(self, action):
        if action not in ("start", "stop"):
            return False, "Invalid action. Use start or stop."

        current = self.get_media_status()
        if action == "start" and current in ("running", "starting"):
            return True, current
        if action == "stop" and current in ("stopped", "stopping"):
            return True, current

        target_trans = "starting" if action == "start" else "stopping"
        with self.media_transition_lock:
            self.media_transition = (target_trans, time.time())

        def _worker():
            try:
                cmd = ["sudo", "-n", "systemctl", action, "stack@media-server"]
                subprocess.run(cmd, capture_output=True, timeout=120)
            except Exception:
                pass
            finally:
                time.sleep(1.0)
                try:
                    self.sample(force_health=True)
                except Exception:
                    pass
                with self.media_transition_lock:
                    self.media_transition = None

        t = threading.Thread(target=_worker, daemon=True)
        t.start()
        return True, target_trans

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

    def _check_tcp(self, ip, port, timeout=0.3):
        try:
            with socket.create_connection((ip, port), timeout=timeout):
                return True
        except Exception:
            return False

    def _check_http(self, path, timeout=0.8):
        started = time.monotonic()
        try:
            req = urllib.request.Request(f"http://127.0.0.1{path}", headers={"Host": "devbox.local"})
            with urllib.request.urlopen(req, timeout=timeout) as response:
                online = response.status in (200, 204, 301, 302, 403)
        except urllib.error.HTTPError as exc:
            online = exc.code in (200, 204, 301, 302, 403)
        except Exception:
            online = False
        latency = max(1, round((time.monotonic() - started) * 1000))
        return {"online": online, "latency": latency, "kind": "http"}

    def _check_http_services(self):
        paths = {
            "jellyfin": "/api/health/jellyfin",
            "qbittorrent": "/api/health/qbittorrent",
            "langfuse": "/api/health/langfuse",
            "9router": "/api/health/9router",
            "minio-console": "/api/health/minio-console",
            "minio-s3": "/api/health/minio",
            "clickhouse-http": "/api/health/clickhouse",
            "dgraph-http": "/api/health/dgraph",
            "cube": "/api/health/cube",
            "t3": "/api/health/t3",
        }
        return {name: self._check_http(path) for name, path in paths.items()}

    def _read_temperature(self):
        """Find coretemp Package id 0 temperature, or fallback to CPU thermal zones."""
        # 1. Check hwmon coretemp / k10temp
        for hw in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
            try:
                name_file = f"{hw}/name"
                if os.path.exists(name_file):
                    with open(name_file) as fn:
                        name = fn.read().strip()
                    if "coretemp" in name or "k10temp" in name:
                        # Look for Package id 0 sensor first
                        for tf in sorted(glob.glob(f"{hw}/temp*_input")):
                            lbl_file = tf.replace("_input", "_label")
                            lbl = ""
                            if os.path.exists(lbl_file):
                                try:
                                    with open(lbl_file) as fl:
                                        lbl = fl.read().strip()
                                except Exception:
                                    pass
                            if "Package" in lbl:
                                with open(tf) as fv:
                                    return round(int(fv.read().strip()) / 1000.0, 1)

                        # If no Package label found, take the highest core temperature
                        core_temps = []
                        for tf in sorted(glob.glob(f"{hw}/temp*_input")):
                            try:
                                with open(tf) as fv:
                                    val = int(fv.read().strip())
                                    if val > 0:
                                        core_temps.append(val)
                            except Exception:
                                pass
                        if core_temps:
                            return round(max(core_temps) / 1000.0, 1)
            except Exception:
                continue

        # 2. Fallback to CPU-specific thermal zones (x86_pkg_temp, coretemp, acpitz)
        for priority_types in [("x86_pkg_temp", "coretemp"), ("cpu-thermal", "soc_thermal", "acpitz")]:
            for tz in sorted(glob.glob("/sys/class/thermal/thermal_zone*")):
                try:
                    type_file = f"{tz}/type"
                    if os.path.exists(type_file):
                        with open(type_file) as ft:
                            tz_type = ft.read().strip()
                        if any(pt in tz_type for pt in priority_types):
                            temp_file = f"{tz}/temp"
                            if os.path.exists(temp_file):
                                with open(temp_file) as fv:
                                    val = int(fv.read().strip())
                                    if val > 0:
                                        return round(val / 1000.0, 1)
                except Exception:
                    continue
        return None

    def sample(self, force_health=False):
        with self.lock:
            now = time.time()
            if self.cached_metrics and not force_health and (now - self.last_sample_time < 0.5):
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

            # Temperature (with EMA smoothing to prevent raw DTS sensor jitter)
            raw_temp = self._read_temperature()
            if raw_temp is not None:
                if self.smoothed_temp is None:
                    self.smoothed_temp = raw_temp
                else:
                    self.smoothed_temp = round(self.smoothed_temp * 0.7 + raw_temp * 0.3, 1)
            temp = self.smoothed_temp

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
                    timeout=3
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

            # Direct TCP health checks for non-HTTP backend ports
            lan_ip = "192.168.0.172"
            tcp_services = {
                "postgres": self._check_tcp(lan_ip, 5432),
                "redis": self._check_tcp(lan_ip, 6380),
                "clickhouse-native": self._check_tcp(lan_ip, 9002),
                "dgraph-grpc": self._check_tcp(lan_ip, 9080)
            }
            if force_health or (now - self.last_http_check >= 10):
                self.cached_http_services = self._check_http_services()
                self.last_http_check = now
            service_status = {
                name: {"online": online, "latency": 0, "kind": "tcp"}
                for name, online in tcp_services.items()
            }
            service_status.update(self.cached_http_services)

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
                "tcp_services": tcp_services,
                "service_status": service_status,
                "media_profile": self.get_media_profile_info(),
                "timestamp": int(now)
            }
            self.last_sample_time = now
            return self.cached_metrics

collector = MetricsCollector()

class MetricsHandler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Cache-Control")

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        request_path = self.path.split("?", 1)[0]
        if request_path in ("/api/system", "/api/system/"):
            force_health = "refresh=1" in self.path
            data = collector.sample(force_health=force_health)
            body = json.dumps(data).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(body)
        elif request_path in ("/api/system/media", "/api/system/profile/media"):
            action = None
            if "?" in self.path:
                query = self.path.split("?", 1)[1]
                for part in query.split("&"):
                    if part.startswith("action="):
                        action = part.split("=", 1)[1]
            if action in ("start", "stop"):
                ok, state = collector.trigger_media_action(action)
                payload = {"ok": ok, "action": action, "status": state, "media_profile": collector.get_media_profile_info()}
            else:
                payload = {"ok": True, "media_profile": collector.get_media_profile_info()}
            body = json.dumps(payload).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(body)
        elif self.path in ("/health", "/api/system/health"):
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        request_path = self.path.split("?", 1)[0]
        if request_path in ("/api/system/media", "/api/system/profile/media"):
            content_length = int(self.headers.get("Content-Length", 0))
            action = None
            if content_length > 0:
                try:
                    raw_body = self.rfile.read(content_length)
                    data = json.loads(raw_body.decode("utf-8"))
                    action = data.get("action")
                except Exception:
                    pass
            if not action and "?" in self.path:
                query = self.path.split("?", 1)[1]
                for part in query.split("&"):
                    if part.startswith("action="):
                        action = part.split("=", 1)[1]
            if action in ("start", "stop"):
                ok, state = collector.trigger_media_action(action)
                payload = {"ok": ok, "action": action, "status": state, "media_profile": collector.get_media_profile_info()}
                body = json.dumps(payload).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self._send_cors_headers()
                self.end_headers()
                self.wfile.write(body)
            else:
                self.send_response(400)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self._send_cors_headers()
                self.end_headers()
                self.wfile.write(b'{"error": "Invalid action. Use start or stop."}')
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
