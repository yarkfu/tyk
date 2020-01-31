FROM golang:1.13
LABEL io.tyk.vendor="Tyk" \
  version="1.0" \
  description="Base image for CI tests"

RUN apt-get update \
  && apt-get dist-upgrade --assume-yes \
  && apt-get install --assume-yes --no-install-recommends \
  build-essential \
  ca-certificates \
  curl \
  git \
  jq \
  libluajit-5.1-2 \
  libluajit-5.1-dev \
  locales \
  luarocks \
  python3-dev \
  python3-pip \
  python3-setuptools \
  rpm \
  ruby-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN luarocks install lua-cjson
RUN pip3 install grpcio protobuf
RUN go get github.com/mitchellh/gox
RUN gem install fpm rake package_cloud

VOLUME [ "/go/src/github.com/TykTechnologies/tyk" ]

WORKDIR /go/src/github.com/TykTechnologies/tyk

ENV GO111MODULE=auto

COPY data/test.sh /test.sh
RUN chmod -c +x /test.sh

ENTRYPOINT [ "/test.sh" ]
