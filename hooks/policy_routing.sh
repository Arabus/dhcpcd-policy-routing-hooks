_get_free_routing_table_id(){
  local new_id=$(/sbin/ip -6 route show table all | grep "table" | sed 's/.*\(table.*\)/\1/g' | awk '{print $2}' | sort | uniq | grep -e "[0-9]" | sort -rn | head -n1)
  [ -z "${new_id}" ] && new_id=0
  new_id=$(($new_id + 1))
  printf "%i" $new_id
}

_add_or_update_policy(){

  local prefix_addr=${1?"Source address required"}
  local prefix_gw=${2?gateway address required}
  local prefix_table=$(/sbin/ip -6 ru | grep "from ${prefix_addr}" | head -n1 | sed -rne 's/.*lookup ([0-9]+)/\1/p')
  if [ -z "$prefix_table" ]; then
    local table_id=$(_get_free_routing_table_id)
    /sbin/ip -6 route add table ${table_id} default via ${prefix_gw} dev ${interface}
    /sbin/ip -6 rule add from ${prefix_addr} table ${table_id}
    return 0
  fi

  /sbin/ip -6 r r table ${prefix_table} default via ${prefix_gw} dev ${interface}
}

_add_policy_routing(){
        # Loop to extract the ND prefix and router options using our indexed shell values
        local refix=''
        local i=1
        local j=1
        while true; do
                while true; do
                        eval prefix=\$nd${i}_prefix_information${j}_prefix
                        [ -z "${prefix}" ] && break
                        eval prefix_vltime=\$nd${i}_prefix_information${j}_vltime
                        # do not setup policies for prefixes to be removed
                        [ ${prefix_vltime} -eq 0 ] && j=$(($j + 1)) && continue

                        eval prefix_addr=\$nd${i}_addr${j}
                        eval router_address=\$nd${i}_from
                        [ -z "${prefix_addr}" ] || [ -z "${router_address}" ] && break
                        _add_or_update_policy ${prefix_addr} ${router_address}
                        j=$(($j + 1))
                done

                [ -z "${prefix}" ] && break
                i=$(($i + 1))
        done
}
_remove_policy(){
  local prefix_addr=$1
  local prefix_table=$(/sbin/ip -6 ru | grep "from ${prefix_addr}" | sed -rne 's/.*lookup ([0-9]+)/\1/p')

  [ -z "$prefix_table" ] && return 0
  while /sbin/ip -6 ru d from ::/0 to ::/0 table ${prefix_table} &>/dev/null; do
    true
  done
  /sbin/ip -6 r f table ${prefix_table}
}

_remove_policy_routing(){
        # Loop to extract the ND prefix and router options using our indexed shell values
        local prefix=''
        local i=1
        local j=1
        while true; do
                while true; do
                        eval prefix=\$nd${i}_prefix_information${j}_prefix
                        [ -z "${prefix}" ] && break
                        eval prefix_vltime=\$nd${i}_prefix_information${j}_vltime
                        # remove policies for prefixes to be removed
                        [ ${prefix_vltime} -ne 0 ] && j=$(($j + 1)) && continue

                        eval prefix_addr=\$nd${i}_addr${j}
                        _remove_policy ${prefix_addr}
                        j=$(($j + 1))
                done

                [ -z "${prefix}" ] && break
                i=$(($i + 1))
        done
}

_stop_policy_routing(){
  # remove all policy routes and tables for managed interfaces
  # /sbin/ip -6 r d table 10
  local tables=$(ip route show table all | grep "table" | sed 's/.*\(table.*\)/\1/g' | awk '{print $2}' | sort | uniq | grep -e "[0-9]")
  for table_number in $tables; do
    /sbin/ip -6 r f table ${table_number}
    while /sbin/ip -6 ru d from ::/0 to ::/0 table ${table_number} &>/dev/null; do
      true
    done
  done
}

case "$reason" in
ROUTERADVERT)
        set | sort >> /tmp/pdump
        _add_policy_routing
        _remove_policy_routing
        exit 0
        ;;
STOP*)
        _stop_policy_routing
esac

