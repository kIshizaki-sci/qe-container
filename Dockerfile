FROM intel/oneapi-hpckit:2023.2.1-devel-ubuntu22.04

LABEL maintainer="Kohei ISHIZAKI <ishizaki@superstring.dev>"

ARG LIBXC_VERSION=7.0.0
ARG QE_VERSION=7.4.1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash

USER root

RUN if [ -d "/etc/apt/sources.list.d/" ]; then \
        FILE=$(grep -lR "apt.repos.intel.com" /etc/apt/sources.list.d/); \
        if [ ! -z "$FILE" ]; then \
            sed -i 's/^deb.*apt\.repos\.intel\.com/#&/' $FILE; \
        fi; \
    fi

RUN apt update && \
    apt upgrade -y --no-install-recommends \
    && apt install -y --install-recommends \
    curl \
    git \
    autoconf \
    automake \
    libtool \
    sudo \
    emacs \
    wget \
    build-essential \
    pkg-config \
    libfftw3-dev \
    libblas-dev \
    liblapack-dev; \
    apt install -y --install-recommends \
    cmake \
    ca-certificates ;\
    apt clean; \
    rm -rf /var/lib/apt/lists/*;

WORKDIR /root
RUN git clone --depth 1 https://gitlab.com/libxc/libxc.git -b ${LIBXC_VERSION} libxc-${LIBXC_VERSION} ;\
    mkdir libxc ;\
    cd libxc-${LIBXC_VERSION} ;\
    autoreconf -i . ;

WORKDIR /root/libxc-${LIBXC_VERSION}
RUN ./configure \
    CC=icc \
    CFLAGS="-O3 -parallel -fPIC -lm" \
    FC=ifort \
    FCFLAGS="-O3 -parallel -fPIC -lm" \
    --prefix=/root/libxc &&\
    make -j4 &&\
    make install;
ENV  LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/root/libxc/lib

WORKDIR /root
RUN git clone --depth=1 https://github.com/QEF/q-e.git -b qe-${QE_VERSION} espresso-src &&\
    mkdir espresso;
WORKDIR /root/espresso-src

RUN source /opt/intel/oneapi/setvars.sh --force && \
    ./configure \
    F90=ifort \
    F77=ifort \
    FC=ifort \
    CC=icc \
    CXX=icpc \
    FFLAGS="-O3 -assume byterecl -ip -g -qopenmp -xhost" \
    FCFLAGS="-O3 -assume byterecl -ip -g -qopenmp -xhost" \
    LDFLAGS="-qopenmp" \
    --enable-openmp --enable-parallel=no --with-scalapack=intel --with-libxc --with-libxc-prefix='/root/libxc' --prefix='/root/espresso' && \
    #make all gui gipaw &&\
    make all && \
    make install;

ENV PATH=$PATH:/root/espresso/bin
