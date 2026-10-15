#!/usr/bin/env bash
# Jalankan SEKALI di dalam WSL (butuh sudo): bash scripts/wsl-ssh-setup.sh
# sshd hanya listen di 127.0.0.1:2222, login pakai kunci saja (tanpa password).
set -euo pipefail
sudo apt-get update && sudo apt-get install -y openssh-server
sudo tee /etc/ssh/sshd_config.d/inovasionline.conf >/dev/null <<'CONF'
Port 2222
ListenAddress 127.0.0.1
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers rio
CONF
sudo systemctl disable --now ssh.socket 2>/dev/null || true
sudo systemctl enable --now ssh
sudo systemctl restart ssh
systemctl is-active ssh && ss -ltn | grep 2222
