ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
export PATH := ${ROOT_DIR}/node_modules/.bin:${PATH}

start:
	hubot -a discord -n Maxim --disable-httpd

dev:
	hubot -n Maxim --disable-httpd

help:
	hubot --help
