# golang parameters
ARG GO_VERSION=1.15.8

FROM golang:${GO_VERSION}-buster AS osx-cross-base

# OS-X SDK parameters
ARG OSX_SDK=MacOSX10.15.sdk
ARG OSX_SDK_SUM=4051d210bf232ccb5eee863d6a4052afa800001810a2a42e354c9637ec78cd2c

# osxcross parameters
ARG OSX_VERSION_MIN=10.12
ARG OSX_CROSS_COMMIT=2733413b6847c1489d6230f062d3293e6f42a021

ENV OSX_CROSS_PATH=/osxcross

ARG DEBIAN_FRONTEND=noninteractive
# Install deps
RUN set -x; echo "Starting image build for Debian Stretch" \
 && dpkg --add-architecture i386                       \
 && apt-get update                                     \
 && apt-get install -y -q                              \
        autoconf                                       \
        automake                                       \
        autotools-dev                                  \
        bc                                             \
        binfmt-support                                 \
        binutils-multiarch                             \
        binutils-multiarch-dev                         \
        build-essential                                \
        clang                                          \
        curl                                           \
        devscripts                                     \
        gdb                                            \
        git-core                                       \
        libtool                                        \
        llvm                                           \
        mercurial                                      \
        multistrap                                     \
        patch                                          \
        software-properties-common                     \
        subversion                                     \
        wget                                           \
        xz-utils                                       \
        cmake                                          \
        qemu-user-static                               \
        libxml2-dev                                    \
        lzma-dev                                       \
        openssl                                        \
        mingw-w64                                      \
        libssl-dev                                  && \
				apt -y autoremove && \
    		apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# FIXME: install gcc-multilib
# FIXME: add mips and powerpc architectures

FROM osx-cross-base AS osx-cross
ARG OSX_CROSS_COMMIT
WORKDIR "${OSX_CROSS_PATH}"
# install osxcross:
RUN git clone https://github.com/tpoechtrager/osxcross.git . \
 && git checkout -q "${OSX_CROSS_COMMIT}" \
 && rm -rf ./.git
COPY ${OSX_SDK}.tar.xz "${OSX_CROSS_PATH}/tarballs/${OSX_SDK}.tar.xz"
RUN echo "${OSX_SDK_SUM}"  "${OSX_CROSS_PATH}/tarballs/${OSX_SDK}.tar.xz" | sha256sum -c -
ARG OSX_VERSION_MIN
RUN UNATTENDED=yes OSX_VERSION_MIN=${OSX_VERSION_MIN} ./build.sh

FROM osx-cross-base AS final
LABEL maintainer="Yevgeny Pats<info+github@cloudquery.io>"
ARG DEBIAN_FRONTEND=noninteractive

COPY --from=osx-cross "${OSX_CROSS_PATH}/." "${OSX_CROSS_PATH}/"
ENV PATH=${OSX_CROSS_PATH}/target/bin:$PATH


FROM final

COPY entrypoint.sh /

# Copy generic compiler wrappers
COPY gencc.sh /usr/bin/gencc.sh
COPY gencpp.sh /usr/bin/gencpp.sh

# install goreleaser
ARG GORELEASER_VERSION=0.155.0
ARG GORELEASER_SHA=2a33aa15933cfd5bd2b714860c4876fa76f1fab8f46a7c6d29a8e32c7f9445f2
RUN  \
	GORELEASER_DOWNLOAD_FILE=goreleaser_Linux_x86_64.tar.gz && \
	GORELEASER_DOWNLOAD_URL=https://github.com/goreleaser/goreleaser/releases/download/v${GORELEASER_VERSION}/${GORELEASER_DOWNLOAD_FILE} && \
	wget ${GORELEASER_DOWNLOAD_URL}; \
			echo "$GORELEASER_SHA $GORELEASER_DOWNLOAD_FILE" | sha256sum -c - || exit 1; \
			tar -xzf $GORELEASER_DOWNLOAD_FILE -C /usr/bin/ goreleaser; \
			rm $GORELEASER_DOWNLOAD_FILE;

# install git-chglog
ARG GIT_CHGLOG_VERSION=0.10.0
RUN \
	GIT_CHGLOG_DOWNLOAD_FILE=git-chglog_linux_amd64.tar.gz && \
	GIT_CHGLOG_DOWNLOAD_URL=https://github.com/git-chglog/git-chglog/releases/download/v${GIT_CHGLOG_VERSION}/git-chglog_${GIT_CHGLOG_VERSION}_linux_amd64.tar.gz &&\
	wget -O ${GIT_CHGLOG_DOWNLOAD_FILE} ${GIT_CHGLOG_DOWNLOAD_URL}; \
	tar -xzf $GIT_CHGLOG_DOWNLOAD_FILE -C /usr/bin/ git-chglog; \
	rm $GIT_CHGLOG_DOWNLOAD_FILE && \
	chmod +x /entrypoint.sh

ENTRYPOINT ["bash", "/entrypoint.sh"]

