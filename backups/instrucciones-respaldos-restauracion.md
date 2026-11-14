# Guía paso a paso: respaldos, Cron, copia externa (SSH + rsync) y restauración

**Servidor Ubuntu:** `192.168.50.1` | **Linux Mint (copia externa):** `192.168.50.101`

> **Advertencia:** La restauración sobrescribe datos actuales. Haz pruebas destructivas (`docker compose down -v`) **solo en un entorno de pruebas**.

## 1. Preparación inicial (Ubuntu Server)

Requisitos: Docker funcionando, repositorio en `~/proyecto-eif431o`, contenedores levantados y SSH activo (`SSH/Instalar.md`).

Comprobar servicios y dar permisos a los scripts:

```bash
cd ~/proyecto-eif431o/docker
docker compose ps
```

*(Los servicios `bd` y `chamilo` deben estar en `healthy`).*

```bash
cd ~/proyecto-eif431o
chmod +x backups/respaldar.sh backups/respaldar-bd.sh backups/restaurar.sh backups/restaurar-archivos.sh
```

---

## 2. Crear y verificar el respaldo manual (Ubuntu Server)

Ejecutar **con tu usuario normal (sin `sudo`)**:

```bash
cd ~/proyecto-eif431o
./backups/respaldar.sh
ls -lh ~/respaldos/
tail -n 10 ~/respaldos/respaldo.log
```

*(Si solo necesitas una prueba rápida de base de datos en ~2 segundos, puedes usar `./backups/respaldar-bd.sh`).*

Deben aparecer dos archivos con la misma fecha/hora (`chamilo-bd-AAAA-MM-DD_HHMM.sql.gz` y `chamilo-archivos-AAAA-MM-DD_HHMM.tar.gz`) y líneas `OK BD` / `OK ARCHIVOS` en el log. `respaldar.sh` conserva los últimos 7 días en Ubuntu.

Validar integridad sustituyendo los nombres reales:

```bash
gzip -t ~/respaldos/NOMBRE-REAL-BD.sql.gz && echo "BD OK"
tar -tzf ~/respaldos/NOMBRE-REAL-ARCHIVOS.tar.gz > /dev/null && echo "ARCHIVOS OK"
```

---

## 3. Automatizar respaldos con Cron (Ubuntu Server)

Asegurar la zona horaria correcta en Ubuntu Server (por defecto viene en UTC y correría el `cron` 6 horas antes):

```bash
sudo timedatectl set-timezone America/Costa_Rica
sudo systemctl restart cron
timedatectl
```

Verificar `cron` y `flock`:

```bash
systemctl is-active cron
command -v flock
```

*(Si `cron` no está activo: `sudo apt update && sudo apt install -y cron && sudo systemctl enable --now cron`).*

Abrir el `crontab` de tu usuario:

```bash
crontab -e
```

**Prueba rápida (opcional, 1 minuto):** agrega esta línea, espera 2 minutos revisando `tail -f ~/respaldos/cron.log` y **luego bórrala o coméntala** para evitar respaldos simultáneos:

```cron
* * * * * $HOME/proyecto-eif431o/backups/respaldar.sh >> $HOME/respaldos/cron.log 2>&1
```

**Programación definitiva (todos los días a las 02:30):** deja únicamente esta línea (usa `flock` para evitar ejecuciones superpuestas):

```cron
30 2 * * * flock -n /tmp/respaldo.lock $HOME/proyecto-eif431o/backups/respaldar.sh >> $HOME/respaldos/cron.log 2>&1
```

Confirmar:

```bash
crontab -l
```

---

## 4. Copia externa con SSH y `rsync` (desde Linux Mint)

Linux Mint obtiene los respaldos desde Ubuntu Server con una clave SSH dedicada sin contraseña ni 2FA, así: si el servidor falla o es comprometido, las copias quedan a salvo fuera de él y `rsync` solo transfiere los cambios nuevos.

*(Si en Ubuntu Server corriste algún respaldo con `sudo`, pásalos antes a tu usuario normal: `sudo rsync -a /root/respaldos/ ~/respaldos/ && sudo chown -R "$USER": ~/respaldos`).*

En los comandos siguientes cambia `usuario_servidor` por tu usuario real en Ubuntu Server.

### 4.1 Instalar dependencias (si faltan)

En **Ubuntu Server**: `openssh-server` y `rsync` activos (`sudo apt install -y openssh-server rsync && sudo ufw allow ssh`).  
En **Linux Mint**:

```bash
sudo apt update && sudo apt install -y openssh-client rsync
```

### 4.2 Crear clave SSH dedicada en Linux Mint

