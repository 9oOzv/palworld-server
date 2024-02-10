#!/usr/bin/env bash

set -euo pipefail

palsrv_steamapp_id="2394010"
steamworks_sdk_steamapp_id="1007"

palsrv_base_folder='/srv/palworld'
steamcmd_folder="$palsrv_base_folder/steam"
palsrv_steamapp_folder="$steamcmd_folder/steamapps/common/PalServer"
palsrv_saved_folder="$palsrv_steamapp_folder/Pal/Saved"
palsrv_controlpanel_folder="$palsrv_base_folder/controlpanel"

palsrv_sh="$palsrv_steamapp_folder/PalServer.sh"
palsrv_restart_command="$palsrv_base_folder/restart.sh"
palsrv_update_command="$palsrv_base_folder/update.sh"
steamcmd_sh="$steamcmd_folder/steamcmd.sh"

palsrv_backup_folder="$palsrv_base_folder/backup"
palsrv_backup_py="$palsrv_base_folder/backup.py"
palsrv_backup_venv="$palsrv_base_folder/venv"
palsrv_backup_requirements="$palsrv_base_folder/requirements.txt"

palsrv_service='palsrv'
palsrv_backup_service='palsrv-backup'
palsrv_monitor_service='palsrv-monitor'
palsrv_controlpanel_service='palsrv-controlpanel'
palsrv_services_folder="$palsrv_base_folder/services"

systemd_unit_folder="$HOME/.config/systemd"

palsrv_stop() {
    systemctl --user stop "$palsrv_service"
}

palsrv_start() {
    systemctl --user start "$palsrv_service"
}

palsrv_restart() {
    systemctl --user restart "$palsrv_service"
}

palsrv_steam_update() {
    systemctl --user restart "$palsrv_service"
    cd "$steamcmd_folder"
    "$steamcmd_sh" +login anonymous +app_update "$steamworks_sdk_steamapp_id" +quit
    "$steamcmd_sh" +login anonymous +app_update "$palsrv_steamapp_id" +quit
}

palsrv_server() {
    cd "$palsrv_steamapp_sh"
    "$palsrv_sh" --port 8211 --players 32 -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS
}

install_steamcmd() {
    #TODO
    return
}

install_palserver() {
    #TODO
    return
}

palsrv_backup() {
    cd "$palsrv_base_folder"
    if [ ! -d "$palsrv_backup_venv" ]; then
        /usr/bin/env python3 -m venv "$palsrv_backup_venv"
    fi
    . "$palsrv_backup_venv/bin/activate"
    pip install -r "$palsrv_backup_requirements"
    python3 -u "$palsrv_backup_py" "$palsrv_saved_folder" "$palsrv_backup_folder"
}

palsrv_restore() {
    src="$(readlink -f "$1")"
    backups_folder="$(readlink -f "$palsrv_backup_folder")"
    target="$(readlink -f "$palsrv_saved_folder")"
    if [[ ! "$src" == "$backups_folder"* ]]; then
        printf '`%s` is not a subfolder of `%s`' "$src" "$backups_folder"
        exit 1
    fi
    systemctl --user stop palsrv
    sleep 10
    rsync -av --delete "$src/./" "$target/./"
    sleep 1
    systemctl --user start palsrv
}

palsrv_controlpanel() {
    cd "$palsrv_controlpanel_folder"
    npm install
    node index.js
}

try_stop_all() {
    systemctl --user stop "$palsrv_service" "$palsrv_controlpanel_service" "$palsrv_backup_service" "$palsrv_monitor_service" || true
}

start_all() {
    systemctl --user start "$palsrv_service" "$palsrv_controlpanel_service" "$palsrv_backup_service" "$palsrv_monitor_service"
}

copy_services() {
    mkdir -p "$systemd_unit_folder"
    cp "$palsrv_services_folder/"*.service "$systemd_unit_folder"
}

palsrv_deploy() {
    try_stop_all
    install_steamcmd
    install_palserver
    copy_services
    start_all
}

palsrv_update() {
    palsrv_stop
    palsrv_steam_update
    palsrv_start
}

case "$1" in
    server)
        palsrv_server
    	;;
    backup)
        palsrv_backup
        ;;
    restore)
        shift
        palsrv_restore "$@"
        ;;
    controlpanel)
        palsrv_controlpanel
        ;;
    update)
        palsrv_update
        ;;
    start)
        palsrv_start
        ;;
    stop)
        palsrv_stop
        ;;
    restart)
        palsrv_restart
        ;;
    deploy)
        palsrv_deploy
esac
