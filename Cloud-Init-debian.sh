#!/bin/bash

# Variables à personnaliser
VM_ID=1000
VM_NAME="debian-cloud-template"
CLOUD_IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
CLOUD_IMAGE="debian-12-genericcloud-amd64.qcow2"
PROXMOX_IMAGE_PATH="/var/lib/vz/images/"
STORAGE_NAME="local-lvm"

# Téléchargement de l'image QCOW2
echo "Téléchargement de l'image QCOW2 depuis Debian Cloud..."
if wget -O "${PROXMOX_IMAGE_PATH}${CLOUD_IMAGE}" "${CLOUD_IMAGE_URL}"; then
  echo "Image téléchargée avec succès dans ${PROXMOX_IMAGE_PATH}${CLOUD_IMAGE}."
else
  echo "Échec du téléchargement de l'image QCOW2."
  exit 1
fi

# Création d'une nouvelle VM vide
echo "Création d'une VM vide avec l'ID ${VM_ID}..."
if qm create "${VM_ID}" --name "${VM_NAME}" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0; then
  echo "VM ${VM_ID} créée avec succès."
else
  echo "Échec de la création de la VM."
  exit 1
fi

# Importation de l'image QCOW2 comme disque principal
echo "Importation de l'image QCOW2 dans le stockage ${STORAGE_NAME}..."
if qm importdisk "${VM_ID}" "${PROXMOX_IMAGE_PATH}${CLOUD_IMAGE}" "${STORAGE_NAME}"; then
  echo "Disque importé avec succès dans le stockage ${STORAGE_NAME}."
else
  echo "Échec de l'importation du disque QCOW2."
  exit 1
fi

# Associer le disque importé comme disque principal
echo "Configuration du disque principal pour la VM..."
if qm set "${VM_ID}" --scsihw virtio-scsi-pci --scsi0 "${STORAGE_NAME}:vm-${VM_ID}-disk-0"; then
  echo "Disque principal configuré avec succès."
else
  echo "Échec de la configuration du disque principal."
  exit 1
fi

# Configurer le boot sur le disque principal
echo "Configuration de l'ordre de boot sur le disque principal..."
if qm set "${VM_ID}" --boot c --bootdisk scsi0; then
  echo "Configuration de l'ordre de boot réussie."
else
  echo "Échec de la configuration de l'ordre de boot."
  exit 1
fi

# Ajouter un disque Cloud-Init
echo "Ajout d'un disque Cloud-Init..."
if qm set "${VM_ID}" --ide2 "${STORAGE_NAME}:cloudinit"; then
  echo "Disque Cloud-Init ajouté avec succès."
else
  echo "Échec de l'ajout du disque Cloud-Init."
  exit 1
fi


# Validation des entrées utilisateur pour Cloud-Init
while [ -z "$CI_USER" ]; do
  read -p "Entrez le nom d'utilisateur pour Cloud-Init (par défaut : debian) : " CI_USER
  CI_USER=${CI_USER:-debian}
done

while [ -z "$CI_PASSWORD" ]; do
  read -s -p "Entrez le mot de passe pour Cloud-Init : " CI_PASSWORD
  echo ""
  if [ -z "$CI_PASSWORD" ]; then
    echo "Le mot de passe ne peut pas être vide. Veuillez réessayer."
  fi
done

while [ -z "$CI_NETCONFIG" ]; do
  read -p "Entrez la configuration réseau pour Cloud-Init (ex : dhcp ou IP statique) : " CI_NETCONFIG
  CI_NETCONFIG=${CI_NETCONFIG:-dhcp}
  if [ -z "$CI_NETCONFIG" ]; then
    echo "La configuration réseau ne peut pas être vide. Veuillez réessayer."
  fi
done

# Configuration Cloud-Init
echo "Configuration des paramètres Cloud-Init..."
if qm set "${VM_ID}" --ciuser "${CI_USER}" --cipassword "${CI_PASSWORD}" --ipconfig0 ip="${CI_NETCONFIG}"; then
  echo "Cloud-Init configuré avec succès."
else
  echo "Échec de la configuration Cloud-Init."
  exit 1
fi

# Conversion de la VM en template
echo "Conversion de la VM en template..."
if qm template "${VM_ID}"; then
  echo "Template créé avec succès !"
else
  echo "Échec de la conversion en template."
  exit 1
fi

# Suppression de l'image téléchargée
echo "Suppression de l'image téléchargée pour libérer de l'espace..."
if rm -f "${PROXMOX_IMAGE_PATH}${CLOUD_IMAGE}"; then
  echo "Image QCOW2 supprimée avec succès."
else
  echo "Échec de la suppression de l'image QCOW2."
fi

echo "Script terminé avec succès. Le template Cloud-Init est prêt à être utilisé."
