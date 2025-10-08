#!/bin/bash

sudo tcpdump -i en0 -nn -tttt -G 600 -W 48 \
  -w /volume1/captures/capture-%Y-%m-%d_%H-%M-%S.pcap \
  '(host 1.1.1.1 or host 8.8.8.8) and (tcp[tcpflags] & (tcp-rst|tcp-fin) != 0 or icmp or arp)' &

sudo tcpdump -i en0 -n '(host 1.1.1.1 or host 8.8.8.8) and (tcp[tcpflags] & (tcp-rst|tcp-fin) != 0)'
