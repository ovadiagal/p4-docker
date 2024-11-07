# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV P4_UTILS_BRANCH=master
ENV PROTOBUF_VER=3.20.3
ENV PROTOBUF_COMMIT=v${PROTOBUF_VER}
ENV GRPC_VER=1.44.0
ENV GRPC_COMMIT=tags/v${GRPC_VER}
ENV PI_COMMIT=6d0f3d6c08d595f65c7d96fd852d9e0c308a6f30
ENV BMV2_COMMIT=d064664b58b8919782a4c60a3b9dbe62a835ac74
ENV P4C_COMMIT=66eefdea4c00e3fbcc4723bd9c8a8164e7288724
ENV FRROUTING_COMMIT=frr-8.5
ENV BUILD_DIR=/root/p4-tools
ENV NUM_CORES=$(nproc)
ENV DEBUG_FLAGS=true
ENV P4_RUNTIME=true
ENV SYSREPO=false
ENV FRROUTING=true
ENV DOCUMENTATION=true

# Update and upgrade the system
RUN apt-get update && \
    apt-get -y -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" upgrade

# Install shared dependencies
RUN apt-get install -y --no-install-recommends \
    arping \
    autoconf \
    automake \
    bash-completion \
    bridge-utils \
    build-essential \
    ca-certificates \
    cmake \
    cpp \
    curl \
    emacs \
    gawk \
    git \
    git-review \
    g++ \
    htop \
    libboost-dev \
    libboost-filesystem-dev \
    libboost-program-options-dev \
    libboost-test-dev \
    libc6-dev \
    libevent-dev \
    libgc-dev \
    libgflags-dev \
    libgmpxx4ldbl \
    libgmp10 \
    libgmp-dev \
    libffi-dev \
    libtool \
    libpcap-dev \
    linux-headers-generic \
    make \
    nano \
    pkg-config \
    python3 \
    python3-dev \
    python3-pip \
    python3-setuptools \
    tmux \
    traceroute \
    vim \
    wget \
    xcscope-el \
    xterm \
    zip \
    unzip

# Upgrade pip3
RUN pip3 install --upgrade pip==21.3.1

# Set Python3 as the default binary
RUN ln -sf $(which python3) /usr/bin/python && \
    ln -sf $(which pip3) /usr/bin/pip

# Install shared Python dependencies
RUN pip3 install \
    cffi \
    ipaddress \
    ipdb \
    ipython \
    pypcap

# Install Wireshark and related tools
RUN apt-get install -y --no-install-recommends wireshark && \
    echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections && \
    dpkg-reconfigure wireshark-common && \
    apt-get install -y --no-install-recommends tcpdump tshark

# Install iperf3
RUN apt-get install -y --no-install-recommends iperf3

# Configure tmux
RUN wget -O /root/.tmux.conf https://raw.githubusercontent.com/nsg-ethz/p4-utils/${P4_UTILS_BRANCH}/install-tools/conf_files/tmux.conf

# Create build directory
RUN mkdir -p ${BUILD_DIR}

# Set working directory
WORKDIR ${BUILD_DIR}

# Uninstall Ubuntu python3-protobuf if present and install specific protobuf version
RUN apt-get purge -y python3-protobuf || echo "Failed removing protobuf" && \
    pip install protobuf==${PROTOBUF_VER}

# Install protobuf from source
RUN git clone https://github.com/protocolbuffers/protobuf protobuf && \
    cd protobuf && \
    git checkout ${PROTOBUF_COMMIT} && \
    git submodule update --init --recursive && \
    export CFLAGS="-Os" && \
    export CXXFLAGS="-Os" && \
    export LDFLAGS="-Wl,-s" && \
    ./autogen.sh && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    make clean && \
    unset CFLAGS CXXFLAGS LDFLAGS

# Install gRPC
RUN git clone https://github.com/grpc/grpc.git grpc && \
    cd grpc && \
    git checkout ${GRPC_COMMIT} && \
    git submodule update --init --recursive && \
    export LDFLAGS="-Wl,-s" && \
    mkdir -p cmake/build && \
    cd cmake/build && \
    cmake ../.. && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    unset LDFLAGS

# Install bmv2 dependencies
RUN apt-get install -y \
    git automake libtool build-essential \
    pkg-config libevent-dev libssl-dev \
    libffi-dev python3-dev python3-pip \
    libjudy-dev libgmp-dev \
    libpcap-dev \
    libboost-dev \
    libboost-program-options-dev \
    libboost-system-dev \
    libboost-filesystem-dev \
    libboost-thread-dev \
    libboost-test-dev \
    libboost-context-dev \
    libboost-coroutine-dev \
    libboost-chrono-dev \
    libboost-date-time-dev \
    libboost-atomic-dev \
    libboost-regex-dev \
    libboost-random-dev \
    libboost-math-dev \
    libboost-serialization-dev \
    libtool-bin \
    valgrind \
    libreadline-dev \
    g++ \
    wget \
    net-tools


ENV THRIFT_VER=0.13.0
ENV THRIFT_URL=https://archive.apache.org/dist/thrift/${THRIFT_VER}/thrift-${THRIFT_VER}.tar.gz