En una terminal local de **Linux Mint** (presiona **Enter dos veces** cuando pida passphrase):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_respaldos -C "respaldos"
ls -l ~/.ssh/
```

### 4.3 Copiar la clave pública a Ubuntu Server y probar

Desde **Linux Mint**:

```bash
ssh-copy-id -i ~/.ssh/id_respaldos.pub usuario_servidor@192.168.50.1
```

*(Pide contraseña y código 2FA esta única vez; debe mostrar `Number of key(s) added: 1`).*

Probar conexión sin contraseña ni código:

```bash
ssh -i ~/.ssh/id_respaldos usuario_servidor@192.168.50.1 hostname
ssh -i ~/.ssh/id_respaldos usuario_servidor@192.168.50.1 "ls -lh ~/respaldos"
```

### 4.4 Traer los respaldos con `rsync`

En **Linux Mint**, ejecuta el `rsync` **dos veces** para comprobar que la segunda no vuelve a copiar lo existente:

```bash
mkdir -p ~/respaldos-losangeles
rsync -avz -e "ssh -i ~/.ssh/id_respaldos" usuario_servidor@192.168.50.1:respaldos/ ~/respaldos-losangeles/
ls -lh ~/respaldos-losangeles/
```

Repite:

```bash
rsync -avz -e "ssh -i ~/.ssh/id_respaldos" usuario_servidor@192.168.50.1:respaldos/ ~/respaldos-losangeles/
```

### 4.5 Programar descarga automática con `rsync` en Cron (Linux Mint)

En **Linux Mint**, verifica que `cron` esté activo (si no: `sudo apt update && sudo apt install -y cron && sudo systemctl enable --now cron`):

```bash
systemctl is-active cron
crontab -e
```

**Para pruebas rápidas (cada 1 minuto):**

```cron
* * * * * flock -n /tmp/rsync-mint.lock rsync -az -e "ssh -i $HOME/.ssh/id_respaldos" usuario_servidor@192.168.50.1:respaldos/ $HOME/respaldos-losangeles/ >> $HOME/respaldos-losangeles/rsync.log 2>&1
```

**Para producción (diario a las 02:45, 15 min después del respaldo de Ubuntu):**

```cron
45 2 * * * flock -n /tmp/rsync-mint.lock rsync -az -e "ssh -i $HOME/.ssh/id_respaldos" usuario_servidor@192.168.50.1:respaldos/ $HOME/respaldos-losangeles/ >> $HOME/respaldos-losangeles/rsync.log 2>&1
```

Confirmar y revisar registros en **Linux Mint**:

```bash
crontab -l
ls -lh ~/respaldos-losangeles/
cat ~/respaldos-losangeles/rsync.log
```

*(Nota: `flock -n` evita que se encimen dos `rsync` si uno tarda; sin `--delete`, Mint conserva el histórico completo aunque Ubuntu limpie archivos mayores a 7 días).*

---

## 5. Restauración completa (Ubuntu Server)

> **Si reconstruiste el servidor desde cero:** primero copia el par `.sql.gz` y `.tar.gz` desde **Linux Mint** al servidor:
> ```bash
> scp ~/respaldos-losangeles/NOMBRE-REAL-BD.sql.gz ~/respaldos-losangeles/NOMBRE-REAL-ARCHIVOS.tar.gz usuario_servidor@192.168.50.1:~/respaldos/
> ```

### 5.1 Levantar MariaDB y esperar estado `healthy`

```bash
cd ~/proyecto-eif431o/docker
docker compose up -d bd
docker compose ps
```

### 5.2 Restaurar base de datos y verificar tablas

```bash
cd ~/proyecto-eif431o
./backups/restaurar.sh ~/respaldos/NOMBRE-REAL-BD.sql.gz
```

Contar tablas en `chamilo` (se esperan ~239):

```bash
cd ~/proyecto-eif431o/docker
docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='\''chamilo'\'';"'
```

### 5.3 Restaurar archivos persistentes de Chamilo

Usa el `.tar.gz` **de la misma fecha/hora** que el `.sql.gz` (este script reinicia los servicios al terminar):

```bash
cd ~/proyecto-eif431o
./backups/restaurar-archivos.sh ~/respaldos/NOMBRE-REAL-ARCHIVOS.tar.gz
```

### 5.4 Comprobar Chamilo

```bash
cd ~/proyecto-eif431o/docker
docker compose ps
curl -I http://127.0.0.1:8081
```

Debe responder `HTTP/1.1 200 OK` (o `302`). Verifica en el navegador de Mint: `https://capacitacion.losangeles.internal`.

---

## 6. Prueba rápida de recuperación (solo en máquina de pruebas)

1. Crea el usuario `respaldo_a` en Chamilo y ejecuta `./backups/respaldar.sh`.
2. Crea el usuario `respaldo_b` después del respaldo.
3. Simula pérdida de datos: `cd ~/proyecto-eif431o/docker && docker compose down -v`.
4. Restaura el par generado en el paso 1 (sección 5).
5. Comprueba que `respaldo_a` existe y `respaldo_b` no:
   ```bash
   docker compose exec bd sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE" -e "SELECT id, username FROM user WHERE username IN ('\''respaldo_a'\'','\''respaldo_b'\'');"'
   ```

---

## 7. Problemas frecuentes

- **`bd` no lista:** espera a que `docker compose ps` muestre `healthy`.
- **`rsync` o `ssh` no conecta:** revisa `sudo systemctl status ssh` y `sudo ufw status` en `192.168.50.1`.
- **Error `Permissions are too open` en Mint:** ejecuta `chmod 600 ~/.ssh/id_respaldos`.
- **Faltan documentos al abrir Chamilo:** restauraste un `.tar.gz` de distinta fecha que el `.sql.gz`.
- **Chamilo no levanta:** revisa `cd ~/proyecto-eif431o/docker && docker compose logs --tail=50 chamilo`.
