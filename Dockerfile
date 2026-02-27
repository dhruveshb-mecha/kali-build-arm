# ============================================================
# Kali Linux Custom Image Build Environment
# Base: Ubuntu 24.04 LTS (Noble)
# Compatible with ARM64 (Apple Silicon) and x86_64
# ============================================================
FROM ubuntu:24.04

# Avoid interactive prompts during package installs
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ── Update & base utilities ──────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core build tools
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    ninja-build \
    autoconf \
    automake \
    libtool \
    pkg-config \
    # Cross-compilation (ARM / ARM64 for dev boards)
    gcc-arm-linux-gnueabihf \
    g++-arm-linux-gnueabihf \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    binutils-arm-linux-gnueabihf \
    binutils-aarch64-linux-gnu \
    # Kali / Debian image build tools
    live-build \
    debootstrap \
    qemu-user-static \
    binfmt-support \
    # Disk / filesystem tools
    parted \
    fdisk \
    dosfstools \
    e2fsprogs \
    squashfs-tools \
    xorriso \
    grub-common \
    # Compression tools
    gzip \
    bzip2 \
    xz-utils \
    zstd \
    lz4 \
    # Source control & download tools
    git \
    git-lfs \
    wget \
    curl \
    rsync \
    # Scripting & utilities
    bash \
    zsh \
    python3 \
    python3-pip \
    python3-venv \
    perl \
    ruby \
    # Text processing
    gawk \
    sed \
    grep \
    diffutils \
    patch \
    # Networking tools (useful for testing build deps)
    net-tools \
    iputils-ping \
    dnsutils \
    # Dev libs commonly needed by build deps
    libssl-dev \
    libffi-dev \
    zlib1g-dev \
    liblzma-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libglib2.0-dev \
    libpixman-1-dev \
    # Misc
    sudo \
    locales \
    ca-certificates \
    gnupg \
    lsb-release \
    apt-utils \
    apt-transport-https \
    software-properties-common \
    kpartx \
    u-boot-tools \
    device-tree-compiler \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── Locale setup ─────────────────────────────────────────────
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# ── QEMU static binaries for cross-arch chroot / debootstrap ─
# Already installed via qemu-user-static; register binfmt handlers
RUN update-binfmts --enable

# ── Convenience: a non-root build user (optional) ────────────
RUN useradd -m -s /bin/bash builder \
    && echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ── Working directory ─────────────────────────────────────────
WORKDIR /build

# ── Default shell ─────────────────────────────────────────────
CMD ["/bin/bash"]
