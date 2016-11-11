muacc_map_dir="$state_dir/muacc"
NL="
"

# Extract any ND DNS options from the RA
# For now, we ignore the lifetime of the DNS options unless they
# are absent or zero.
# In this case they are removed from consideration.
# See draft-gont-6man-slaac-dns-config-issues-01 for issues
# regarding DNS option lifetime in ND messages.
eval_nd_dns()
{

        eval ltime=\$nd${i}_rdnss${j}_lifetime
        if [ -z "$ltime" -o "$ltime" = 0 ]; then
                rdnss=
        else
                eval rdnss=\$nd${i}_rdnss${j}_servers
        fi
        eval ltime=\$nd${i}_dnssl${j}_lifetime
        if [ -z "$ltime" -o "$ltime" = 0 ]; then
                dnssl=
        else
                eval dnssl=\$nd${i}_dnssl${j}_search
        fi

        [ -z "$rdnss" -a -z "$dnssl" ] && return 1

        new_rdnss="$new_rdnss${new_rdnss:+ }$rdnss"
        new_dnssl="$new_dnssl${new_dnssl:+ }$dnssl"
        j=$(($j + 1))
        return 0
}

add_muacc_map()
{
        local x= conf="$signature$NL" warn=true
        local i j ltime rdnss dnssl new_rdnss new_dnssl

        # Loop to extract the ND DNS options using our indexed shell values
        i=1
        j=1
        while true; do
                while true; do
                        eval_nd_dns || break
                done
                i=$(($i + 1))
                j=1
                eval_nd_dns || break
        done
        new_domain_name_servers="$new_domain_name_servers${new_domain_name_servers:+ }$new_rdnss"
        new_domain_search="$new_domain_search${new_domain_search:+ }$new_dnssl"

        # If we don't have any configuration, remove it
        if [ -z "$new_domain_name_servers" -a \
                -z "$new_domain_search" ]; then
                remove_muacc_map
                return $?
        fi

        if [ -n "$new_domain_search" ]; then
                if valid_domainname_list $new_domain_search; then
                        conf="${conf}search $new_domain_search$NL"
                elif ! $warn; then
                        syslog err "Invalid domain name in list:" \
                            "$new_domain_search"
                fi
        fi
        for x in ${new_domain_name_servers}; do
                conf="${conf}nameserver $x$NL"
        done

        if [ -e "$muacc_map_dir/$ifname" ]; then
                rm -f "$muacc_map_dir/$ifname"
        fi
        [ -d "$muacc_map_dir" ] || mkdir -p "$muacc_map_dir"
        printf %s "$conf" > "$muacc_map_dir/$ifname"
}

remove_muacc_map()
{
      if [ -e "$muacc_map_dir/$ifname" ]; then
              rm -f "$muacc_map_dir/$ifname"
      fi
}

if $if_up || [ "$reason" = ROUTERADVERT ]; then
        add_muacc_map
elif $if_down; then
        remove_muacc_map
fi

