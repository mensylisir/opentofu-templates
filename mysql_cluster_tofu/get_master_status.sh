#!/bin/bash
set -e


MASTER_STATUS=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "${private_key_path}" "${ssh_user}@${master_ip}" "sudo mysql -u root -p'${mysql_root_password}' -e 'SHOW MASTER STATUS;'" 2>/dev/null)

LOG_FILE=$(echo "$MASTER_STATUS" | awk 'NR==2 {print $1}')
LOG_POS=$(echo "$MASTER_STATUS" | awk 'NR==2 {print $2}')

if [ -z "$LOG_FILE" ] || [ -z "$LOG_POS" ]; then
  echo "{\"error\":\"Failed to get master status\"}" >&2
  exit 1
fi

printf '{"log_file":"%s", "log_pos":"%s"}' "$LOG_FILE" "$LOG_POS"
