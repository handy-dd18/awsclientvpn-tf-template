FROM hashicorp/terraform:1.11.2

# システムパッケージの更新とインストール
USER root
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    unzip \
    git \
    openssl \
    jq \
    vim \
    ca-certificates \
    sudo \
    py3-pip \
    aws-cli \
    easy-rsa \
    openvpn

# 非rootユーザーの作成
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN addgroup -g $USER_GID $USERNAME && \
    adduser -u $USER_UID -G $USERNAME -s /bin/bash -D $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

# Alpine特有のEasyRSAパスを確認
RUN EASYRSA_PATH=$(find /usr -name "easyrsa" -type f | head -1) && \
    if [ -n "$EASYRSA_PATH" ]; then \
    echo "Found EasyRSA at $EASYRSA_PATH"; \
    EASYRSA_DIR=$(dirname $EASYRSA_PATH); \
    mkdir -p /home/vscode/easy-rsa; \
    cp -r $EASYRSA_DIR/* /home/vscode/easy-rsa/; \
    else \
    echo "EasyRSA not found in standard locations, downloading..."; \
    mkdir -p /home/vscode/easy-rsa; \
    wget -qO- https://github.com/OpenVPN/easy-rsa/releases/download/v3.1.5/EasyRSA-3.1.5.tgz | tar xz -C /home/vscode/easy-rsa/ --strip-components=1; \
    fi && \
    chown -R vscode:vscode /home/vscode/easy-rsa && \
    chmod -R 755 /home/vscode/easy-rsa

# ヘルパーコマンドの作成
RUN echo '#!/bin/bash\necho "Checking for EasyRSA:"\nfind /usr -name "easyrsa" -type f\necho ""\necho "Checking for OpenSSL configs:"\nfind /usr -name "openssl-*.cnf"' > /usr/local/bin/check-easyrsa && \
    chmod +x /usr/local/bin/check-easyrsa

# デフォルトユーザーを設定
USER $USERNAME