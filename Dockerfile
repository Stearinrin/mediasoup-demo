FROM node:14 AS stage-one

# install brower
RUN \
	wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add \
	&& sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'

# Install DEB dependencies and others.
RUN \
	set -x \
	&& apt-get update \
	&& apt-get install -y net-tools build-essential python3 python3-pip iperf3 wget google-chrome-stable

# install mediasoup dependencies
RUN npm install -g gulp-cli eslint

# install webdriver
RUN \
	pip3 install selenium webdriver-manager

WORKDIR /server
COPY ./server/config.js .
COPY ./server/certs certs

WORKDIR /app

COPY ./app/package.json .
RUN npm install
COPY ./app/ .

CMD ["gulp", "devel"]
