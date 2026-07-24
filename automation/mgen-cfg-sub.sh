
#
# This script emits vpp mgen commands into $vppconfig
# which is the VPP startup script on the remote VPPs.
#
# Use '--custom-vpp-config-script=mgen-cfg-sub.sh' argument to
# runtests.py to cause this script to be called on each of the
# remote VPP instances.
#
# See tfs-cfg-sub.sh for examples of variables that can be used
#
# Example invocation of runtests.py:
#
# venv ...
# runtests.py -w 5 -d 20 --testbed=A -v test_nop.py --native-crypto \
#     --dont-use-tfs --pause --dont-use-trex \
#     --custom-vpp-config-script=mgen-cfg-sub.sh
#

# ${vpp_ifnames[0])	connected to trex on trex host
# ${vpp_ifnames[1]}	connected to VPP peer
#
# $(make_v4v6_tfs_prefix $(get_tfs_intf_addr 0 1) local VPP peer Ip address
# $(get_tfs_remote_ip 0 1)	remote VPP peer IP address
#
# These next two values come from runtfs.py options:
#	-s|--iptfs-packet-size SIZE
#	-r|--rate RATE
#
# ${o_iptfs_packet_size} iptfs packet size (default 1500 i.e., MTU)
# ${o_tfs_ether_rate}	ethernet bitrate bits per second
# ${o_duration}		test duration in seconds
#
# We need to convert SIZE and RATE to corresponding values for mgen
#


prefix_me=$(make_v4v6_tfs_prefix $(get_tfs_intf_addr 0 1))
ipa_me="${prefix_me%/*}"

ipa_them=$(get_tfs_remote_ip 0 1)
port_src=8811
port_dst=8812

#
# Rate and size conversion
#
# The TFS rate and size runtests.py options are given in terms of line
# bitrate and MTU.
#
# mgen size is the udp/tcp payload size
# mgen rate is the number of payloads per second
#

# overhead:
#
# MTU relates to size of IP packet
# UDP header is 8 bytes
# TCP header is 20 bytes
# IPv4 header is 20 bytes
# Ethernet overhead: 36 bytes
#	8 bytes		preamble
#	14 bytes	header
#	4 bytes		FCS
#	12 bytes	inter-frame gap
#
# MTU=1500 means:
#    UDP payload is (1500-20-8 = 1472 bytes)
#    TCP payload is (1500-20-20 = 1460 bytes)
#
# bitrate 10Mb/s calculation:
#    assume MTU=1500, UDP
#
#    bits per payload = (MTU + 36) * 8 bits/byte
#    payloads per second = media_bitrate / bits_per_payload
#    mgen payload size = MTU - size(IPhdr) - size(l4hdr)
# 

#
# args:
#    mtu
#    medium_bitrate
#    l4_type		"tcp" or "udp"
#
# returns:
#    mgen_packet_rate	(payloads per second)
#    mgen_payload_size	(bytes per payload)
#
get_mgen_rate_size()
{
    MTU=$1
    MEDIUM_BITRATE=$2
    L4_TYPE=$3

    case "$L4_TYPE" in
    tcp)
	L4_OVH=20
	;;
    udp)
	L4_OVH=8
	;;
    *)
	echo "bad L4_TYPE: $L4_TYPE" >&2
	exit 1
	;;
    esac

    L2_OVH=36

    bits_per_payload=$(( ( $MTU + $L2_OVH ) * 8 ))
    payloads_per_second=$(( $MEDIUM_BITRATE / $bits_per_payload ))
    mgen_payload_size=$(( $MTU - 20 - $L4_OVH ))

    echo "$payloads_per_second" "$mgen_payload_size"
}

read -r mgen_rate mgen_size <<< "$(get_mgen_rate_size ${o_iptfs_packet_size} ${o_tfs_ether_rate} udp)"

echo "Calculated mgen rate: $mgen_rate"
echo "Calculated mgen size: $mgen_size"

# For mgen, we will probably rx and tx on ${vpp_ifnames[1]}

mgen_ontime=15
duration_integer="${o_duration%.*}"
mgen_offtime=$(( $mgen_ontime + ${duration_integer} ))

echo "Mgen ontime $mgen_ontime"
echo "Mgen offtime $mgen_offtime"

# Not sure if needed: below we append ".0" to mgen_ontime to force
# explicit floating-point format.

cat >> $vppconfig <<- EOF
mgen log /tmp/mgen_rx.log
mgen listen UDP $port_dst analytics window 5
mgen event ${mgen_ontime}.0 ON 1 UDP SRC $ipa_me/$port_src DST $ipa_them/$port_dst PERIODIC [$mgen_rate $mgen_size]
mgen event $mgen_offtime OFF 1
mgen start
EOF

