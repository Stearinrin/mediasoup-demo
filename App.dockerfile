FROM node:14 AS stage-one

# Install DEB dependencies and others.
RUN \
	set -x \
	&& apt-get update \
	&& apt-get install -y net-tools build-essential python3 python3-pip iperf3

# Install mediasoup dependencies
RUN npm install -g gulp-cli eslint

# Install the webdriver
RUN \
	pip3 install selenium webdriver-manager

WORKDIR /server
COPY ./server/config.js .
COPY ./server/certs certs

# Install the application
WORKDIR /app

COPY ./app/package.json .
RUN npm install
COPY ./app/ .

CMD ["gulp", "devel"]
