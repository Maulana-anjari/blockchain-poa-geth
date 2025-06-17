#!/bin/sh
# wait-for-it.sh

set -e

host="$1"
shift
port="$1"
shift
cmd="$@"

until nc -z -v -w30 "$host" "$port"; do
  >&2 echo "Clef is unavailable - sleeping"
  sleep 1
done

>&2 echo "Clef is up - executing command"
exec $cmd