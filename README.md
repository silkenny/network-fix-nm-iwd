# 🧩 network-fix-nm-iwd

Este projeto corrige o conflito comum entre `NetworkManager` e `iwd` (utilitário usado pelo `iwctl`) no Linux. Ideal para ambientes que utilizam Arch, Fedora, ou derivados.

## 🔧 O problema

Ambos `NetworkManager` e `iwd` tentam gerenciar o Wi-Fi. Isso causa:

- Interfaces invisíveis no `iwctl`
- `NetworkManager` não detecta redes Wi-Fi corretamente
- Conexões instáveis

## ✅ Solução

Este repositório fornece scripts para:

- Desabilitar `iwd` e forçar o uso do `NetworkManager`
- Restaurar o estado anterior se necessário

## 🚀 Como usar

### 1. Clone o repositório

```bash
git clone https://github.com/seunome/network-fix-nm-iwd.git
cd network-fix-nm-iwd

