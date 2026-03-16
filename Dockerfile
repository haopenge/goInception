FROM golang:1.22.1 as builder
# MAINTAINER hanchuanchuan <chuanchuanhan@gmail.com>

ENV TZ=Asia/Shanghai
ENV LANG="en_US.UTF-8"

RUN apt-get update && apt-get install -y \
    ca-certificates wget \
    make \
    git \
    gcc \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64 \
&& chmod +x /usr/local/bin/dumb-init

RUN mkdir -p /etc/apk/keys \
&& wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub \
&& wget -q -O /glibc.apk https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.28-r0/glibc-2.28-r0.apk

RUN wget -q -O /tmp/pt-online-schema-change https://www.percona.com/get/pt-online-schema-change \
&& chmod +x /tmp/pt-online-schema-change

RUN wget -q -O /tmp/gh-ost.tar.gz https://github.com/github/gh-ost/releases/download/v1.1.0/gh-ost-binary-linux-20200828140552.tar.gz \
&& tar -zxvf /tmp/gh-ost.tar.gz -C /tmp/ \
&& rm /tmp/gh-ost.tar.gz

WORKDIR /go/src/github.com/hanchuanchuan/goInception
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 go build -o /goInception tidb-server/main.go

COPY config/config.toml.default /etc/config.toml

# Executable image
FROM alpine:3.18

COPY --from=builder /glibc.apk /glibc.apk
COPY --from=builder /etc/apk/keys/sgerrand.rsa.pub /etc/apk/keys/sgerrand.rsa.pub
COPY --from=builder /goInception /goInception
COPY --from=builder /etc/config.toml /etc/config.toml
COPY --from=builder /usr/local/bin/dumb-init /usr/local/bin/dumb-init

# COPY --from=builder /tmp/percona-toolkit.tar.gz /tmp/percona-toolkit.tar.gz
COPY --from=builder /tmp/pt-online-schema-change /usr/local/bin/pt-online-schema-change
COPY --from=builder /tmp/gh-ost /usr/local/bin/gh-ost
RUN chmod +x /usr/local/bin/pt-online-schema-change /usr/local/bin/gh-ost

WORKDIR /

EXPOSE 4000

ENV LANG="en_US.UTF-8"
ENV TZ=Asia/Shanghai

# ENV PERCONA_TOOLKIT_VERSION 3.0.4

# && wget -O /tmp/percona-toolkit.tar.gz https://www.percona.com/downloads/percona-toolkit/${PERCONA_TOOLKIT_VERSION}/source/tarball/percona-toolkit-${PERCONA_TOOLKIT_VERSION}.tar.gz \

#RUN set -x \
#  && apk add --no-cache perl perl-dbi perl-dbd-mysql perl-io-socket-ssl perl-term-readkey make tzdata \
#  && tar -xzvf /tmp/percona-toolkit.tar.gz -C /tmp \
#  && cd /tmp/percona-toolkit-${PERCONA_TOOLKIT_VERSION} \
#  && perl Makefile.PL \
#  && make \
#  && make test \
#  && make install \
#  && apk del make \
#  && rm -rf /var/cache/apk/* /tmp/percona-toolkit*


RUN set -x \
  && apk add --no-cache --force-overwrite perl perl-dbi perl-dbd-mysql perl-io-socket-ssl perl-term-readkey tzdata /glibc.apk \
  && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
  && apk fix --force-overwrite alpine-baselayout-data

ENTRYPOINT ["/usr/local/bin/dumb-init", "/goInception","--config=/etc/config.toml"]
