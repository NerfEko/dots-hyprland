#!/usr/bin/env python3

import argparse
import ipaddress
import json
import socket
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor, as_completed


SSDP_ADDRESS = ("239.255.255.250", 1900)
SSDP_REQUEST = "\r\n".join([
    "M-SEARCH * HTTP/1.1",
    "HOST: 239.255.255.250:1900",
    'MAN: "ssdp:discover"',
    "MX: 2",
    "ST: roku:ecp",
    "",
    "",
]).encode()


def parse_ssdp_response(payload: bytes) -> dict[str, str]:
    headers: dict[str, str] = {}
    for line in payload.decode("utf-8", errors="ignore").split("\r\n")[1:]:
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        headers[key.strip().lower()] = value.strip()
    return headers


def fetch_device_info(host: str, timeout: float) -> dict | None:
    try:
        with urllib.request.urlopen(f"http://{host}:8060/query/device-info", timeout=timeout) as response:
            xml_bytes = response.read()
    except (urllib.error.URLError, TimeoutError, OSError):
        return None

    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError:
        return None

    def text(name: str, default: str = "") -> str:
        value = root.findtext(name)
        return value.strip() if value else default

    is_tv = text("is-tv").lower() == "true"
    supports_suspend = text("supports-suspend").lower() == "true"
    supports_find_remote = text("supports-find-remote").lower() == "true"
    supports_power = is_tv or supports_suspend or bool(text("power-mode"))

    name = (
        text("user-device-name")
        or text("friendly-device-name")
        or text("default-device-name")
        or text("model-name")
        or "Roku"
    )

    udn = text("udn")
    serial_number = text("serial-number")

    return {
        "id": udn or serial_number or host,
        "name": name,
        "host": host,
        "modelName": text("model-name"),
        "modelNumber": text("model-number"),
        "serialNumber": serial_number,
        "softwareVersion": text("software-version"),
        "vendorName": text("vendor-name"),
        "friendlyName": text("friendly-device-name"),
        "userDeviceName": text("user-device-name"),
        "powerMode": text("power-mode"),
        "ecpSettingMode": text("ecp-setting-mode"),
        "supportsFindRemote": supports_find_remote,
        "supportsPower": supports_power,
        "supportsVolume": is_tv,
        "isTv": is_tv,
        "available": True,
    }


def discover_ssdp(timeout: float) -> list[dict]:
    socket_timeout = max(0.5, timeout)
    deadline = time.monotonic() + timeout
    locations: dict[str, dict[str, str]] = {}

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP) as sock:
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
        sock.settimeout(min(socket_timeout, 1.0))
        sock.sendto(SSDP_REQUEST, SSDP_ADDRESS)

        while time.monotonic() < deadline:
            try:
                payload, _ = sock.recvfrom(65535)
            except socket.timeout:
                break

            headers = parse_ssdp_response(payload)
            location = headers.get("location")
            if not location:
                continue
            locations[location] = headers

    devices: list[dict] = []
    for location, headers in locations.items():
        parsed = urllib.parse.urlparse(location)
        host = parsed.hostname
        if not host:
            continue

        device = fetch_device_info(host, timeout=1.5)
        if not device:
            device = {
                "id": headers.get("usn") or host,
                "name": "Roku",
                "host": host,
                "modelName": "",
                "modelNumber": "",
                "serialNumber": "",
                "softwareVersion": "",
                "vendorName": "",
                "friendlyName": "",
                "userDeviceName": "",
                "powerMode": "",
                "ecpSettingMode": "",
                "supportsFindRemote": False,
                "supportsPower": False,
                "supportsVolume": False,
                "isTv": False,
                "available": True,
            }

        device["location"] = location
        devices.append(device)

    devices.sort(key=lambda item: (item["name"].lower(), item["host"]))
    return devices


def local_networks() -> list[ipaddress.IPv4Network]:
    try:
        result = subprocess.run(
            ["ip", "-4", "route", "show", "proto", "kernel", "scope", "link"],
            check=False,
            capture_output=True,
            text=True,
            timeout=2,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []

    networks: list[ipaddress.IPv4Network] = []
    for line in result.stdout.splitlines():
        parts = line.strip().split()
        if not parts:
            continue

        cidr = parts[0]
        try:
            network = ipaddress.ip_network(cidr, strict=False)
        except ValueError:
            continue

        if isinstance(network, ipaddress.IPv4Network):
            networks.append(network)

    return networks


def probe_ecp_host(host: str, timeout: float) -> dict | None:
    try:
        with socket.create_connection((host, 8060), timeout=timeout):
            pass
    except OSError:
        return None

    return fetch_device_info(host, timeout=max(timeout, 0.75))


def discover_unicast(timeout: float) -> list[dict]:
    devices_by_id: dict[str, dict] = {}
    candidate_hosts: set[str] = set()

    for network in local_networks():
        if network.prefixlen < 24:
            network = ipaddress.ip_network(f"{network.network_address}/24", strict=False)

        if network.num_addresses > 256:
            continue

        for host in network.hosts():
            candidate_hosts.add(str(host))

    if not candidate_hosts:
        return []

    connect_timeout = min(max(timeout / 4, 0.1), 0.35)

    with ThreadPoolExecutor(max_workers=64) as executor:
        futures = {
            executor.submit(probe_ecp_host, host, connect_timeout): host
            for host in sorted(candidate_hosts)
        }

        for future in as_completed(futures):
            device = future.result()
            if not device:
                continue
            devices_by_id[device["id"]] = device

    return sorted(devices_by_id.values(), key=lambda item: (item["name"].lower(), item["host"]))


def discover(timeout: float) -> list[dict]:
    devices_by_id: dict[str, dict] = {}

    for device in discover_ssdp(timeout):
        devices_by_id[device["id"]] = device

    if not devices_by_id:
        for device in discover_unicast(timeout):
            devices_by_id[device["id"]] = device

    return sorted(devices_by_id.values(), key=lambda item: (item["name"].lower(), item["host"]))


def main() -> None:
    parser = argparse.ArgumentParser(description="Discover Roku devices via SSDP.")
    parser.add_argument("--timeout", type=float, default=2.0)
    args = parser.parse_args()

    print(json.dumps(discover(max(0.5, args.timeout))))


if __name__ == "__main__":
    main()
