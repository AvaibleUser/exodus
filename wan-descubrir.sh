#!/bin/bash
# wan-descubrir.sh - consulta DHCP de prueba para conocer red y gateway de un ISP
# sin configurar la interfaz. Uso: sudo bash wan-descubrir.sh wan2
# (wan1 debe estar asociada al Wi-Fi: ifup wan1)
set -u
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
IF="${1:?Uso: $0 <interfaz>}"
[ "$(id -u)" -eq 0 ] || { echo "Ejecutar con sudo"; exit 1; }
ip link show "$IF" &>/dev/null || { echo "No existe la interfaz $IF"; exit 1; }
ip link set "$IF" up

echo "Consultando DHCP en $IF (no se cambia la configuración)..."
if command -v busybox &>/dev/null && busybox udhcpc --help &>/dev/null; then
    script="$(mktemp)"
    cat > "$script" <<'EOF'
#!/bin/sh
[ "$1" = "bound" ] && echo "RESULTADO ip=$ip mascara=$subnet prefijo=/$mask gateway=$router dns=$dns"
exit 0
EOF
    chmod +x "$script"
    busybox udhcpc -i "$IF" -n -q -f -t 5 -s "$script" 2>/dev/null | grep RESULTADO
    rm -f "$script"
elif command -v dhcpcd &>/dev/null; then
    dhcpcd -T -1 -t 15 "$IF" 2>/dev/null | grep -E 'new_(ip_address|subnet_cidr|subnet_mask|routers|domain_name_servers)='
else
    echo "No hay busybox ni dhcpcd. Instale uno: sudo apt install busybox"; exit 1
fi

cat <<EOF

Con esos datos:
  * Elijan una IP LIBRE en esa red para MWAN01 (p. ej. .100 o .250, distinta del gateway).
  * Escríbanla en /etc/network/interfaces (stanza de $IF) y en /etc/multiwan/multiwan.conf
    (ISPn_IP e ISPn_GW). Luego: sudo ifdown $IF; sudo ifup $IF; sudo mwan-apply
  * Verifiquen que la red NO choque con 192.168.10/20/30/40.0/24 (si choca, apaguen y
    enciendan el anclaje USB para que el celular elija otra red).
EOF
