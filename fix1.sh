#!/bin/bash

echo "[+] Desativando serviço iwd..."
sudo systemctl stop iwd.service
sudo systemctl disable iwd.service

echo "[+] Criando override para impedir que iwd inicie..."
sudo mkdir -p /etc/systemd/system/iwd.service.d

sudo tee /etc/systemd/system/iwd.service.d/disable-iwd.conf > /dev/null <<EOF
[Service]
ExecStart=
EOF

echo "[+] Recarregando systemd..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

echo "[+] Ativando NetworkManager..."
sudo systemctl enable NetworkManager.service
sudo systemctl start NetworkManager.service

echo "[✔] Conflito resolvido!"
echo "ℹ Agora você pode usar 'nmcli' ou a interface gráfica de rede normalmente."
