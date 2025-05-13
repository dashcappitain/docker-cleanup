#!/bin/bash

set -e

echo "=== 1. Mengecek penggunaan terbesar ==="
top_log=$(du -ahx /var/lib/docker/containers 2>/dev/null | sort -rh | grep -m1 '\.log$')
log_size=$(echo "$top_log" | awk '{print $1}')
log_path=$(echo "$top_log" | awk '{print $2}')
container_id=$(basename $(dirname "$log_path"))

if [ -z "$log_path" ]; then
    echo "Tidak ditemukan log besar di container."
else
    echo "Penggunaan terbesar ditemukan di file log: $log_path ($log_size)"
fi

echo
echo "=== 2. Membersihkan Docker container dan image yang tidak digunakan ==="
docker system prune -af --volumes

echo
echo "=== 3. Menghapus log besar docker (jika ada) ==="
if [ -f "$log_path" ]; then
    echo "Log besar ditemukan di: $log_path"
else
    echo "Tidak ditemukan file log besar untuk dihapus."
fi

echo
echo "=== 4. Menghapus file di /tmp ==="
rm -rf /tmp/*
echo "Semua file di /tmp telah dihapus."

echo
echo "=== 5. Identifikasi container ==="
docker ps -a --no-trunc | grep "$container_id" || echo "Container tidak ditemukan di daftar aktif/berhenti."

echo
echo "=== 6. Menampilkan isi akhir log dan konfirmasi ==="
if [ -f "$log_path" ]; then
    echo "Isi 20 baris terakhir dari $log_path:"
    tail -n 20 "$log_path"

    read -p "Apakah Anda ingin menghapus log ini? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        echo
        echo "=== 7. Truncate log ==="
        truncate -s 0 "$log_path"
        echo "Log telah dikosongkan."
    else
        echo "Log tidak dihapus."
    fi
else
    echo "Log file tidak ditemukan."
fi

echo
echo "=== 8. Menambahkan pembatas log di /etc/docker/daemon.json ==="
daemon_file="/etc/docker/daemon.json"

if [ ! -f "$daemon_file" ]; then
    echo "{}" > "$daemon_file"
fi

jq '. + {
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}' "$daemon_file" > /tmp/daemon.json.tmp && mv /tmp/daemon.json.tmp "$daemon_file"

echo "Konfigurasi log Docker telah diupdate: $daemon_file"

echo
echo "=== 9. Restart Docker ==="
systemctl restart docker && echo "Docker berhasil direstart."

echo
echo "✅ Pembersihan selesai."