# Install Thrift 0.13.0
RUN cd ${BUILD_DIR} && \
    wget ${THRIFT_URL} && \
    tar xzf thrift-${THRIFT_VER}.tar.gz && \
    mv thrift-${THRIFT_VER} thrift && \
    rm thrift-${THRIFT_VER}.tar.gz && \
    cd thrift && \
    ./configure --disable-tutorial --disable-tests --without-qt4 --without-qt5 --without-c_glib && \
    make -j$(nproc) && \
    make install && \
    ldconfig
    
# Install PI dependencies
RUN apt-get install -y --no-install-recommends \
    libboost-system-dev \
    libboost-thread-dev \
    libjudy-dev \
    libreadline-dev \
    libtool-bin \
    valgrind

# Install PI
RUN cd ${BUILD_DIR} && \
    git clone https://github.com/p4lang/PI.git PI && \
    cd PI && \
    git checkout ${PI_COMMIT} && \
    git submodule update --init --recursive && \
    ./autogen.sh && \
    ./configure --prefix=/usr --with-proto --without-internal-rpc --without-cli --without-bmv2 "CXXFLAGS=-O0 -g" && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    make clean


RUN apt-get update && apt-get install -y libnanomsg-dev

# Install bmv2
RUN cd ${BUILD_DIR} && \
    git clone https://github.com/p4lang/behavioral-model.git bmv2 && \
    cd bmv2 && \
    git checkout ${BMV2_COMMIT} && \
    # Modify install_deps.sh to replace libgc1c2 with libgc-dev
    sed -i 's/libgc1c2/libgc-dev/g' install_deps.sh && \
    ./autogen.sh && \
    ./configure --with-pi --with-thrift --with-nanomsg --enable-debugger --disable-elogger "CXXFLAGS=-O0 -g" && \
    make -j$(nproc) && \
    make install && \
    ldconfig


# Install p4c dependencies
RUN apt-get install -y --no-install-recommends \
    bison \
    clang \
    flex \
    iptables \
    libboost-graph-dev \
    libboost-iostreams-dev \
    libelf-dev \
    libfl-dev \
    libgc-dev \
    llvm \
    net-tools \
    zlib1g-dev \
    lld \
    pkg-config \
    ccache \
    python3-setuptools

RUN pip install scapy==2.5.0 ply pyroute2

# Install p4c
RUN cd ${BUILD_DIR} && \
    git clone https://github.com/p4lang/p4c.git p4c && \
    cd p4c && \
    git checkout ${P4C_COMMIT} && \
    git submodule update --init --recursive && \
    mkdir -p build && \
    cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=DEBUG && \
    make -j2 && \
    make install && \
    ldconfig && \
    cd .. && \
    rm -rf build/

# Install ptf
RUN cd ${BUILD_DIR} && \
    git clone https://github.com/p4lang/ptf.git ptf && \
    cd ptf && \
    git pull origin main && \
    pip3 install .

RUN apt install sudo -y

# Install mininet without Python 2
RUN cd /root && \
    git clone https://github.com/mininet/mininet && \
    cd mininet && \
    git checkout 5b1b376336e1c6330308e64ba41baac6976b6874 && \
    wget -O mininet.patch https://raw.githubusercontent.com/nsg-ethz/p4-utils/${P4_UTILS_BRANCH}/install-tools/conf_files/mininet.patch && \
    patch -p1 < "mininet.patch" && \
    PYTHON=python3 ./util/install.sh -nwv

# Install FRRouting dependencies
RUN apt-get install -y \
    git autoconf automake libtool make libreadline-dev texinfo \
    pkg-config libpam0g-dev libjson-c-dev bison flex \
    libc-ares-dev python3-dev python3-sphinx \
    install-info build-essential libsnmp-dev perl \
    libcap-dev libelf-dev libunwind-dev

RUN apt-get install -y libpcre2-dev

# Install libyang
RUN cd ${BUILD_DIR} && \
    git clone https://github.com/CESNET/libyang.git libyang && \
    cd libyang && \
    git checkout v2.0.0 && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr -D CMAKE_BUILD_TYPE:String="Release" .. && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# Install additional dependencies for FRRouting
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        protobuf-compiler \
        libprotobuf-dev \
        libprotobuf-c-dev \
        libsystemd-dev \
        libreadline-dev \
        libncurses5-dev \
        libncursesw5-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install 
RUN apt-get update && \
    apt-get install -y --no-install-recommends libprotobuf-c-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install protobuf-c-compiler for protoc-c
RUN apt-get update && \
    apt-get install -y protobuf-c-compiler && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install FRRouting
RUN cd ${BUILD_DIR} && \
    git clone https://github.com/FRRouting/frr.git frr && \
    cd frr && \
    git checkout ${FRROUTING_COMMIT} && \
    ./bootstrap.sh && \
    ./configure --enable-fpm --enable-protobuf --enable-multipath=8 && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# Install p4-utils
RUN cd ${BUILD_DIR} && \
    git clone https://github.com/nsg-ethz/p4-utils.git p4-utils && \
    cd p4-utils && \
    git checkout ${P4_UTILS_BRANCH} && \
    ./install.sh

# Install p4-learning
RUN cd ${BUILD_DIR} && \
    git clone https://github.com/nsg-ethz/p4-learning.git p4-learning && \
    cd p4-learning && \
    git checkout ${P4_UTILS_BRANCH}

# Install Sphinx and ReadtheDocs theme
RUN apt-get install -y python3-sphinx && \
    pip3 install sphinx-rtd-theme

# Perform final cleanup
RUN ldconfig && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN pip install thrift


# Set default command
CMD ["/bin/bash"]
