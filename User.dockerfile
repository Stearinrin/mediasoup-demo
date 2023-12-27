FROM ubuntu AS stage-one

# Install DEB dependencies and others.
RUN \
	set -x \
	&& apt-get update \
	&& apt-get install -y wget python3 python3-pip iperf3

# Install chrome browser
RUN \
	wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add \
	&& sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
	&& apt-get update \
	&& apt-get install -y google-chrome-stable	

# Install the webdriver
RUN \
	pip3 install selenium webdriver-manager

WORKDIR /scripts
COPY ./scripts/ .

CMD ["python3", "/scripts/producer.py"]
