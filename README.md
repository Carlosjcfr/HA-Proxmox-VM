# 🚀 Instalación Automática de VM en Proxmox via Script

Esta guía explica cómo desplegar una Máquina Virtual (VM) o Contenedor (LXC) en Proxmox VE ejecutando un script de instalación directamente desde la consola (Shell) utilizando su URL `raw`.

Todos los scripts son modificaciones de los script de tteck (@tteckster), debido a que algunso de ellos instalaban versiones antiguas o daban problemas con el chekeo de la version de proxmox instalada

## 📋 Prerrequisitos

* Acceso a la interfaz web de **Proxmox VE**.
* Conexión a internet desde el nodo de Proxmox.
* La **URL Raw** del script (ej. `https://raw.githubusercontent.com/.../install.sh`).

## 🛠️ Instrucciones de Ejecución

Sigue estos pasos para lanzar el instalador:

1.  Inicia sesión en tu interfaz web de Proxmox.
2.  Selecciona tu **Nodo (pve)** en el menú de la izquierda.
3.  Haz clic en **>_ Shell** para abrir la consola del sistema.

4.  **Ejecuta el comando combinado:**
    Copia y pega la siguiente línea, reemplazando `<URL_RAW_DEL_SCRIPT>` con la dirección real de tu script.

    ```bash
    bash -c "$(wget -qO - <URL_RAW_DEL_SCRIPT>)"
    ```

### 💡 Ejemplo Real

Si deseas instalar un servicio específico (por ejemplo, Home Assistant o un script de prueba), el comando se vería así:

```bash
bash -c "$(wget -qO - [https://raw.githubusercontent.com/usuario/repo/main/install_vm.sh](https://raw.githubusercontent.com/usuario/repo/main/install_vm.sh))"
