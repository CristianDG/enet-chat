#! /usr/bin/env sh

[[ -z $BUILD_DIR ]] && BUILD_DIR=src
[[ -z $OUT_FILE  ]] && OUT_FILE=bin/out

odin build $BUILD_DIR -out:$OUT_FILE $@
