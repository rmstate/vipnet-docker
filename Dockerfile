FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       procps \
       iproute2 \
       iptables \
       ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY local/package/ /

RUN chmod 755 /usr/bin/vipnetclient \
    /var/lib/vipnet-core/ld-linux-x86-64.so.2

WORKDIR /root

CMD ["/usr/bin/vipnetclient", "--help"]
