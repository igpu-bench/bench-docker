#!/usr/bin/env bash

case $1 in
  bash|sh|shell)
    exec $@
  ;;

  *)
    ibench $@
  ;;
esac
