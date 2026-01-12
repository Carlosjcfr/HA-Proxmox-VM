#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Modified by Assistant for Custom User Requirements

function header_info {
  clear
  cat <<"EOF"
   __  ____                __           ___  __ __   ____  __ __     _    ____  ___
  / / / / /_  __  ______  / /___  __   |__ \/ // /  / __ \/ // /    | |  / /  |/  /
 / / / / __ \/ / / / __ \/ __/ / / /   __/ / // /_ / / / / // /_    | | / / /|_/ /
/ /_/ / /_/ / /_/ / / / / /_/ /_/ /   / __/__  __// /_/ /__  __/    | |/ / /  / /
\____/_.___/\__,_/_/ /_/\__/\__,_/   /____/ /_/ (_)____/  /_/       |___/_/  /_/
                               (INSTALADOR PERSONALIZADO)
EOF
}
header_info
echo -e "\n Cargando..."
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
NEXTID=$(pvesh get /cluster/nextid)

YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
HA=$(echo "\033[1;34m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
THIN="discard=on,ssd=1,"
set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT

function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} en línea ${RD}$line_number${CL}: código de salida ${RD}$exit_code${CL}: ejecutando comando ${YW}$command${CL}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

function cleanup_vmid() {
  if qm status $VMID &>/dev/null; then
    qm stop $VMID &>/dev/null
    qm destroy $VMID &>/dev/null
  fi
}

function cleanup() {
  popd >/dev/null
  rm -rf $TEMP_DIR
}

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null
if whiptail --backtitle "Proxmox VE Scripts" --title "Ubuntu 24.04 VM" --yesno "Esto creará una nueva VM de Ubuntu 24.04. ¿Proceder?" 10 58; then
  :
else
  header_info && echo -e "⚠ Usuario canceló el script \n" && exit
fi

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

function check_root() {
  if [[ "$(id -u)" -ne 0 || $(ps -o comm= -p $PPID) == "sudo" ]]; then
    clear
    msg_error "Por favor ejecute este script como root."
    echo -e "\nSaliendo..."
    sleep 2
    exit
  fi
}

function pve_check() {
  if ! pveversion | grep -Eq "pve-manager/(8\.[1-9]|9\.)"; then
    msg_error "Esta versión de Proxmox VE no está soportada"
    echo -e "Requiere Proxmox VE Version 8.1 o posterior."
    echo -e "Saliendo..."
    sleep 2
    exit
  fi
}

function arch_check() {
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    msg_error "Este script no funciona en PiMox! \n"
    echo -e "Saliendo..."
    sleep 2
    exit
  fi
}

function ssh_check() {
  if command -v pveversion >/dev/null 2>&1; then
    if [ -n "${SSH_CLIENT:+x}" ]; then
      if whiptail --backtitle "Proxmox VE Scripts" --defaultno --title "SSH DETECTADO" --yesno "Se sugiere usar la consola de Proxmox en lugar de SSH. ¿Desea proceder con SSH de todos modos?" 10 62; then
        echo "Advertencia: SSH detectado"
      else
        clear
        exit
      fi
    fi
  fi
}

function exit-script() {
  clear
  echo -e "⚠  Usuario canceló el script \n"
  exit
}

function configuracion_usuario() {
  # VMID
  while true; do
    if VMID=$(whiptail --backtitle "Proxmox VE Scripts" --inputbox "Establecer ID de Máquina Virtual" 8 58 $NEXTID --title "ID MÁQUINA VIRTUAL" --cancel-button Salir 3>&1 1>&2 2>&3); then
      if [ -z "$VMID" ]; then
        VMID="$NEXTID"
      fi
      if pct status "$VMID" &>/dev/null || qm status "$VMID" &>/dev/null; then
        echo -e "${CROSS}${RD} ID $VMID ya está en uso${CL}"
        sleep 2
        continue
      fi
      echo -e "${DGN}ID Máquina Virtual: ${BGN}$VMID${CL}"
      break
    else
      exit-script
    fi
  done

  # Hostname
  if VM_NAME=$(whiptail --backtitle "Proxmox VE Scripts" --inputbox "Establecer Nombre de Host" 8 58 ubuntu --title "NOMBRE DE HOST" --cancel-button Salir 3>&1 1>&2 2>&3); then
    if [ -z $VM_NAME ]; then
      HN="ubuntu"
    else
      HN=$(echo ${VM_NAME,,} | tr -d ' ')
    fi
    echo -e "${DGN}Nombre de Host: ${BGN}$HN${CL}"
  else
    exit-script
  fi

  # Cores
  if CORE_COUNT=$(whiptail --backtitle "Proxmox VE Scripts" --inputbox "Asignar Núcleos CPU" 8 58 2 --title "NÚCLEOS" --cancel-button Salir 3>&1 1>&2 2>&3); then
    if [ -z $CORE_COUNT ]; then
      CORE_COUNT="2"
    fi
    echo -e "${DGN}Núcleos Asignados: ${BGN}$CORE_COUNT${CL}"
  else
    exit-script
  fi

  # RAM
  if RAM_SIZE=$(whiptail --backtitle "Proxmox VE Scripts" --inputbox "Asignar RAM en MiB" 8 58 2048 --title "RAM" --cancel-button Salir 3>&1 1>&2 2>&3); then
    if [ -z $RAM_SIZE ]; then
      RAM_SIZE="2048"
    fi
    echo -e "${DGN}RAM Asignada: ${BGN}$RAM_SIZE${CL}"
  else
    exit-script
  fi

  # Disk Size (Solicitado explícitamente)
  if DISK_SIZE_GB=$(whiptail --backtitle "Proxmox VE Scripts" --inputbox "Tamaño del Disco en GB" 8 58 32 --title "TAMAÑO DE DISCO" --cancel-button Salir 3>&1 1>&2 2>&3); then
    if [ -z $DISK_SIZE_GB ]; then
      DISK_SIZE_GB="32"
    fi
    echo -e "${DGN}Tamaño de Disco: ${BGN}${DISK_SIZE_GB}GB${CL}"
  else
    exit-script
  fi

  # Bridge
  if BRG=$(whiptail --backtitle "Proxmox VE Scripts" --inputbox "Establecer Puente (Bridge)" 8 58 vmbr0 --title "PUENTE" --cancel-button Salir 3>&1 1>&2 2>&3); then
    if [ -z $BRG ]; then
      BRG="vmbr0"
    fi
    echo -e "${DGN}Usando Puente: ${BGN}$BRG${CL}"
  else
    exit-script
  fi

  # MAC
  if MAC1=$(whiptail --backtitle "Proxmox VE Scripts" --inputbox "Establecer dirección MAC" 8 58 $GEN_MAC --title "DIRECCIÓN MAC" --cancel-button Salir 3>&1 1>&2 2>&3); then
    if [ -z $MAC1 ]; then
      MAC="$GEN_MAC"
    else
      MAC="$MAC1"
    fi
    echo -e "${DGN}Usando MAC: ${BGN}$MAC${CL}"
  else
    exit-script
  fi

  # Default Settings for others
  FORMAT=",efitype=4m"
  MACHINE=""
  DISK_CACHE=""
  CPU_TYPE=""
  VLAN=""
  MTU=""
  
  if (whiptail --backtitle "Proxmox VE Scripts" --title "CONFIRMACIÓN" --yesno "¿Listo para crear la VM de Ubuntu 24.04?" 10 58); then
     echo -e "${RD}Creando VM...${CL}"
  else
     exit-script
  fi
}

