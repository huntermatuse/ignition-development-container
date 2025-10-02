ARG IGNITION_VERSION="8.3.0"
FROM inductiveautomation/ignition:${IGNITION_VERSION:-latest}
USER root
# Install required dependencies
RUN apt-get update && apt-get install -y sqlite3 unzip zip openssl vim-common jq file && rm -rf /var/lib/apt/lists/*
ENV WORKING_DIRECTORY=${WORKING_DIRECTORY:-/workdir}
ENV ACCEPT_IGNITION_EULA="Y"
ENV GATEWAY_ADMIN_USERNAME=${GATEWAY_ADMIN_USERNAME:-admin}
ENV GATEWAY_ADMIN_PASSWORD=${GATEWAY_ADMIN_PASSWORD:-password}
ENV IGNITION_EDITION=${IGNITION_EDITION:-standard}
ENV GATEWAY_MODULES_ENABLED=${GATEWAY_MODULES_ENABLED:-com.inductiveautomation.alarm-notification,com.inductiveautomation.opcua.drivers.ablegacy,com.inductiveautomation.opcua.drivers.logix,com.inductiveautomation.opcua,com.inductiveautomation.perspective,com.inductiveautomation.reporting,com.inductiveautomation.historian,com.inductiveautomation.webdev}
ENV IGNITION_UID=${IGNITION_UID:-1000}
ENV IGNITION_GID=${IGNITION_GID:-1000}
ENV DEVELOPER_MODE=${DEVELOPER_MODE:-N}
ENV GATEWAY_PUBLIC_ADDRESS=${GATEWAY_PUBLIC_ADDRESS:-localhost}
ENV GATEWAY_PUBLIC_HTTP_PORT=${GATEWAY_PUBLIC_HTTP_PORT:-8088}
ENV GATEWAY_PUBLIC_HTTPS_PORT=${GATEWAY_PUBLIC_HTTPS_PORT:-8043}
ENV DISABLE_QUICKSTART=${DISABLE_QUICKSTART:-true}
# Symlink options
ENV SYMLINK_PROJECTS=${SYMLINK_PROJECTS:-true}
ENV SYMLINK_THEMES=${SYMLINK_THEMES:-true}
ENV SYMLINK_IGNITION_FOLDERS=${SYMLINK_IGNITION_FOLDERS:-images,tag-definition,tag-group,tag-provider,tag-type-definition}
ENV ADDITIONAL_DATA_FOLDERS=${ADDITIONAL_DATA_FOLDERS:-}
# Copy scripts
COPY --chmod=0755 ./entrypoint-shim.sh /usr/local/bin/
ENTRYPOINT [ "entrypoint-shim.sh" ]