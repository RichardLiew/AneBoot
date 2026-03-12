# Hosts:
function assign_hosts() {
  local -r computer_name="$1"
  local -r local_hostname="$2"
  local -r hostname="$3"

  sudo scutil --set ComputerName "${computer_name}"
  sudo scutil --set LocalHostName "${local_hostname}"
  sudo scutil --set HostName "${hostname}"

  sudo dscacheutil -flushcache
  sudo killall -HUP mDNSResponder
}


function set_hosts() {
  assign_hosts \
    "Richard's MacBook Pro" \
    "RichardMacBookPro" \
    "anebit.cn"
}


set_hosts
