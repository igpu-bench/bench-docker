#!/usr/bin/env bash


function entrypoint_help {
  echo "Container wrapper help:"
  echo "  bash|sh                       Launches an interactive shell"
  echo "  *                             run all given text as an argument to ibench"
  printf "\n\n"
}

case $1 in

  bash|sh)
    exec $@
  ;;

  help|--help)
    entrypoint_help
    ibench --help
  ;;

  *)
    ibench $@
  ;;
esac
