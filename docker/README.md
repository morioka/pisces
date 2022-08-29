# PISCES を docker コンテナで動かす。

## はじめに

何分にも古いコードで最近の環境ではビルドできないし、動かない。
たとえばWSL2/Ubuntu20.04ではビルドできない。

適切な環境を用意する必要がある。Ubuntu14.04/16.04/18.04ではビルドできるし、実行できる。

そこでDockerコンテナ環境を用意するが、コンテナ内で作成したファイルの権限の問題から、ローカルとコンテナ側のUIDとGIDを揃えたい。
下記の2つの方法のうち、手順の簡便さから前者の方法を採用する。

## 実行するだけなら

```
$ docker run -it  --rm -v $PWD:/pisces ubuntu:14.04 bash
# apt update
# apt install build-essential cmake gfortran libreadline-dev libncurses5-dev
```

コンテナ内ではデフォルトのroot権限で動作させればよい。


## ローカルとコンテナ側のUIDとGIDを揃える(1)

コンテナ側で作成したファイルの権限をlocal側に合わせたい。

- [ローカルとdockerコンテナ側のUID,GIDを揃える - やる気がストロングZERO](https://yaruki-strong-zero.hatenablog.jp/entry/docker_container_uid_gid)
- [Dockerでuid/gid指定可能かつsudo使用可能なデスクトップ環境を構築する(XRDP編) - Qiita](https://qiita.com/yama07/items/b905ceff0498e52b00cb)
- [docker run するときにUID,GIDを指定する - Qiita](https://qiita.com/manabuishiirb/items/83d675afbf6b4eea90e4)

```
docker run --rm -u `id -u`:`id -g` \
 -v $PWD:/work ubuntu:latest touch /work/uid1000gid1000.txt
```

Dockerfile
```docker
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
```

build.sh
```bash
docker build -t pisces .
```

run.sh
```bash
pushd ..
docker run --rm -it -u `id -u`:`id -g` -v $PWD:/pisces -w /pisces pisces
popd
```

## ローカルとコンテナ側のUIDとGIDを揃える(2)

下記の手順にそのまま倣った

- [Docker開発環境(2): コンテナのユーザーとホストのユーザーをマップする](https://zenn.dev/
https://zenn.dev/anyakichi/articles/73765814e57cba
  - コンテナ内でホストの自分の uid/gid でビルドができるようにする。
  - コンテナ内には当該 uid/gid を持つ正しいユーザーが存在する。
  - コンテナ内には予め用意されたホームディレクトリが存在する。
  - ホスト環境から不必要に多くのボリュームをマップしない（コンテナの独立性のため）。
- 上記手順ではユーザ権限の差し替えに setprivコマンドが必要。
  - setpriv が用意されているのはubuntu 18.04以降?
  - PISCESをビルドできるのはubuntu 18.04以前。
  - 結果、ubuntu 18.04のみで適用可能な方法。

Dockerfile
```docker
FROM ubuntu:18.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      build-essential \
      cmake \
      gfortran \
      libreadline-dev \
      libncurses5-dev \
      util-linux \
      setpriv \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /var/lib/apt/lists/*


RUN useradd -m builder && echo 'echo "hello, world"' >> /home/builder/.bashrc

COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
```

entorypoint.sh
```bash
#!/bin/bash

export USER=builder
export HOME=/home/$USER

# カレントディレクトリの uid と gid を調べる
uid=$(stat -c "%u" .)
gid=$(stat -c "%g" .)

if [ "$uid" -ne 0 ]; then
    if [ "$(id -g $USER)" -ne $gid ]; then
        # builder ユーザーの gid とカレントディレクトリの gid が異なる場合、
	# builder の gid をカレントディレクトリの gid に変更し、ホームディレクトリの
	# gid も正常化する。
        getent group $gid >/dev/null 2>&1 || groupmod -g $gid $USER
        chgrp -R $gid $HOME
    fi
    if [ "$(id -u $USER)" -ne $uid ]; then
        # builder ユーザーの uid とカレントディレクトリの uid が異なる場合、
	# builder の uid をカレントディレクトリの uid に変更する。
	# ホームディレクトリは usermod によって正常化される。
        usermod -u $uid $USER
    fi
fi

# このスクリプト自体は root で実行されているので、uid/gid 調整済みの builder ユーザー
# として指定されたコマンドを実行する。
exec setpriv --reuid=$USER --regid=$USER --init-groups "$@"
```

build.sh
```bash
docker build -t builder .
```

run.sh
```bash
docker run --rm -it -v $PWD:/build -w /build builder
```

以上
