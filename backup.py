#!/usr/bin/env python3

import shutil
import os
import datetime
from pathlib import Path
import threading
import time
import json

terminate = False

def perform_backup(source_dir: Path, backup_dir: Path):
    backup_dir.mkdir(parents=True, exist_ok=True)
    now = datetime.datetime.now()
    backup_folder = backup_dir /  now.strftime("backup_%Y-%m-%d_%H-%M-%S")
    shutil.copytree(source_dir, backup_folder)
    print(json.dumps({
        "msg": "Backup created",
        "backup_folder": str(backup_folder)
    }))

def manage_retention(backup_dir: Path, retention: datetime.timedelta):
    now = datetime.datetime.now()
    for backup_folder in backup_dir.iterdir():
        if backup_folder.is_dir():
            backup_time = datetime.datetime.strptime(backup_folder.name, "backup_%Y-%m-%d_%H-%M-%S")
            if backup_time < now - retention:
                shutil.rmtree(backup_folder)
                print(json.dumps({
                    "msg": "Deleted old backup",
                    "backup_folder": str(backup_folder)
                }))

def run(source_dir: Path, backup_dir: Path, interval: datetime.timedelta, retention: datetime.timedelta, description: str):
    next_backup = datetime.datetime.min
    while not terminate:
        now = datetime.datetime.now()
        print(json.dumps({
            "description": description,
            "now": str(now),
            "interval": str(interval),
            "next_backup": str(next_backup)
        }))
        if now >= next_backup:
            perform_backup(source_dir, backup_dir)
            manage_retention(backup_dir, retention)
            next_backup = now + interval
        time.sleep(60)

if __name__ == "__main__":
    source_dir = Path(os.environ["PALSRV_SAVED_DIR"])
    backup_dir = Path(os.environ["PALSRV_BACKUP_DIR"])
    minute = datetime.timedelta(seconds=60)
    hour = 60 * minute
    day = 24 * hour
    week = 7 * day
    year = 365 * day
    quarterly = threading.Thread(target=run, args=(source_dir, backup_dir / '15min', 15 * minute, 8 * hour, "15min backup"))
    hourly = threading.Thread(target=run, args=(source_dir, backup_dir / 'hourly', hour, 14 * day, "hourly backup"))
    daily = threading.Thread(target=run, args=(source_dir, backup_dir / 'daily', day, 4 * week, "daily backup"))
    weekly = threading.Thread(target=run, args=(source_dir, backup_dir / 'weekly', week, year, "weekly backup"))
    quarterly.start()
    hourly.start()
    daily.start()
    weekly.start()
    try:
        hourly.join()
        daily.join()
        weekly.join()
    except KeyboardInterrupt:
        print(json.dumps({"msg": "Backup stopped by the user"}))
        terminate = True
