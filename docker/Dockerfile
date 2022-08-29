FROM ubuntu:14.04

#ARG USERNAME=app
#ARG GROUPNAME=app
#ARG UID=1000
#ARG GID=1000
#
#RUN groupadd -g $GID $GROUPNAME && \
#    useradd -m -s /bin/bash -u $UID -g $GID $USERNAME

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      build-essential \
      cmake \
      gfortran \
      libreadline-dev \
      libncurses5-dev \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /var/lib/apt/lists/*

#USER $USERNAME
#WORKDIR /home/$USERNAME/
