#!/bin/bash
set -euo pipefail

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

BACKUP_ROOT="/srv/backups"
LOG="/var/log/backup.log"
DATE=$(date +%F-%H%M%S)

SSH_KEY="/home/ali-admin/.ssh/id_ed25519"
SSH_OPTS="ssh -i $SSH_KEY -o BatchMode=yes"

SERVERS=(
  "srv-id-01"
  "srv-app-01"
  "srv-edge-01"
)

PATHS_TO_BACKUP=(
  "/etc"
  "/home"
  "/srv"
)

echo "[$(date '+%F %T')] Backup started" >> "$LOG"

for SERVER in "${SERVERS[@]}"; do
  echo "[$(date '+%F %T')] Starting backup for $SERVER" >> "$LOG"

  SERVER_BACKUP_DIR="$BACKUP_ROOT/$SERVER"
  SNAPSHOT_DIR="$SERVER_BACKUP_DIR/$DATE"
  CURRENT_LINK="$SERVER_BACKUP_DIR/current"

  mkdir -p "$SNAPSHOT_DIR"

  for SRC in "${PATHS_TO_BACKUP[@]}"; do
    echo "[$(date '+%F %T')] Backing up $SERVER:$SRC" >> "$LOG"

    DEST="$SNAPSHOT_DIR$SRC"
    mkdir -p "$DEST"

    RSYNC_OPTS=(
      -aAX
      --numeric-ids
      --delete
      --rsync-path="sudo rsync"
      --exclude=/proc/*
      --exclude=/sys/*
      --exclude=/dev/*
      --exclude=/tmp/*
      --exclude=/run/*
    )

    if [ -d "$CURRENT_LINK$SRC" ]; then
      RSYNC_OPTS+=(--link-dest="$CURRENT_LINK$SRC")
    fi

    rsync "${RSYNC_OPTS[@]}" \
      -e "$SSH_OPTS" \
      "ali-admin@$SERVER:$SRC/" \
      "$DEST/" >> "$LOG" 2>&1
  done

  ln -sfn "$SNAPSHOT_DIR" "$CURRENT_LINK"

  echo "[$(date '+%F %T')] Backup completed for $SERVER" >> "$LOG"
done

echo "[$(date '+%F %T')] Backup completed successfully" >> "$LOG"