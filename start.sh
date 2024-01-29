#!/usr/bin/env bash
export PALSRV_BASE="/srv/palworld/"
export PALSRV_STEAMCMD_DIR="$PALSRV_BASE/steam"
export PALSRV_STEAMAPP_DIR="$PALSRV_BASE/steam/steamapps/common/PalServer"
export PALSRV_SAVED_DIR="$PALSRV_STEAMAPP_DIR/Pal/Saved"
export PALSRV_BACKUP_DIR="$PALSRV_BASE/backup"

case "$1" in
    server)
        cd "$PALSRV_STEAMAPP_DIR"
        ./PalServer.sh --port 8211 --players 32 -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS
    	;;
    backup)
        cd "$PALSRV_BASE"
        python3 -u backup.py
	;;
esac
