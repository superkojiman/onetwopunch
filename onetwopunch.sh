#!/bin/bash 

NMAP_OPT=""	# additional nmap options like -O, -A, etc
IFACE="eth0"

if [[ -z $1 ]]; then 
	echo "usage $0 network-list [tcp/udp/all]";
	exit
fi

mode=""
if [[ -z $2 ]]; then 
	mode="tcp"
else
	mode=$2
fi

# backup any old scans before we start a new one
mkdir -p backup
if [[ -d ndir ]]; then 
	mv ndir backup/ndir-$(date "+%Y%m%d-%H%M%S")
fi
if [[ -d udir ]]; then 
	mv udir backup/udir-$(date "+%Y%m%d-%H%M%S")
fi 

rm -rf ndir
mkdir -p ndir
rm -rf udir
mkdir -p udir

for ip in $(cat $1); do 
	echo "[+] scanning $ip for $mode ports..."

	# unicornscan identifies all open TCP ports
	if [[ $mode == "tcp" || $mode == "all" ]]; then 
		echo "[+] obtaining all open TCP ports using unicornscan..."
		echo "[+] unicornscan -msf ${ip}:a -l udir/${ip}-tcp.txt"
		unicornscan -i ${IFACE} -msf ${ip}:a -l udir/${ip}-tcp.txt
		ports=$(cat udir/${ip}-tcp.txt | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
		if [[ ! -z $ports ]]; then 
			# nmap follows up
			echo "[+] ports for nmap to scan: $ports"
			echo "[+] nmap -sV -oX ndir/${ip}-tcp.xml -oG ndir/${ip}-tcp.grep -p ${ports} ${ip}"
			nmap -e ${IFACE} -sV ${NMAP_OPT} -oX ndir/${ip}-tcp.xml -oG ndir/${ip}-tcp.grep -p ${ports} ${ip}
		else
			echo "[!] no TCP ports found"
		fi
	fi
	# unicornscan identifies all open UDP ports
	if [[ $mode == "udp" || $mode == "all" ]]; then  
		echo "[+] obtaining all open UDP ports using unicornscan..."
		echo "[+] unicornscan -mU ${ip}:a -l udir/${ip}-udp.txt"
		unicornscan -i ${IFACE} -mU ${ip}:a -l udir/${ip}-udp.txt
		ports=$(cat udir/${ip}-udp.txt | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
		if [[ ! -z $ports ]]; then
			# nmap follows up
			echo "[+] nmap -sU -oX ndir/${ip}-udp.xml -oG ndir/${ip}-udp.grep -p ${ports} ${ip}"
			nmap -e ${IFACE} -sU -oX ndir/${ip}-udp.xml -oG ndir/${ip}-udp.grep -p ${ports} ${ip}
		else
			echo "[!] no UDP ports found"
		fi
	fi
done
echo "[+] scans completed"