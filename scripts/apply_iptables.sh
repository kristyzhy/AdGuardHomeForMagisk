#!/system/bin/sh

AGH_DIR="/data/adb/agh"
exec >"$AGH_DIR/apply.log" 2>&1
source "$AGH_DIR/scripts/config.sh"

# find packages uid
uid_list=()
for package in "${packages_list[@]}"; do
  uid_list+=$(
    busybox awk -v p="${package}" '$1~p{print $2}' "${system_packages_file}"
  )
done

$iptables_w -t nat -N ADGUARD
# return requests from AdGuardHome
$iptables_w -t nat -A ADGUARD -m owner --uid-owner $adg_user --gid-owner $adg_group -j RETURN
# return requests from bypassed apps
if [ "$use_blacklist" = true ]; then
  if [ ${#uid_list[@]} -ne 0 ]; then
    for uid in "${uid_list[@]}"; do
      $iptables_w -t nat -A ADGUARD -m owner --uid-owner $uid -j RETURN
    done
  fi
  # redirect DNS requests to AdGuardHome
  $iptables_w -t nat -A ADGUARD -p udp --dport 53 -j REDIRECT --to-ports $redir_port
  $iptables_w -t nat -A ADGUARD -p tcp --dport 53 -j REDIRECT --to-ports $redir_port
else
  if [ ${#uid_list[@]} -ne 0 ]; then
    for uid in "${uid_list[@]}"; do
      $iptables_w -t nat -A ADGUARD -p udp --dport 53 -m owner --uid-owner $uid -j REDIRECT --to-ports $redir_port
      $iptables_w -t nat -A ADGUARD -p tcp --dport 53 -m owner --uid-owner $uid -j REDIRECT --to-ports $redir_port
    done
  fi
  $iptables_w -t nat -A ADGUARD -j RETURN
fi

# apply iptables rules
$iptables_w -t nat -I OUTPUT -j ADGUARD

if [ "$ipv6" = false ]; then
  # DROP ipv6 DNS requests
  ip6tables -t filter -A OUTPUT -p udp --dport 53 -j DROP
  ip6tables -t filter -A OUTPUT -p tcp --dport 53 -j DROP
  # disable ipv6
  # sysctl -w net.ipv4.ip_forward=1
  # sysctl -w net.ipv6.conf.all.forwarding=0
  # sysctl -w net.ipv6.conf.all.accept_ra=0
  # sysctl -w net.ipv6.conf.wlan0.accept_ra=0
  sysctl -w net.ipv6.conf.all.disable_ipv6=1
  sysctl -w net.ipv6.conf.default.disable_ipv6=1
  # sysctl -w net.ipv6.conf.wlan0.disable_ipv6=1
fi
