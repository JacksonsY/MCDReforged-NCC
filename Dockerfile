# ----------------------------------
# Pterodactyl Core Dockerfile
# Environment: Java
# Minimum Panel Version: 0.6.0
# ----------------------------------
    ARG BASE_IMAGE_TAG=3.11
    FROM python:${BASE_IMAGE_TAG}
        
    ARG MCDR_VERSION_REQUIREMENT=latest
    ARG PYPI_INDEX=https://pypi.org/simple
    ARG JAVA=21
    
    MAINTAINER Pterodactyl Software, <support@pterodactyl.io>
    
    USER container
    ENV  USER=container HOME=/home/container
    
    RUN <<EOT
    set -eux
    export PIP_ROOT_USER_ACTION=ignore
    python3 -m pip install -U pip
    if [ "$MCDR_VERSION_REQUIREMENT" = "latest" ]; then
      pip3 install mcdreforged
    else
      pip3 install "mcdreforged==${MCDR_VERSION_REQUIREMENT}" -i "$PYPI_INDEX" --extra-index-url https://pypi.org/simple
    fi
    pip3 cache purge && rm -rf ~/.cache/
    EOT
    
    RUN <<EOT
    set -eux
    mkdir -p "$(python3 -m site --user-site)"
    cat <<EOF > /etc/pip.conf
    [global]
    user = true
    EOF
    cat <<EOF >> ~/.bashrc
    
    # Add Python user bin to PATH
    export PATH="\$PATH:$(python3 -m site --user-base)/bin"
    EOF
    EOT
    
    # https://adoptium.net/installation/linux/
    RUN <<EOT
    set -eux
    export DEBIAN_FRONTEND="noninteractive"
    
    apt-get update
    apt-get install -y gnupg ca-certificates curl
    curl -so- https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /etc/apt/trusted.gpg.d/adoptium.gpg
    echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list
    apt-get update
    
    # The temurin source is currently very unstable, add more retries for it
    # https://github.com/adoptium/adoptium-support/issues/554
    # https://github.com/adoptium/installer/issues/766
    set +e
    wait_times="1 3 5 5 5 5 5 5 5"
    attempts=$(echo "$wait_times" | awk '{print NF}')  # 9 attempts
    for attempt in $(seq 1 $attempts); do
      if apt-get install -y "temurin-${JAVA}-jdk"; then
        break
      fi
      if [ "$attempt" != "$attempts" ]; then
        wait_time=$(echo "$wait_times" | cut -d ' ' -f $attempt)
        echo "Install attempt #$attempt failed. Waiting ${wait_time} minutes for another attempt..."
        sleep $((wait_time * 60))
      else
        echo "All $attempts attempts failed"
        exit 1
      fi
    done
    set -e
    
    java -version
    javac -version
    rm -rf /var/lib/apt/lists/*
    EOF
    EOT
    
    WORKDIR /home/container
    
    CMD ["python3", "-m", "mcdreforged", "start", "--auto-init"]