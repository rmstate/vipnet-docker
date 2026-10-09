# Keys and startup

This guide covers handling the DST file and checking the client after it has been started.

## Keep the DST file outside the repository

Use only key material issued for your test environment. For example, keep the file at `~/Downloads/client.dst`, outside the project directory.

Check that the file exists and is readable without printing its contents:

```bash
test -r "$HOME/Downloads/client.dst" && echo "DST file is readable"
```

Do not commit the DST file or include it in an image.

## Make the file available to a container

A read-only bind mount can expose the file to a container:

```bash
-v "$HOME/Downloads/client.dst:/run/secrets/client.dst:ro"
```

This mount only makes the file available; it does not import the key into ViPNet. The import procedure depends on the installed ViPNet Client version and its supported configuration workflow. Follow the documentation supplied with your client build rather than assuming that commands for ViPNet Client 4 also apply to version 5.

Do not add `COPY client.dst` to the Dockerfile. Avoid publishing images, container exports, or archives created after secrets have been added to a container: key material may remain in image layers or the container filesystem.

## Check client state

Once your container is running, replace `CONTAINER_NAME` with its actual name:

```bash
sudo docker ps
sudo docker exec CONTAINER_NAME vipnetclient info
sudo docker exec CONTAINER_NAME ip -br addr
sudo docker exec CONTAINER_NAME ip route
```

These commands show the container state, network interfaces, and routing table. A running process alone does not prove that the VPN is connected. Confirm the client status, the tunnel interface, and the expected routes before testing traffic.

Continue with [Routing and connectivity](03-routing-and-connectivity.md).
