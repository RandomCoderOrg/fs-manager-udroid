# [Choice] Ubuntu version (use hirsuite or bionic on local arm64/Apple Silicon): hirsute, focal, bionic
ARG VARIANT=jammy
FROM mcr.microsoft.com/vscode/devcontainers/base:${VARIANT}

ENV DEVCONTAINER true

# [Optional] Uncomment this section to install additional OS packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install tar fonts-firacode
