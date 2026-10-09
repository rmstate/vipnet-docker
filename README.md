# ViPNet Client 5 — Docker Networking Lab

A Docker-based ViPNet Client 5 networking lab for Arch Linux and Omarchy.

Run ViPNet Client 5 in a container and route selected traffic through the VPN tunnel using Linux networking, packet forwarding, and NAT.

## Features

- **Containerized VPN client** — run ViPNet Client 5 in Docker.
- **VPN routing** — route selected traffic through the VPN tunnel.
- **IP forwarding** — forward packets between network interfaces.
- **NAT** — configure source NAT for routed traffic.
- **Network diagnostics** — inspect interfaces, routing tables, forwarding, and connectivity.
- **Arch Linux / Omarchy** — developed and tested on an Arch-based environment.

## Architecture

The container runs ViPNet Client 5 and establishes the VPN tunnel. Host and container networking rules control how selected traffic reaches remote networks through that tunnel.

## Project structure

| File or directory | Purpose |
|---|---|
| `Dockerfile` | Container image definition |
| `scripts/route.sh` | Routing and network configuration |
| `scripts/diagnose.sh` | Network diagnostics |
| `docs/` | Installation, configuration, routing, and troubleshooting guides |

## Documentation

1. [Installation](docs/01-installation.md)
2. [Keys and startup](docs/02-keys-and-startup.md)
3. [Routing and connectivity](docs/03-routing-and-connectivity.md)
4. [Troubleshooting](docs/04-troubleshooting.md)

## Requirements

- Arch Linux or Omarchy
- Docker Engine and Docker Compose
- ViPNet Client 5 installation package
- Valid ViPNet configuration and key material

## Getting started

Clone the repository:

```bash
git clone https://github.com/rmstate/vipnet-docker.git
cd vipnet-docker
```

Follow the [installation guide](docs/01-installation.md) to prepare the client package, configure the environment, and start the container.

## Scope

This project demonstrates containerized VPN networking, Linux routing, packet forwarding, and NAT in a lab environment.

Actual connectivity depends on the ViPNet configuration, host networking, firewall rules, and the destination network.
