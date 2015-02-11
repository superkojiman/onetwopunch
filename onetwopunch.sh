#!/bin/bash 

if [[ ! $(id -u) == 0 ]]; then
	echo "This script must be run as root!"
	exit 1
fi

NMAP_OPT="-A"
IFACE="wlp0s20u1"
MYDIR="$(dirname $0)"
TARGETS=""
PROTO="tcp"

function usage {
	echo "Usage: sudo $0 <interface> <targets> [proto] [nmap_args]"
	echo "	interface	Interface to use (e.g. eth0, wlp3s0, tap0 ...)"
	echo "	targets		File with line-delimited targets to scan"
	echo "	proto		Protocol to scan (tcp, udp, or all): default tcp"
	echo "	nmap_args	Additional arguments to pass to nmap: default -A"

	exit 1
}

# Set arguments
if [[ $# < 2 ]]; then usage; fi
IFACE=$1
TARGETS=$2
if [[ -n $3 ]]; then PROTO=$3; fi
if [[ -n $4 ]]; then NMAP_OPT=$4; fi

if [[ ! $PROTO == "tcp" && ! $PROTO == "udp" && ! $PROTO == "all" ]]; then
	echo "[!] Only valid protocol options are tcp, udp, or all"
	exit 1
fi

echo "[+] Interface set to ${IFACE}"
echo "[+] Target list set to ${TARGETS}"
echo "[+] Protocol set to ${PROTO}"
echo "[+] NMAP arguments set to ${NMAP_OPT}"

# backup any old scans before we start a new one
mkdir -p "${MYDIR}/backup/"
if [[ -d "${MYDIR}/ndir/" ]]; then 
	mv "${MYDIR}/ndir/" "${MYDIR}/backup/ndir-$(date "+%Y%m%d-%H%M%S")/"
fi
if [[ -d "${MYDIR}/udir/" ]]; then 
	mv "${MYDIR}/udir/" "${MYDIR}/backup/udir-$(date "+%Y%m%d-%H%M%S")/"
fi 

rm -rf "${MYDIR}/ndir/"
mkdir -p "${MYDIR}/ndir/"
rm -rf "${MYDIR}/udir/"
mkdir -p "${MYDIR}/udir/"

while read IP; do
	echo "[+] Scanning $IP for $PROTO ports..."

	# unicornscan identifies all open TCP ports
	if [[ $PROTO == "tcp" || $PROTO == "all" ]]; then 
		echo "[+] Obtaining all open TCP ports using unicornscan..."
		echo "[+] unicornscan -i ${IFACE} -mT ${IP}:a -l ${MYDIR}/udir/${IP}-tcp.txt"
		unicornscan -i ${IFACE} -mT ${IP}:a -l ${MYDIR}/udir/${IP}-tcp.txt
		PORTS=$(cat "${MYDIR}/udir/${IP}-tcp.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
		if [[ ! -z $PORTS ]]; then 
			# nmap follows up
			echo "[+] Ports for nmap to scan: $PORTS"
			echo "[+] nmap -e ${IFACE} ${NMAP_OPT} -oX ${MYDIR}/ndir/${IP}-tcp.xml -oG ${MYDIR}/ndir/${IP}-tcp.grep -p ${PORTS} ${IP}"
			nmap -e ${IFACE} ${NMAP_OPT} -oX ${MYDIR}/ndir/${IP}-tcp.xml -oG ${MYDIR}/ndir/${IP}-tcp.grep -p ${PORTS} ${IP}
		else
			echo "[!] No TCP ports found"
		fi
	fi

	# unicornscan identifies all open UDP ports
	if [[ $PROTO == "udp" || $PROTO == "all" ]]; then  
		echo "[+] Obtaining all open UDP ports using unicornscan..."
		echo "[+] unicornscan -i ${IFACE} -mU ${IP}:a -l ${MYDIR}/udir/${IP}-udp.txt"
		unicornscan -i ${IFACE} -mU ${IP}:a -l ${MYDIR}/udir/${IP}-udp.txt
		ports=$(cat "${MYDIR}/udir/${IP}-udp.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
		if [[ ! -z $PORTS ]]; then
			# nmap follows up
			echo "[+] nmap -e ${IFACE} -sU -oX ${MYDIR}/ndir/${IP}-udp.xml -oG ${MYDIR}/ndir/${IP}-udp.grep -p ${PORTS} ${IP}"
			nmap -e ${IFACE} -sU -oX ${MYDIR}/ndir/${IP}-udp.xml -oG ${MYDIR}/ndir/${IP}-udp.grep -p ${PORTS} ${IP}
		else
			echo "[!] No UDP ports found"
		fi
	fi
done < ${TARGETS}

echo "[+] Scans completed"

