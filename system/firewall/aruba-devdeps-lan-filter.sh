#!/bin/sh
set -eu
SUBNET="${SUBNET:-192.168.0.0/24}"
DEVBOX_IP="${DEVBOX_IP:-192.168.0.172}"
LAN_IFACE="${LAN_IFACE:-wlp3s0}"
CHAIN=ARUBA-DEVDEPS-LAN
TCP_PORTS="5432 6380 8080 9080 8124 9002 9092 9094 3005 15432 20128 8096 8081 6881"
UDP_PORTS="6881 7359"
iptables -N "$CHAIN" 2>/dev/null || true
iptables -F "$CHAIN"
iptables -C DOCKER-USER -j "$CHAIN" 2>/dev/null || iptables -I DOCKER-USER 1 -j "$CHAIN"
for port in $TCP_PORTS; do
  iptables -A "$CHAIN" -i "$LAN_IFACE" -s "$SUBNET" -p tcp -m conntrack --ctstate DNAT --ctorigdst "$DEVBOX_IP" --ctorigdstport "$port" -j ACCEPT
  iptables -A "$CHAIN" -i "$LAN_IFACE" -p tcp -m conntrack --ctstate DNAT --ctorigdst "$DEVBOX_IP" --ctorigdstport "$port" -j DROP
done
for port in $UDP_PORTS; do
  iptables -A "$CHAIN" -i "$LAN_IFACE" -s "$SUBNET" -p udp -m conntrack --ctstate DNAT --ctorigdst "$DEVBOX_IP" --ctorigdstport "$port" -j ACCEPT
  iptables -A "$CHAIN" -i "$LAN_IFACE" -p udp -m conntrack --ctstate DNAT --ctorigdst "$DEVBOX_IP" --ctorigdstport "$port" -j DROP
done
iptables -A "$CHAIN" -j RETURN
