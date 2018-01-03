#!/bin/bash

# Colors
ESC="\e["
RESET=$ESC"39m"
RED=$ESC"31m"
GREEN=$ESC"32m"
BLUE=$ESC"34m"

function banner {
echo "                             _                                          _       _ "
echo "  ___  _ __   ___           | |___      _____    _ __  _   _ _ __   ___| |__   / \\"
echo " / _ \| '_ \ / _ \          | __\ \ /\ / / _ \  | '_ \| | | | '_ \ / __| '_ \ /  /"
echo "| (_) | | | |  __/ ᕦ(ò_óˇ)ᕤ | |_ \ V  V / (_) | | |_) | |_| | | | | (__| | | /\_/ "
echo " \___/|_| |_|\___|           \__| \_/\_/ \___/  | .__/ \__,_|_| |_|\___|_| |_\/   "
echo "                                                |_|                               "
echo "                                                                   by superkojiman"
echo ""
}

function usage {
    echo "Usage: $0 [-t target IP | -f targets.txt] [-p tcp/udp/all] [-i interface] [-n nmap-options] [-l filepath] [-o output types] [-h]"
    echo "       -h: Help"
    echo "       -t: IP of target to scan (this or '-f' must be specified)."
    echo "       -f: File containing ip addresses to scan (one per line)."
    echo "       -p: Protocol. Defaults to tcp."
    echo "       -i: Network interface. Defaults to eth0."
    echo "       -n: Comma separated NMap options without hyphens (A,O,sV,etc). Defaults to no options."
    echo "       -l: Directory to save results to. Defaults to ~/.onetwopunch."
    echo "       -o: Filetype for reports. Multiple (comma separated) options can be specified. Defaults to Normal."
    echo "            n: Normal output format."
    echo "            x: XML output format."
    echo "            g: Grepable output format."
    echo "            a: All output formats."
    echo ""
}

function scans {
    echo -e "${BLUE}[+]${RESET} Scanning $ip for $proto ports..."

    # unicornscan identifies all open TCP ports
    if [[ $proto == "tcp" || $proto == "all" ]]; then
        echo -e "${BLUE}[+]${RESET} Obtaining all open TCP ports using unicornscan..."
        echo -e "${BLUE}[+]${RESET} unicornscan -i ${iface} -mT ${ip}:a -l ${log_dir}/udir/${ip}-tcp.txt"
        unicornscan -i ${iface} -mT ${ip}:a -l ${log_dir}/udir/${ip}-tcp.txt
        ports=$(cat "${log_dir}/udir/${ip}-tcp.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
        if [[ ! -z $ports ]]; then
            # nmap follows up
            echo -e "${GREEN}[*]${RESET} TCP ports for nmap to scan: $ports"
            ntcp+=" -p ${ports}"
            echo -e "${BLUE}[+]${RESET} $ntcp"
            $ntcp
        else
            echo -e "${RED}[!]${RESET} No TCP ports found"
        fi
    fi

    # unicornscan identifies all open UDP ports
    if [[ $proto == "udp" || $proto == "all" ]]; then
        echo -e "${BLUE}[+]${RESET} Obtaining all open UDP ports using unicornscan..."
        echo -e "${BLUE}[+]${RESET} unicornscan -i ${iface} -mU ${ip}:a -l ${log_dir}/udir/${ip}-udp.txt"
        unicornscan -i ${iface} -mU ${ip}:a -l ${log_dir}/udir/${ip}-udp.txt
        ports=$(cat "${log_dir}/udir/${ip}-udp.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
        if [[ ! -z $ports ]]; then
            # nmap follows up
            echo -e "${GREEN}[*]${RESET} UDP ports for nmap to scan: $ports"
            nudp+=" -sU -p ${ports}"
            echo -e "${BLUE}[+]${RESET} $nudp"
            $nudp
        else
            echo -e "${RED}[!]${RESET} No UDP ports found"
        fi
    fi
}

function clean {
    echo -e "${BLUE}[+]${RESET} Cleaning up..."
    rm -rf $log_dir/udir
    echo -e "${BLUE}[+]${RESET} Done cleaning!"
}

function build_scan {
    nscan="nmap -e ${iface} ${nmap_opt} ${ip}"

    #build nmap tcp command with output options
        #I'm sure there is a much better way to do this, but I am not a programmer...
    ntcp=$nscan
    if [[ $output == *"n"* ]]; then
        ntcp+=" -oN ${log_dir}/scans/${ip}-tcp.nmap"
    fi
    if [[ $output == *"x"* ]]; then
        ntcp+=" -oX ${log_dir}/scans${ip}-tcp.xml"
    fi
    if [[ $output == *"g"* ]]; then
        ntcp+=" -oG ${log_dir}/scans/${ip}-tcp.grep"
    fi
    if [[ $output == *"a"* ]]; then
        ntcp+=" -oA ${log_dir}/scans/${ip}-tcp"
    fi

    #build nmap udp command with output options
    nudp=$nscan
    if [[ $output == *"n"* ]]; then
        nudp+=" -oN ${log_dir}/scans/${ip}-udp.nmap"
    fi
    if [[ $output == *"x"* ]]; then
        nudp+=" -oX ${log_dir}/scans/${ip}-udp.xml"
    fi
    if [[ $output == *"g"* ]]; then
        nudp+=" -oG ${log_dir}/scans/${ip}-udp.grep"
    fi
    if [[ $output == *"a"* ]]; then
        nudp+=" -oA ${log_dir}/scans/${ip}-udp"
    fi

}

banner

if [[ ! $(id -u) == 0 ]]; then
    echo -e "${RED}[!]${RESET} This script must be run as root"
    exit 1
fi

if [[ -z $(which nmap) ]]; then
    echo -e "${RED}[!]${RESET} Unable to find nmap. Install it and make sure it's in your PATH environment"
    exit 1
fi

if [[ -z $(which unicornscan) ]]; then
    echo -e "${RED}[!]${RESET} Unable to find unicornscan. Install it and make sure it's in your PATH environment"
    exit 1
fi

if [[ -z $1 ]]; then
    usage
    exit 0
fi

# commonly used default options
proto="tcp"
iface="eth0"
nmap_opt=""
target=""
targets=""
log_dir="${HOME}/.onetwopunch"


while getopts "p:i:t:f:n:l:o:h" OPT; do
    case $OPT in
        p) proto=${OPTARG};;
        i) iface=${OPTARG};;
        t) target=${OPTARG};;
	f) targets=${OPTARG};;
        n) nmap_opt=${OPTARG};;
	l) log_dir=${OPTARG};;
        o) output=${OPTARG};;
        h) usage; exit 0;;
        *) usage; exit 0;;
    esac
