FROM golang:1.10

RUN apt update && \
    apt-get install -y autoconf automake pkg-config  libtool git && \
    apt-get install -y openssl libssl-dev sqlite libp11-kit-dev libcppunit-dev

RUN git clone https://github.com/opendnssec/SoftHSMv2.git /go/src/SoftHSMv2

WORKDIR /go/src/SoftHSMv2
RUN sh autogen.sh && ./configure --disable-gost
RUN make && make install

RUN go get -u github.com/golang/dep/cmd/dep
RUN go get github.com/ThalesIgnite/crypto11

WORKDIR /go/src/github.com/ThalesIgnite/crypto11
RUN dep ensure && go build

RUN echo '{\n    "Path": "/usr/local/lib/softhsm/libsofthsm2.so",' \ 
         > config && \
    echo '    "TokenLabel": "test",' >> config && \
    echo '    "Pin": "password"\n}'    >> config

RUN echo 'directories.tokendir = /var/lib/softhsm/tokens/' \
        > /etc/softhsm2.conf && \
    echo 'objectstore.backend = file' \
        >> /etc/softhsm2.conf && \
    echo 'log.level = INFO' \
        >> /etc/softhsm2.conf

RUN echo 'export SOFTHSM_CONF=/etc/softhsm2.conf' >> ~/.bashrc
RUN echo 'export SOFTHSM2_CONF=/etc/softhsm2.conf' >> ~/.bashrc

RUN export SOFTHSM2_CONF=/etc/softhsm2.conf && \
    softhsm2-util --init-token --slot 0 --label test --pin password --so-pin password

ADD example.go /go/src/example/example.go
WORKDIR /go/src/example

RUN go build

CMD go run example.go