#!/bin/bash

set -o errexit
set -o pipefail

QEMU_VERSION='2.7.0-resin-rc1-arm'
QEMU_SHA256='d36d9bf71d19191efe55b2ed238a7858c30608ddc50a1edb50acfc04466639c7'
QEMU_AARCH64_VERSION='2.7.0-resin-rc1-aarch64'
QEMU_AARCH64_SHA256='a631c80c087ed79483ad724e2e90dde4c8ff1b7a8bf06506c9f4f92287f39a21'

# Download QEMU
curl -SLO https://github.com/resin-io/qemu/releases/download/qemu-$QEMU_VERSION/qemu-$QEMU_VERSION.tar.gz \
	&& echo "$QEMU_SHA256  qemu-$QEMU_VERSION.tar.gz" | sha256sum -c - \
	&& tar -xz --strip-components=1 -f qemu-$QEMU_VERSION.tar.gz
curl -SLO https://github.com/resin-io/qemu/releases/download/qemu-$QEMU_AARCH64_VERSION/qemu-$QEMU_AARCH64_VERSION.tar.gz \
	&& echo "$QEMU_AARCH64_SHA256  qemu-$QEMU_AARCH64_VERSION.tar.gz" | sha256sum -c - \
	&& tar -xz --strip-components=1 -f qemu-$QEMU_AARCH64_VERSION.tar.gz
chmod +x qemu-arm-static qemu-aarch64-static

for arch in $ARCHS; do
	for suite in $SUITES; do

		case "$arch" in
		'armv7hf')
			label='io.resin.architecture="armv7hf" io.resin.qemu.version="'$QEMU_VERSION'"'
			qemu='COPY qemu-arm-static /usr/bin/'
			repo="resin/$arch-fedora"
			template='Dockerfile.armv7hf.tpl'
		;;
		'aarch64')

			if [ $suite == '23' ]; then
				continue
			fi

			label='io.resin.architecture="aarch64" io.resin.qemu.version="'$QEMU_AARCH64_VERSION'"'
			qemu='COPY qemu-aarch64-static /usr/bin/'
			repo="resin/$arch-fedora"
			template='Dockerfile.tpl'
		;;
		'amd64')
			label='io.resin.architecture="amd64"'
			qemu=''
			repo="fedora"
			template='Dockerfile.tpl'
		;;
		esac

		if [ $arch != 'amd64' ]; then
			rootfs_file="Fedora-Docker-Base-$suite.$arch.tar.xz"
			checksum=$(grep " $rootfs_file" SHASUMS256.txt)
			curl -SLO "http://resin-packages.s3.amazonaws.com/fedora/$suite/$rootfs_file"
			echo "$checksum" | sha256sum -c -
			rm -rf tmp
			mkdir tmp
			tar -xJvf $rootfs_file -C tmp --strip-components=1
			docker import tmp/layer.tar $repo:$suite
		fi

		sed -e s~#{FROM}~"$repo:$suite"~g \
			-e s~#{LABEL}~"$label"~g \
			-e s~#{QEMU}~"$qemu"~g "$template" > Dockerfile

		docker build -t resin/$arch-fedora:$suite .
		rm -rf "$rootfs_file"
	done
done

rm -rf qemu*
