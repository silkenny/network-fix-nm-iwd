#!/bin/bash
echo "[+] Desativando iwd..."
sudo systemctl stop iwd.service
sudo systemctl disable iwd.service

echo "[+] Evitando que o iwd seja ativado por engano..."
sudo mkdir -p /etc/systemd/system/iwd.service.d
echo -e "[Service]\nExecStart=\n" | sudo tee /etc/systemd/system/iwd.service.d/disable-iwd.conf > /dev/null

echo "[+] Garantindo que NetworkManager esteja ativo..."
sudo systemctl enable NetworkManager.service
sudo systemctl start NetworkManager.service

echo "[✔] Conflito resolvido! Use 'nmcli' ou a interface gráfica normalmente."
