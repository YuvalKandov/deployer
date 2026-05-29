#!/bin/bash
# --- EC2 boot script (cloud-init user-data) ---
# Runs ONCE, as root, on the instance's first boot — before any human logs in.
# Goal: leave the box with Docker + the Compose plugin installed and the
# 'ubuntu' user able to run docker without sudo. Phase 3's CI/CD deploy step
# then just SSHes in and runs `docker compose up`.
#
# Output of this script lands in /var/log/cloud-init-output.log on the box —
# that's where you go to debug a boot that didn't install things correctly.

set -euxo pipefail
# -e  exit on any command failure   -u  error on unset variables
# -x  print each command (so the log shows exactly what ran)
# -o pipefail  a failure anywhere in a pipe fails the whole pipe

# 1. Refresh package lists and install Docker's prerequisites.
apt-get update -y
apt-get install -y ca-certificates curl gnupg

# 2. Add Docker's official APT repository + signing key. We install from
#    Docker's repo (not Ubuntu's older 'docker.io' package) to get the
#    current engine plus the `docker compose` v2 plugin.
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

# 3. Install the engine, CLI, containerd, and the Compose v2 plugin.
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 4. Let the 'ubuntu' user run docker without sudo (group membership applies
#    on its next login / SSH session).
usermod -aG docker ubuntu

# 5. Make sure Docker starts now and on every future reboot.
systemctl enable --now docker

echo "cloud-init: Docker bootstrap complete."
