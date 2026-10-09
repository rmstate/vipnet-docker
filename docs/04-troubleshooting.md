# Troubleshooting

Use the checks below to narrow down whether a problem is with the client, the tunnel, routing, or the return path.

## 1. Check container and client state

```bash
sudo docker ps
sudo docker exec CONTAINER_NAME vipnetclient info
sudo docker exec CONTAINER_NAME ip -br addr
sudo docker exec CONTAINER_NAME ip route
```

Replace `CONTAINER_NAME` with the actual container name.

If the client is running but the VPN is not connected, confirm that the intended configuration and key material were imported successfully and that the client reports a connected state. Do not treat a running process as proof of connectivity.

## 2. `Operation not permitted` during mount operations

In the original lab, the client failed to remount an internal directory and logged `Operation not permitted`. In a diagnostic run, adding `CAP_SYS_ADMIN` allowed the initial `ramfs` mount to succeed.

`CAP_SYS_ADMIN` is a broad capability. This is an observation from one configuration, not a universal requirement. Confirm the exact operation and required permissions before changing container capabilities; do not make `--privileged` the default fix.

## 3. Tunnel is present, but there is no response

Check the route to the target on both the host and inside the container:

```bash
ip route get TARGET_IP
sudo docker exec CONTAINER_NAME ip route get TARGET_IP
```

Then inspect packets on the relevant interfaces. Confirm whether the request leaves through the tunnel and whether a response returns. Also check IP forwarding, firewall rules, NAT, and the remote network's return route.

If a SYN leaves but no SYN-ACK returns, the failure may be at the destination or elsewhere along the path.

## 4. Collect diagnostic information

Run the bundled diagnostic script from the repository root:

```bash
bash scripts/diagnose.sh
```

The script collects system information, Docker status, host interfaces and routes, forwarding settings, and information from known ViPNet container names. Some commands may require Docker permissions.

Review the output before sharing it. Remove internal IP addresses, hostnames, usernames, and other environment-specific details as needed. Never share DST files, private keys, or configuration files containing secrets.
