# Instalación y configuración básica de SSH

- `sudo apt update`: Actualiza la lista de paquetes disponibles en los repositorios del sistema.
- `sudo apt install openssh-server -y`: Instala el servidor OpenSSH para permitir conexiones remotas entrantes.
- `sudo systemctl status ssh`: Verifica el estado actual del servicio SSH (debe mostrarse como `active (running)`).
- `sudo systemctl enable --now ssh`: Inicia el servicio SSH inmediatamente y lo habilita para arrancar con el sistema.
- `sudo ufw allow ssh`: Abre el puerto 22 en el firewall UFW para permitir el tráfico SSH.
- `sudo ufw status`: Muestra el estado y las reglas del firewall UFW para confirmar que el acceso SSH esté en `ALLOW`.
- `ip a` o `hostname -I`: Muestra la dirección IP local del servidor.
- `ssh tu_usuario@ip_del_servidor`: Inicia una sesión remota por SSH hacia el servidor desde otro equipo.

