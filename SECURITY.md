# Security notes

## Never commit

Do not commit or publish:

- ViPNet DST files, keys, certificates, credentials or exported client state;
- proprietary ViPNet packages or extracted vendor files;
- backups, logs, packet captures or container filesystem exports that may contain internal data;
- `.env` files with secrets.

The `.gitignore` and `.dockerignore` files are defense-in-depth, not a substitute for reviewing files before committing, archiving or building an image. Git ignore rules do not automatically filter a manually created `tar` archive.

## Container privilege

This project manipulates routes and firewall rules and therefore may require elevated networking permissions in the relevant network namespace. Grant only the permissions required by the confirmed client workflow. Do not default to `--privileged` or add `CAP_SYS_ADMIN` without identifying the failing operation.

## Sharing diagnostics

Review output from `scripts/diagnose.sh`, `docker inspect`, client status commands and packet captures before sharing. These may reveal hostnames, internal IPs, client identifiers, network topology or other operational metadata.

## Incident response

If a key, credential or client-state backup may have been exposed, follow your organization's incident process and ask the ViPNet administrator whether revocation or re-issuance is needed. Removing the file from the latest commit does not remove it from earlier Git history or existing copies.

## Scope

This repository is a lab and documentation project. It does not replace the vendor's security guidance or an organization's change-control process.
