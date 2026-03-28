#!/bin/bash
export ERL_AFLAGS="-noshell"
export USER=holter
export HOME=/home/holter
mix deps.get
exec "$@"
