#!/usr/bin/env python3

import shutil
import os
import time
from pathlib import Path
import threading

terminate = False

def perform_backup(source_dir: Path, backup_dir: Path):
    backup_dir.mkdir(parents=True, exist_ok=True)
    timestamp = time.strftime("%Y-%m-%d_%H-%M-%S")
    backup_folder = backup_dir / f"backup_{timestamp}"
    shutil.copytree(source_dir, backup_folder)
    print(f"Backup created: {backup_folder}")

def manage_retention(backup_dir: Path, retention_seconds: int):
    retention_timestamp = time.time() - retention_seconds
    for backup_folder in backup_dir.iterdir():
        if backup_folder.is_dir():
            backup_time = backup_folder.stat().st_mtime
            if backup_time < retention_timestamp:
                shutil.rmtree(backup_folder)
                print(f"Deleted old backup: {backup_folder}")

def run(source_dir: Path, backup_dir: Path, interval_seconds: int, retention_seconds: int):
    next_backup = 0
    while not terminate:
        if time.time() >= next_backup:
            perform_backup(source_dir, backup_dir)
            manage_retention(backup_dir, retention_seconds)
            next_backup = time.time() + interval_seconds
        time.sleep(5)

if __name__ == "__main__":
    source_dir = Path(os.environ["PALSRV_SAVED_DIR"])
    backup_dir = Path(os.environ["PALSRV_BACKUP_DIR"])
    minute = 60
    hour = 60 * minute
    day = 24 * hour
    week = 7 * day
    year = 365 * day
    quarterly = threading.Thread(target=run, args=(source_dir, backup_dir / 'quarterly', 15 * minute, 8 * hour))
    hourly = threading.Thread(target=run, args=(source_dir, backup_dir / 'hourly', hour, 14 * day))
    daily = threading.Thread(target=run, args=(source_dir, backup_dir / 'daily', day, 4 * week))
    weekly = threading.Thread(target=run, args=(source_dir, backup_dir / 'weekly', week, year))
    quarterly.start()
    hourly.start()
    daily.start()
    weekly.start()
    try:
        hourly.join()
        daily.join()
        weekly.join()
    except KeyboardInterrupt:
        print("Backup process stopped by user.")
        terminate = True
