# Installation

This guide prepares the local ViPNet Client 5 files and builds the container image.

## Requirements

- Arch Linux or Omarchy with Docker Engine available.
- `dpkg-deb` for extracting the Debian package. On Arch, install a compatible package/tooling that provides it if it is not already available.
- A ViPNet Client for Linux x86-64 package you are authorized to use.
- The configuration and key material issued for your test environment.

The original lab used `vipnetclient_gost_amd64_5.0.0-7877.deb` (version `5.0.0-7877`). Other releases may have different dependencies or behavior.

## Obtain the client package

Obtain the package from the official [Infotecs website](https://infotecs.ru/) or your organization's authorized software distribution channel. Do not use untrusted file-sharing sites.

In the examples below, the downloaded package is located at:

```text
~/Downloads/vipnetclient_gost_amd64_5.0.0-7877.deb
```

If your filename or location differs, update the commands accordingly.

Inspect the package metadata:

```bash
file ~/Downloads/vipnetclient_gost_amd64_5.0.0-7877.deb
dpkg-deb --info ~/Downloads/vipnetclient_gost_amd64_5.0.0-7877.deb
```

## Prepare the local package files

Run these commands from the repository root:

```bash
cd ~/Projects/vipnet-docker-lab
mkdir -p local/package
dpkg-deb -x ~/Downloads/vipnetclient_gost_amd64_5.0.0-7877.deb local/package/
find local/package -maxdepth 3 -type d | sort | head -80
```

The Dockerfile copies the extracted package contents from `local/package/` into the image; it does not install the `.deb` inside the image.

`local/package/` contains proprietary vendor files and is excluded from Git by `.gitignore`. Keep the original package, extracted files, keys, and configuration out of public repositories and public container registries.

## Build the image

```bash
cd ~/Projects/vipnet-docker-lab
sudo docker build -t vipnet5-lab:test .
sudo docker image inspect vipnet5-lab:test --format '{{.Id}}'
```

The image build confirms that Docker can assemble the image; it does not confirm that the VPN is connected or that routing works. Continue with [Keys and startup](02-keys-and-startup.md).
