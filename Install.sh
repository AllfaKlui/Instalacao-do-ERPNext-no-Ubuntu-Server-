#!/bin/bash

# --- 1. Instalação e Configuração do MariaDB ---
sudo apt update
sudo apt install -y mariadb-server mariadb-client

# Aplicando as configurações de otimização (InnoDB e Collation)
# Isso automatiza o que fizemos no arquivo /etc/mysql/mariadb.conf.d/50-server.cnf
cat <<EOF | sudo tee /etc/mysql/mariadb.conf.d/z_frappe_optimizations.cnf
[server]
innodb-check-optimize-metadata = ON
innodb-buffer-pool-size = 1G
innodb-log-buffer-size = 64M
innodb-file-format = Barracuda
innodb-file-per-table = 1
innodb-large-prefix = 1
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
EOF

sudo systemctl restart mariadb

# Configurando a senha do root do banco para 'root' (necessário para o bench)
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'root'; FLUSH PRIVILEGES;"

# --- 2. Dependências do Sistema e Bench ---
sudo apt install -y ansible nginx supervisor redis-server python3-pip python3-venv
sudo apt install python3-frappe-bench -y || sudo pip install frappe-bench --break-system-packages

# --- 3. Inicialização do Frappe Bench (Versão 15) ---
bench init frappe-bench --frappe-branch version-15 --skip-redis-config-generation
cd ~/frappe-bench

# --- 4. Criação do Site ---
# O --force garante que se o site existir, ele será recriado do zero
bench new-site seu-site.local --admin-password 'admin' --mariadb-root-password 'root' --force

# --- 5. Ativação do Modo Produção ---
sudo chmod o+x /home/$USER
sudo chmod -R o+rx ~/frappe-bench

# Configura Nginx e Supervisor
echo "y" | sudo bench setup production $USER
sudo ln -sf ~/frappe-bench/config/nginx.conf /etc/nginx/conf.d/frappe-bench.conf
sudo ln -sf ~/frappe-bench/config/supervisor.conf /etc/supervisor/conf.d/frappe-bench.conf

sudo supervisorctl reread
sudo supervisorctl update
sudo systemctl restart nginx

# --- 6. Relatório Final ---
IP_LOCAL=$(hostname -I | awk '{print $1}')
clear
echo "==========================================================="
echo "   AUTOMAÇÃO COMPLETA: FRAPPE + MARIADB + NGINX"
echo "==========================================================="
echo "Acesso Produção: http://$IP_LOCAL"
echo "Acesso Dev: http://$IP_LOCAL:8000"
echo "-----------------------------------------------------------"
sudo supervisorctl status
echo "==========================================================="