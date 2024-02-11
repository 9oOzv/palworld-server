#!/usr/bin/env bash

set -euo pipefail

palsrv_steamapp_id="2394010"
steamworks_sdk_steamapp_id="1007"

palsrv_base_folder='/srv/palworld/palsrv'
run_sh="$palsrv_base_folder/run.sh"

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

all_services=(
    "$palsrv_service"
    "$palsrv_controlpanel_service"
    "$palsrv_backup_service"
    "$palsrv_monitor_service"
)

systemd_unit_folder="$HOME/.config/systemd/user"

palsrv_stop() {
    printf 'Stopping service `%s`...\n' "$palsrv_service"
    systemctl --user stop "$palsrv_service"
}

palsrv_start() {
    printf 'Starting service `%s`...\n' "$palsrv_service"
    systemctl --user start "$palsrv_service"
}

palsrv_restart() {
    printf 'Restarting service `%s`...\n' "$palsrv_service"
    systemctl --user restart "$palsrv_service"
}

palsrv_steam_update() {
    printf 'Updating steam apps...\n'
    systemctl --user restart "$palsrv_service"
    cd "$steamcmd_folder"
    "$steamcmd_sh" +login anonymous +app_update "$steamworks_sdk_steamapp_id" +quit
    "$steamcmd_sh" +login anonymous +app_update "$palsrv_steamapp_id" +quit
}

palsrv_server() {
    printf 'Running PalServer...\n'
    cd "$palsrv_steamapp_folder"
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
    printf 'Running palsrv-backup...\n'
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
    printf 'Restoring backup `%s`...\n' "$src"
    backups_folder="$(readlink -f "$palsrv_backup_folder")"
    target="$(readlink -f "$palsrv_saved_folder")"
    if [[ ! "$src" == "$backups_folder"* ]]; then
        printf '`%s` is not a subfolder of `%s`\n' "$src" "$backups_folder"
        exit 1
    fi
    systemctl --user stop palsrv
    sleep 10
    rsync -av --delete "$src/./" "$target/./"
    sleep 1
    systemctl --user start palsrv
}

palsrv_controlpanel() {
    printf 'Running palsrv-controlpanel...\n'
    cd "$palsrv_controlpanel_folder"
    npm install
    node index.js -b "$palsrv_backup_folder" -r "$run_sh"
}

try_stop_all() {
    printf 'Stopping services:\n'
    printf ' %s' "${all_services[@]}"
    printf '\n'
    systemctl --user stop "${all_services[@]}" || true
}

start_all() {
    printf 'Starting services:\n'
    printf ' %s' "${all_services[@]}"
    printf '\n'
    systemctl --user start "${all_services[@]}"
}

install_services() {
    printf 'Copying systemd service files `%s` -> `%s`\n' "$palsrv_services_folder" "$systemd_unit_folder"
    mkdir -p "$systemd_unit_folder"
    cp "$palsrv_services_folder/"*.service "$systemd_unit_folder"
    printf 'Reloading systemd daemon\n'
    systemctl --user daemon-reload
}

palsrv_deploy() {
    printf 'Deploying the palsrv components...\n'
    try_stop_all
    install_steamcmd
    install_palserver
    install_services
    start_all
}

palsrv_update() {
    printf 'Updating PalServer...\n'
    palsrv_stop
    palsrv_steam_update
    palsrv_start
}


printf 'Running palsrv `run.sh`\n'

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
