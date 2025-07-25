#!/bin/bash

echo "[+] Parando e desativando NetworkManager..."
sudo systemctl stop NetworkManager.service
sudo systemctl disable NetworkManager.service

echo "[+] Removendo override que desativa o iwd..."
sudo rm -rf /etc/systemd/system/iwd.service.d

echo "[+] Recarregando systemd..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

echo "[+] Ativando iwd novamente..."
sudo systemctl enable iwd.service
sudo systemctl start iwd.service

echo "[✔] iwd restaurado com sucesso."
echo "ℹ Agora você pode usar o 'iwctl' normalmente."
