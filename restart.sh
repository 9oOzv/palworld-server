#!/usr/bin/env bash

source="$1/./"
target="/srv/palworld/Saved/./"

systemctl --user restart palsrv
