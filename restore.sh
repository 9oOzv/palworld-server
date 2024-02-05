#!/usr/bin/env bash

source="$1/./"
target="/srv/palworld/Saved/./"

systemctl --user stop palsrv
sleep 15
rsync -av --delete "$source" "$target"
sleep 1
systemctl --user start palsrv
