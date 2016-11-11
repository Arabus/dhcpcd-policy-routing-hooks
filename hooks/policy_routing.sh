_get_free_routing_table_id(){
  # TODO fix this
  printf "%i" $(($RANDOM % 253 + 1))
}

_add_or_update_policy(){
  # for each global prefix create or replace a new source route to a routing table
  # also add a default route to each routing table
  local prefix_addr=$1
  local prefix_gw=$2
  local prefix_table=$(/sbin/ip -6 ru | grep "from ${prefix_addr}" | sed -rne 's/.*lookup ([0-9]+)/\1/p')
  [ -z "$prefix_table" ] && \
    local table_id=$(_get_free_routing_table_id) && \
    /sbin/ip -6 r a table ${table_id} default via ${prefix_gw} && \
    /sbin/ip -6 rule add from ${prefix_addr} table ${table_id}

  /sbin/ip -6 r r table ${prefix_table} default via ${prefix_gw}
}

_add_policy_routing(){
        # Loop to extract the ND prefix and router options using our indexed shell values
        local -i i=1
        local -i j=1
        while true; do
                while true; do
                        eval prefix=$nd${i}_prefix_information${j}_prefix
                        [ -z "${prefix}" ] && break
                        eval prefix_vltime=$nd${i}_prefix_information${j}_vltime
                        # do not setup policies for prefixes to be removed
                        [ ${prefix_vltime} -eq 0 ] && let j++ && continue

                        eval prefix_addr=$nd${i}_addr${j}
                        eval router_address=$nd${i}_from
                        _add_or_update_policy ${prefix_addr} ${router_address}
                        let j++
                done

                [ -z "${prefix}" ] && break
                let i++
        done
}

_remove_policy(){
  local prefix_addr=$1
  local prefix_table=$(/sbin/ip -6 ru | grep "from ${prefix_addr}" | sed -rne 's/.*lookup ([0-9]+)/\1/p')

  [ -z "$prefix_table" ] && return 0
  /sbin/ip -6 rule d from ${prefix_addr} table "${prefix_table}"
  /sbin/ip -6 r d table ${prefix_table}
}


The contents...
licy_routing(){
        # Loop to extract the ND prefix and router options using our indexed shell values
        local -i i=1
        local -i j=1
        while true; do
                while true; do
                        eval prefix=$nd${i}_prefix_information${j}_prefix
                        [ -z "${prefix}" ] && break
                        eval prefix_vltime=$nd${i}_prefix_information${j}_vltime
                        # remove policies for prefixes to be removed
                        [ ${prefix_vltime} -ne 0 ] && let j++ && continue

                        eval prefix_addr=$nd${i}_addr${j}
                        _remove_policy ${prefix_addr}
                        let j++
                done

                [ -z "${prefix}" ] && break
                let i++
        done
}

_stop_policy_routing(){
  # remove all policy routes and tables for managed interfaces
  local tables=$(ip route show table all | grep "table" | sed 's/.*\(table.*\)/\1/g' | awk '{print $2}' | sort | uniq | grep -e "[0-9]")
  for table_number in $tables; do
    /sbin/ip -6 r d table ${table_number}
  done
}

case "$reason" in
ROUTER*)
        _add_policy_routing
        _remove_policy_routing
        exit 0
        ;;
STOP*)
        _stop_policy_routing
esac
