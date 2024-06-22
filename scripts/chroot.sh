#!/usr/bin/env bash

set -e -x

export DEBIAN_FRONTEND=noninteractive
export HOME=/root
export LC_ALL=C

# Generar un ID de máquina
if [ -n "$(which dbus-uuidgen)" ]
then
    dbus-uuidgen > /etc/machine-id
    ln -sf /etc/machine-id /var/lib/dbus/machine-id
fi

if [ ! -f /run/systemd/resolve/stub-resolv.conf ]
then
    mkdir -p /run/systemd/resolve
    echo "nameserver 1.1.1.1" > /run/systemd/resolve/stub-resolv.conf
fi

# Especificar correctamente resolv.conf
ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Habilitar i386 para que Steam se pueda instalar
dpkg --add-architecture i386

# Añadir clave APT
if [ -n "${KEY}" ]
then
    echo "Adding APT key: ${KEY}"
    apt-key add "${KEY}"
fi

# Añadir repositorios principales de Ubuntu
echo "deb http://apt.pop-os.org/ubuntu jammy main" > /etc/apt/sources.list
echo "deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb http://apt.pop-os.org/proprietary jammy-main Pop_OS Applications" >> /etc/apt/sources.list
echo "deb http://apt.pop-os.org/release jammy-main Pop_OS Release Sources" >> /etc/apt/sources.list


# Add Brave Browser repository and key
echo "Adding Brave Browser repository and key"
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list

# Añadir todas las PPAs de la distribución
if [ $# -gt 0 ]
then
    echo "Enabling repository source"
    ENABLE_SOURCE=--enable-source
    for repo in "$@"
    do
        if [ "$repo" == "--" ]
        then
            echo "Disabling repository source"
            ENABLE_SOURCE=
        else
            echo "Adding repository '$repo'"
            if [[ "${repo}" == "deb "* ]]
            then
                echo "${repo}" >> /etc/apt/sources.list
                if [ -n "${ENABLE_SOURCE}" ]
                then
                    echo "${repo}" | sed 's/^deb /deb-src /' >> /etc/apt/sources.list
                fi
            else
                add-apt-repository ${ENABLE_SOURCE} --yes "${repo}"
            fi
        fi
    done
fi

if [ -n "${STAGING_BRANCHES}" ]
then
    if ! command -v apt-manage; then
        echo "Installing python3-repolib to add requested staging branches"
        apt-get update -y
        apt-get install -y python3-repolib
    fi

    for branch in $STAGING_BRANCHES; do
      echo "Adding preference for '$branch'"
      apt-manage add "popdev:${branch}" -y
    done
fi

# Actualizar definiciones de paquetes
if [ -n "${UPDATE}" ]
then
    echo "Actualizando listas de paquetes..."
    apt-get update -y
fi

# Mejorar paquetes instalados
if [ -n "${UPGRADE}" ]
then
    echo "Mejorando paquetes..."
    apt-get upgrade -y --allow-downgrades
    apt-get dist-upgrade -y
fi

# Instalar paquetes
if [ -n "${INSTALL}" ]
then
    INSTALL="${INSTALL} bleachbit"
    INSTALL="${INSTALL} telegram-desktop"
    # Agrega más programas aquí según sea necesario
    echo "Installing packages: ${INSTALL}"
    apt-get install -y ${INSTALL}
fi

if [ -n "${LANGUAGES}" ]
then
    pkgs=""
    for language in ${LANGUAGES}
    do
        echo "Adding language '$language'"
        pkgs+=" $(XDG_CURRENT_DESKTOP=GNOME check-language-support --show-installed --language="$language")"
    done
    if [ -n "$pkgs" ]
    then
        apt-get install -y --no-install-recommends $pkgs
    fi
fi

# Eliminar paquetes
if [ -n "${PURGE}" ]
then
    echo "Removing packages: ${PURGE}"
    apt-get purge -y ${PURGE}
fi

# Eliminar paquetes innecesarios
if [ -n "${AUTOREMOVE}" ]
then
    apt-get autoremove --purge -y
fi

# Descargar paquetes del main pool
if [ -n "${MAIN_POOL}" ]
then
    mkdir -p "/iso/pool/main"
    chown -R _apt "/iso/pool/main"
    pushd "/iso/pool/main"
        apt-get download ${MAIN_POOL}
    popd
fi

# Descargar paquetes del restricted pool
if [ -n "${RESTRICTED_POOL}" ]
then
    mkdir -p "/iso/pool/restricted"
    chown -R _apt "/iso/pool/restricted"
    pushd "/iso/pool/restricted"
        apt-get download ${RESTRICTED_POOL}
    popd
fi

# Limpiar archivos de apt
if [ -n "${CLEAN}" ]
then
    apt-get clean -y
fi

# Eliminar archivos temporales
rm -rf /tmp/*

# Eliminar ID de máquina
rm -f /var/lib/dbus/machine-id
