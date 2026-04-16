#!/usr/bin/env bash
set -u

TARGET_SUITE="trixie"
SOURCE_SUITE="bookworm"
SOURCES_LIST="/etc/apt/sources.list"

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERRO: rode como root."
    exit 1
  fi
}

need_whiptail() {
  if ! command -v whiptail >/dev/null 2>&1; then
    echo "ERRO: 'whiptail' nÃ£o estÃ¡ instalado. Instale com: apt update && apt install -y whiptail"
    exit 1
  fi
}

get_debian_version() {
  . /etc/os-release 2>/dev/null || true
  echo "${VERSION_ID:-unknown}"
}

run_step() {
  local desc="$1"
  shift
  echo
  echo "==> ${desc}"
  "$@"
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "ERRO: etapa falhou (${desc}) com cÃ³digo ${rc}"
    exit $rc
  fi
}

need_root
need_whiptail

CUR_VER="$(get_debian_version)"

whiptail --title "ATENÃ‡ÃƒO: AtualizaÃ§Ã£o do Debian" --backtitle "Upgrade Debian 12 â†’ 13" \
  --yesno "Sistema serÃ¡ atualizado para Debian 13 (${TARGET_SUITE}).\n\nVersÃ£o atual detectada: ${CUR_VER}\n\nANTES DE CONTINUAR:\n- FaÃ§a um backup da VM atual, e qualquer coisa volte o backup.\n\nDeseja continuar?" \
  20 78

if [[ $? -ne 0 ]]; then
  echo "Cancelado pelo usuÃ¡rio."
  exit 0
fi

whiptail --title "Aviso: GRUB pode solicitar interaÃ§Ã£o" --backtitle "Upgrade Debian 12 â†’ 13" \
  --msgbox "Durante o upgrade, pode aparecer uma tela perguntando em quais dispositivos/partiÃ§Ãµes instalar/atualizar o GRUB.\n\nINSTRUÃ‡ÃƒO:\n- Marque TODAS as caixas/listas apresentadas\n- Confirme para prosseguir" \
  18 78

if [[ "${CUR_VER}" != "12" ]]; then
  whiptail --title "Aviso: versÃ£o atual nÃ£o Ã© Debian 12" --backtitle "Upgrade Debian 12 â†’ 13" \
    --yesno "Este script foi pensado para Debian 12 â†’ 13.\n\nVersÃ£o detectada: ${CUR_VER}\n\nSe vocÃª continuar assim mesmo, a responsabilidade Ã© sua.\n\nContinuar?" \
    16 78
  if [[ $? -ne 0 ]]; then
    echo "Cancelado pelo usuÃ¡rio."
    exit 0
  fi
fi

  run_step "Atualizando ${SOURCES_LIST} para ${TARGET_SUITE}" bash -c "sed -i 's/${SOURCE_SUITE}/${TARGET_SUITE}/g' /etc/apt/sources.list ; sed -i 's/${SOURCE_SUITE}/${TARGET_SUITE}/g' /etc/apt/sources.list.d/*.list"

run_step "apt update" apt update

run_step "apt full-upgrade (nÃ£o-interativo)" bash -c 'DEBIAN_FRONTEND=noninteractive apt -y \
  -o Dpkg::Options::="--force-confold" \
  -o Dpkg::Options::="--force-confdef" \
  full-upgrade'

run_step "apt install -f (corrigir dependÃªncias)" apt install -f -y

run_step "apt autoremove" apt autoremove -y

whiptail --title "Upgrade concluÃdo" --backtitle "Upgrade Debian 12 â†’ 13" \
  --yesno "A atualizaÃ§Ã£o foi concluÃda.\n\nAgora Ã© necessÃ¡rio reiniciar para carregar o novo kernel/serviÃ§os.\n\nReiniciar agora?" \
  14 78

if [[ $? -eq 0 ]]; then
  echo "Reiniciando..."
  reboot
else
  echo "ReinÃcio adiado pelo usuÃ¡rio. Reinicie quando possÃvel: reboot"
fi
