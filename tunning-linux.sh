#!/bin/bash

# Checagem se o usuário é root
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script precisa ser executado como root."
    exit 1
fi

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==========================="
echo "   Arthur Linux Bootstrap  "
echo "==========================="
sleep 1; echo

echo "[1/7] Atualizando sistema..."
echo
apt update && apt upgrade -y && apt --purge autoremove -y
sleep 1; echo

echo "[2/7] Instalando pacotes..."
echo
apt install sudo lsof snapd vim tcptraceroute bash-completion build-essential irqbalance grc tree bmon net-tools nmap dnsutils whois htop curl wget apt-transport-https dirmngr mtr traceroute screenfetch iotop openssh-server netdiscover gnupg2 gnupg1 aptitude hping3 fping lshw unzip lsb-release ipcalc man-db hdparm fzf chrony qemu-guest-agent -y
sleep 1; echo

echo "[3/7] Configurando serviços..."
echo
systemctl enable --now irqbalance snapd chrony qemu-guest-agent
sleep 1; echo

echo "[4/7] Configurando Chrony..."
echo
cat <<EOF >/etc/chrony/chrony.conf
pool a.ntp.br iburst
pool b.ntp.br iburst

driftfile /var/lib/chrony/chrony.drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF

systemctl restart chrony
sleep 1; echo

echo "[5/7] Otimizando shell..."
sleep 1; echo

# Autocomplete global (inserir no bash.bashrc apenas se ainda não inserido)
if ! grep -q "bash-completion" /etc/bash.bashrc; then
    cat <<'EOF' >> /etc/bash.bashrc

# Autocompletar extra
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
EOF
fi
sleep 1

# Config Vim
sed -i 's/"syntax on/syntax on/' /etc/vim/vimrc || true
sed -i 's/"set background=dark/set background=dark/' /etc/vim/vimrc || true

cat <<EOF >/root/.vimrc
set showmatch
set ts=4
set sts=4
set sw=4
set autoindent
set smartindent
set smarttab
set expandtab
set number
EOF

# Agora reconstruímos o /root/.bashrc do zero
BASHRC=/root/.bashrc
rm -f $BASHRC

cat <<'EOF' > $BASHRC
# ~/.bashrc: Arthur Bootstrap Custom

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# Histórico otimizado
HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize

# less otimizado
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Aliases básicos coloridos
export LS_OPTIONS='--color=always'
eval "`dircolors`"
alias ls='grc ls $LS_OPTIONS -lahtr'
alias ll='grc ls $LS_OPTIONS -lahtr'
alias l='grc ls $LS_OPTIONS -lhatr'

# Aliases de comandos com grc
alias grep='grep --color'
alias tail='grc tail'
alias ping='grc ping'
alias traceroute='grc traceroute -A'
alias traceroute6='grc traceroute6 -A'
alias ps='grc ps'
alias netstat='grc netstat'
alias dig='grc dig'
alias nmap='grc nmap'
alias whois='grc whois'
alias mtr='grc mtr --aslookup --show-ips'
alias df='grc df -hT'
alias hping='grc hping3'
alias hping3='grc hping3'
alias lsblk='grc lsblk'
alias du='grc du -hc'
alias ip='ip -c'

# PS1 custom Arthur Bootstrap
PS1="${debian_chroot:+(${debian_chroot})}\[\033[01;31m\]\u\[\033[01;34m\]@\[\033[01;33m\]\h\[\033[01;34m\][\[\033[00m\]\[\033[01;37m\]\w\[\033[01;34m\]]\[\033[01;31m\]\\$\[\033[00m\] "

# Carrega aliases adicionais caso existam
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Atalhos FZF
source /usr/share/doc/fzf/examples/key-bindings.bash
EOF

sleep 1

echo "[6/7] Ajustando kernel..."
sleep 1; echo

cat <<EOF >/etc/sysctl.conf
vm.swappiness = 5
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
net.core.somaxconn = 65535
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_mem = 4096 87380 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_fin_timeout = 15
net.core.netdev_max_backlog = 8192
net.ipv4.ip_local_port_range = 1024 65535
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

sysctl -p
sleep 1; echo

echo "[7/7] Carregando módulos TCP adicionais..."
echo
for module in tcp_illinois tcp_westwood tcp_htcp; do
    modprobe -a $module
    grep -q "$module" /etc/modules || echo "$module" >> /etc/modules
done

echo
echo "==========================="
echo "Provisionamento concluído!"
echo "==========================="
echo
sleep 1