done

#make sure a target is specified
if [[ -z $targets && -z $target ]]; then
    echo "[!] No target file provided"
    usage
    exit 1
fi

#make sure only one target option is used
if [[ -n $targets && -n $target ]]; then
    echo "[!] Please only specify one target option"
    usage
    exit 1
fi

#make sure the protocol is correct
if [[ ${proto} != "tcp" && ${proto} != "udp" && ${proto} != "all" ]]; then
    echo "[!] Unsupported protocol"
    usage
    exit 1
fi

# check if multiple nmap options were specified and format them
if [[ $nmap_opt == *","* ]]; then
    nmap_opt=$(echo -${nmap_opt} | sed 's/,/ -/g')
elif [[ -n $nmap_opt ]]; then
    nmap_opt=$(echo -${nmap_opt})
fi

# add subdirectory to log_dir and remove any trailing "/" characters
log_dir=$(echo ${log_dir} | sed 's/\/$//')
log_dir=$(echo "${log_dir}/onetwopunch")

echo -e "${BLUE}[+]${RESET} Protocol : ${proto}"
echo -e "${BLUE}[+]${RESET} Interface: ${iface}"
echo -e "${BLUE}[+]${RESET} Nmap opts: ${nmap_opt}"
if [[ -n $targets ]]; then					#use this if a target file is specified
	echo -e "${BLUE}[+]${RESET} Targets: ${targets}"
fi

if [[ -n $target ]]; then					#use this if only one target is specified
	echo -e "${BLUE}[+]${RESET} Target: ${target}"
fi
echo -e "${BLUE}[+]${RESET} Log dir: ${log_dir}"

#backup any old scans
if [[ -d ${log_dir}/scans ]]; then
    echo -e "${BLUE}[+]${RESET} Backing up old scans."
    mkdir -p "${log_dir}/backup-$(date "+%Y%m%d-%H%M")/"
    mv "${log_dir}/scans/" "${log_dir}/backup-$(date "+%Y%m%d-%H%M")/"
fi

#create needed directories
mkdir -p "${log_dir}/udir/"
mkdir -p "${log_dir}/scans/"

# if there are multiple targets (-f option)
if [[ -n $targets ]]; then
    while read ip; do
        build_scan
        scans
    done
elif [[ -n $target ]]; then
    ip=$target
    build_scan
    scans
else
    echo "${RED}[!]${RESET} Error dealing with the target/targets variables"
fi

echo -e "${BLUE}[+]${RESET} Scans completed"
clean
echo -e "${BLUE}[+]${RESET} Results saved to ${log_dir}"
