#!/usr/bin/env bash
while true; do
    echo 'Checking for potential crash...'
    if journalctl -n 2 --user -u palsrv | grep 'Engine crash'; then
        echo 'Crash detected. Restarting palsrv service'
        systemctl --user restart palsrv
    fi
    sleep 60
done
