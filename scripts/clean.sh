#!/usr/bin/env bash
sudo rm -rf /mnt/rootfs
rm rootfs.img

sudo rm -rf $HOME/RatOS/build/rootfs/*
sudo rm -rf $HOME/RatOS/build/build/bash/*
sudo rm -rf $HOME/RatOS/build/build/glibc/*
sudo rm -rf $HOME/RatOS/build/build/kernel/*
sudo rm -rf $HOME/RatOS/build/build/ncurses/*