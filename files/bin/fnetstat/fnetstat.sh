#!/bin/sh
# Netmon Nodewatcher (C) 2010-2011 Freifunk Oldenburg
# Update from Wermelskirchen by RubenKelevra 2012 - cyrond@gmail.com
# Lizenz: GPL

MESH_INTERFACE="br-freifunk"
CLIENT_INTERFACES="wlan0"
BRCTL="/bin/brctl_ff"

echo "{"

echo "\"sys:script\": \"v0.5\","
echo "\"type\": \"minutly\","
#hostnamen ausgeben
output=`cat /proc/sys/kernel/hostname`
echo "\"sys:hostname\": \"$output\","
#IPv6 Adresse Global
output=`ifconfig $MESH_INTERFACE | grep Scope:Global | awk '{ print $3 }' | sed -e 's/\/64//g'`
echo "\"sys:ip6:global\": \"$output\","
#IPv6 Adresse Link
output=`ifconfig $MESH_INTERFACE | grep Scope:Link | awk '{ print $3 }' | sed -e 's/\/64//g'`
echo "\"sys:ip6:link\": \"$output\","
#IPv4 Adresse
output=`ifconfig $MESH_INTERFACE | grep 'inet addr' | awk '{ print $2}' | sed -e 's/addr://g'`
echo "\"sys:ip4\": \"$output\","
#uptime, localtime & idletime
output=`cat /proc/uptime | awk '{ print $1 }'`
echo "\"sys:uptime\": $output,"
output=`date -Iseconds`
echo "\"sys:localtime\": \"$output\","
output=`cat /proc/uptime | awk '{ print $2 }'`
echo "\"sys:idletime\": $output,"
#sysinfo memory
echo "\"sys:memory\": {"
output=`cat /proc/meminfo | grep 'MemTotal' | awk '{ print $2 }'`
echo "  \"total\": $output,"
output=`cat /proc/meminfo | grep -m 1 'Cached:' | awk '{ print $2 }'`
echo "  \"caching\": $output,"
output=`cat /proc/meminfo | grep 'Buffers' | awk '{ print $2 }'`
echo "  \"buffering\": $output,"
output=`cat /proc/meminfo | grep 'MemFree' | awk '{ print $2 }'`
echo "  \"free\": $output"
echo "  },"
output=`cat /proc/loadavg | awk '{ print $4 }'`
echo "\"sys:processes\": \"$output\","
output=`cat /proc/loadavg | awk '{ print $1 }'`
echo "\"sys:loadavg\": $output,"

IFACES=`cat /proc/net/dev | awk -F: '!/\|/ { gsub(/[[:space:]]*/, "", $1); split($2, a, " "); printf("%s=%s=%s=%s ", $1, a[1], a[9], a[4]) }'`
echo "\"traffic\": ["

b="0"
for entry in $IFACES; do
	if [ $b -eq "1" ]; then
		echo ","
	fi
	echo -en "  {"
	iface=`echo $entry | cut -d '=' -f 1`
	echo " \"interface\": \"$iface\","
	rx=`echo $entry | cut -d '=' -f 2`
	echo "    \"rx\": $rx,"
	tx=`echo $entry | cut -d '=' -f 3`
	echo "    \"tx\": $tx,"
	drop=`echo $entry | cut -d '=' -f 4`
	echo "    \"drop\": $drop"
	echo -en "  }"
	b="1"
done

if [ $b -eq "1" ]; then
	echo ""
fi

echo "  ],"

#B.A.T.M.A.N. advanced
if which batctl >/dev/null; then
	BAT_ADV_ORIGINATORS=`batctl o | grep 'No batman nodes in range'`
	if [ "$BAT_ADV_ORIGINATORS" == "" ]; then
		OLDIFS=$IFS
		IFS="
"
		
		BAT_ADV_ORIGINATORS=`batctl o | grep 'wlan0-1' | awk '/O/ {next} /B/ {next} {print}'`
		echo "\"batman\": ["
		b="0"
		
		for row in $BAT_ADV_ORIGINATORS; do
			originator=`echo $row | awk '{print $1}'`
			next_hop=`echo $row | awk '{print $4}'`
			last_seen=`echo $row | awk '{print $2}'`
			last_seen="${last_seen//s/}"
			link_quality=`echo $row | awk '{print $3}'`
			link_quality="${link_quality//(/}"
			link_quality="${link_quality//)/}"
			
			if [ "$next_hop" == "$originator" ]; then
				if [ $b -eq "1" ]; then
					echo ","
				fi
				echo -en "  {"
				echo " \"originator\": \"$originator\","
				echo "    \"last_seen\": \"$last_seen\","
				echo "    \"linkquality\": \"$link_quality\","
				echo -en "  }"
				b="1"
			fi
		done
		
		if [ $b -eq "1" ]; then
			echo ""
		fi

		echo "  ],"
		
		IFS=$OLDIFS
	fi
fi

if which $BRCTL >/dev/null; then

	#CLIENTS
	SEDDEV=`$BRCTL showstp $MESH_INTERFACE | egrep '\([0-9]\)' | sed -e "s/(//;s/)//" | awk '{ print "s/^  "$2"/"$1"/;" }'`
		
	for entry in $CLIENT_INTERFACES; do
		CLIENT_MACS=$CLIENT_MACS`$BRCTL showmacs $MESH_INTERFACE | sed -e "$SEDDEV" | awk '{if ($3 != "yes" && $1 == "'"$entry"'") print $2}'`" "
	done
						
	output=0
	for client in $CLIENT_MACS; do
		output=`expr $i + 1`  #Z�hler um eins erh�hen
	done
	echo "\"ap:clients\": $output"

else
	echo "\"E: BRCTL missing\": \"yes\""
fi

echo "}"