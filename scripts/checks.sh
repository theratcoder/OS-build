#! /usr/bin/env bash
ROOTFS="$HOME/RatOS/build/rootfs"

readelf -a $ROOTFS/usr/bin/bash | grep NEEDED
readelf -a $ROOTFS/usr/bin/bash | grep interpreter

ls -l $ROOTFS/lib64/ld-linux-x86-64.so.2
ls -l $ROOTFS/lib64/libc.so.6
ls -l $ROOTFS/usr/lib/libtinfo.so.6