check_root
arch_check
pve_check
ssh_check
configuracion_usuario

msg_info "Validando Almacenamiento"
while read -r line; do
  TAG=$(echo $line | awk '{print $1}')
  TYPE=$(echo $line | awk '{printf "%-10s", $2}')
  FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
  ITEM="  Tipo: $TYPE Libre: $FREE "
  OFFSET=2
  if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
    MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
  fi
  STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
done < <(pvesm status -content images | awk 'NR>1')
VALID=$(pvesm status -content images | awk 'NR>1')
if [ -z "$VALID" ]; then
  msg_error "No se pudo detectar una ubicación de almacenamiento válida."
  exit
elif [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
  STORAGE=${STORAGE_MENU[0]}
else
  while [ -z "${STORAGE:+x}" ]; do
    STORAGE=$(whiptail --backtitle "Proxmox VE Scripts" --title "Almacenamiento" --radiolist \
      "¿Qué almacenamiento desea usar para ${HN}?\nUse la barra espaciadora para seleccionar.\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit
  done
fi
msg_ok "Usando ${CL}${BL}$STORAGE${CL} ${GN}como ubicación de almacenamiento."
msg_ok "ID de Máquina Virtual es ${CL}${BL}$VMID${CL}."

msg_info "Obteniendo URL de la imagen de Ubuntu 24.04"
URL=https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
sleep 2
msg_ok "${CL}${BL}${URL}${CL}"
wget -q --show-progress $URL
echo -en "\e[1A\e[0K"
FILE=$(basename $URL)
msg_ok "Descargado ${CL}${BL}${FILE}${CL}"

STORAGE_TYPE=$(pvesm status -storage $STORAGE | awk 'NR>1 {print $2}')
case $STORAGE_TYPE in
nfs | dir)
  DISK_EXT=".qcow2"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format qcow2"
  THIN=""
  ;;
btrfs)
  DISK_EXT=".raw"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format raw"
  FORMAT=",efitype=4m"
  THIN=""
  ;;
esac
for i in {0,1}; do
  disk="DISK$i"
  eval DISK${i}=vm-${VMID}-disk-${i}${DISK_EXT:-}
  eval DISK${i}_REF=${STORAGE}:${DISK_REF:-}${!disk}
done

msg_info "Creando VM Ubuntu 24.04"
qm create $VMID -agent 1${MACHINE} -tablet 0 -localtime 1 -bios ovmf${CPU_TYPE} -cores $CORE_COUNT -memory $RAM_SIZE \
  -name $HN -tags proxmox-helper-scripts -net0 virtio,bridge=$BRG,macaddr=$MAC$VLAN$MTU -onboot 1 -ostype l26 -scsihw virtio-scsi-pci
pvesm alloc $STORAGE $VMID $DISK0 4M > /dev/null 2>&1
qm importdisk $VMID ${FILE} $STORAGE ${DISK_IMPORT:-} > /dev/null 2>&1
qm set $VMID \
  -efidisk0 ${DISK0_REF}${FORMAT} \
  -scsi0 ${DISK1_REF},${DISK_CACHE}${THIN}size=${DISK_SIZE_GB}G \
  -ide2 ${STORAGE}:cloudinit \
  -boot order=scsi0 \
  -serial0 socket \
  -description "<div align='center'><a href='https://Helper-Scripts.com'><img src='https://raw.githubusercontent.com/tteck/Proxmox/main/misc/images/logo-81x112.png'/></a>

  # Ubuntu 24.04 VM (Custom)

  </div>" >/dev/null
msg_ok "Creada VM Ubuntu 24.04 ${CL}${BL}(${HN})"
msg_ok "Completado Exitosamente!\n"
echo -e "Configure Cloud-Init antes de iniciar \n"
