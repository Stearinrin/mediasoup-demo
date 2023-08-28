FROM jrottenberg/ffmpeg:4.4-nvidia AS stage-one

# Install DEB dependencies and others.
RUN \
	set -x \
	&& apt-get update \
	&& apt-get install -y net-tools build-essential python3 python3-pip \
	iproute2 iperf iperf3 telnet httpie jq

WORKDIR /broadcasters
COPY ./broadcasters/ .

ENTRYPOINT [ "tail", "-f", "/dev/null"]
