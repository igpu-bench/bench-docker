#!/usr/bin/env bash


echo "DEBUG: docker-entrypoint.sh ran with arguments $*"


case $1 in

  run-all|all)
    echo "TODO"
    ;;

  get-samples|samples|download)
    echo "TODO: only download the sample files"
    ;;

  update|upgrade|install)
    echo "TODO: install a specific version of the benchmark"
    ;;

  *)
    echo "Unknown command \"$1\". attempting to execute"
    exec $@
    ;;
esac
