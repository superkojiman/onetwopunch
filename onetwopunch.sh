#!/bin/bash

# Colors
ESC="\e["
RESET=$ESC"39m"
RED=$ESC"31m"
GREEN=$ESC"32m"
YELLOW=$ESC"33m"
BLUE=$ESC"34m"

#global variables for found ports
TCP_PORTS=""
UDP_PORTS=""
HTTP_PORTS=""

#global variables for options (set to defaults)
proto="tcp"
iface="eth0"
nmap_opt=""
target=""
targets=""
log_dir="${HOME}/.onetwopunch"
output="n"
web="0"



function banner {
echo "                             _                                          _       _  "
echo "  ___  _ __   ___           | |___      _____    _ __  _   _ _ __   ___| |__   / \\"
echo " / _ \| '_ \ / _ \          | __\ \ /\ / / _ \  | '_ \| | | | '_ \ / __| '_ \ /  / "
echo "| (_) | | | |  __/ ᕦ(ò_óˇ)ᕤ | |_ \ V  V / (_) | | |_) | |_| | | | | (__| | | /\_/  "
echo " \___/|_| |_|\___|           \__| \_/\_/ \___/  | .__/ \__,_|_| |_|\___|_| |_\/    "
echo "                                                |_|                                "
echo "                                                                   by superkojiman "
echo ""
}

function usage {
    echo "Usage: $0 [-t target IP | -f targets.txt] [-p tcp/udp/all] [-i interface] [-n nmap-options] [-l filepath] [-o output types] [-w] [-h]"
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
    echo "       -w: Send any identified HTTP ports to Nikto."
    echo ""
}

#set up directories and stuff
function prep {
    # check if multiple nmap options were specified and format them
    if [[ $nmap_opt == *","* ]]; then
        nmap_opt=$(echo -${nmap_opt} | sed 's/,/ -/g')
    elif [[ -n $nmap_opt ]]; then
        nmap_opt=$(echo -${nmap_opt})
    fi

    #create a banner section for the output format
    if [[ $output == *","* ]]; then
        banner_out=$(echo ${output} | sed 's/,/, /g')
    else
        banner_out=$output
    fi

    # add subdirectory to log_dir and remove any trailing "/" characters
    log_dir=$(echo ${log_dir} | sed 's/\/$//')
    log_dir=$(echo "${log_dir}/onetwopunch")

    #backup any old scans
    if [[ -d ${log_dir}/scans ]]; then
        echo -e "${BLUE}[+]${RESET} Backing up old scans."
        echo ""
        mkdir -p "${log_dir}/backup-$(date "+%Y%m%d-%H%M")/"
        mv "${log_dir}/scans/" "${log_dir}/backup-$(date "+%Y%m%d-%H%M")/"
    fi

    #create needed directories
    mkdir -p "${log_dir}/tmp_dir/"
    mkdir -p "${log_dir}/scans/"

}

#do basic error checking
function error_check {
    #check for root permissions
    if [[ ! $(id -u) == 0 ]]; then
        echo -e "${RED}[!]${RESET} This script must be run as root"
        exit 1
    fi

    #check for nmap
    if [[ -z $(which nmap) ]]; then
        echo -e "${RED}[!]${RESET} Unable to find nmap. Install it and make sure it's in your PATH environment"
        exit 1
    fi

    #check for unicornscan
    if [[ -z $(which unicornscan) ]]; then
        echo -e "${RED}[!]${RESET} Unable to find unicornscan. Install it and make sure it's in your PATH environment"
        exit 1
    fi

    #check for Nikto if a web scan is requested
    if [[ $web == 1 ]]; then
        if [[ -z $(which nikto) ]]; then
            echo -e "${RED}[!]${RESET} Unable to find Nikto. Install it and make sure it's in your PATH environment"
            exit 1
        fi
    fi

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

}

#make a banner showing selected scan options
function scan_banner {
    echo -e "${BLUE}[+]${RESET} Protocol:	${proto}"
    echo -e "${BLUE}[+]${RESET} Interface:	${iface}"
    echo -e "${BLUE}[+]${RESET} Nmap opts:	${nmap_opt}"
    echo -e "${BLUE}[+]${RESET} Log dir:	${log_dir}"
    echo -e "${BLUE}[+]${RESET} Output:	${banner_out}"
    if [[ -n $targets ]]; then					#use this if a target file is specified
        echo -e "${BLUE}[+]${RESET} Targets:	${targets}"
    fi

    if [[ -n $target ]]; then					#use this if only one target is specified
        echo -e "${BLUE}[+]${RESET} Target:	${target}"
    fi
    echo ""

}

#make function for processing type of scan ('cuz I didn't want to write it twice...)
function trigger_scan {
    if [[ $proto == "udp" ]]; then
        get_udp
        echo ""

        #only run Nmap scan if ports are found
	if [[ $UDP_PORTS == "" ]]; then
            echo -e "${RED}[!]${RESET} No UDP ports found, skipping Nmap scan..."
            echo ""
        else
            scan
        fi

    elif [[ $proto == "tcp" ]]; then
        get_tcp
        echo ""

        #only run Nmap scan if ports are found
        if [[ $TCP_PORTS == "" ]]; then
            echo -e "${RED}[!]${RESET} No TCP ports found, skipping Nmap scan..."
            echo ""
        else
            scan
        fi

    elif [[ $proto == "all" ]]; then
        get_udp
        echo ""
        get_tcp
        echo ""

        #only run Nmap scan if ports are found
        if [[ $UDP_PORTS == "" && $TCP_PORTS == "" ]]; then
            echo -e "${RED}[!]${RESET} No UDP or TCP ports found, skipping Nmap scan..."
            echo ""
        else
            scan
        fi

    else
        echo "${RED}[!]${RESET} Error triggering scans"
    fi

    #if web scan is requested
    if [[ $web == 1 ]]; then
        web_scan
    fi

}




#-------------- BEGIN SCANS --------------


#use unicornscan to get udp ports (if only udp was specified)
function get_udp {
    echo -e "${BLUE}[+]${RESET} Scanning $ip for UDP ports..."
    echo -e "${GREEN}[+]${RESET} unicornscan -i ${iface} -mU ${ip}:a -l ${log_dir}/tmp_dir/${ip}-udp.txt"

    unicornscan -i ${iface} -mU ${ip}:a -l ${log_dir}/tmp_dir/${ip}-udp.txt

    #get found ports from scan
    UDP_PORTS=$(cat "${log_dir}/tmp_dir/${ip}-udp.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',' | sed 's/,$//')
    echo -e "${YELLOW}[-]${RESET}	UDP Ports: ${UDP_PORTS}"

}

#use unicornscan to get tcp ports (if only tcp was specified)
function get_tcp {
    echo -e "${BLUE}[+]${RESET} Scanning $ip for TCP ports..."
    echo -e "${GREEN}[+]${RESET} unicornscan -i ${iface} -mT ${ip}:a -l ${log_dir}/tmp_dir/${ip}-tcp.txt"

    unicornscan -i ${iface} -mT ${ip}:a -l ${log_dir}/tmp_dir/${ip}-tcp.txt

    #get found ports from scan
    TCP_PORTS=$(cat "${log_dir}/tmp_dir/${ip}-tcp.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',' | sed 's/,$//')
    echo -e "${YELLOW}[-]${RESET}	TCP Ports: ${TCP_PORTS}"

    #if a web scan is selected, get the ports (if any)
    if [[ $web == 1 ]]; then
        HTTP_PORTS=$(cat "${log_dir}/tmp_dir/${ip}-tcp.txt" | grep http | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',' | sed 's/,$//')
        echo -e "${YELLOW}[-]${RESET}	HTTP Ports: ${HTTP_PORTS}"
        echo ""
    fi

}

#use nmap to scan found ports
function scan {
    #set base nmap scan
    nscan="nmap -e ${iface} ${nmap_opt} ${ip}"

    #ADD PROTOCOL SWITCH----------
    #only UDP scan
    if [[ $UDP_PORTS != "" && $TCP_PORTS == "" ]]; then
        nscan+=" -sU -p ${UDP_PORTS}"
    fi

    #only TCP scan
    if [[ $UDP_PORTS == "" && $TCP_PORTS != "" ]]; then
        nscan+=" -sT -p ${TCP_PORTS}"
    fi

    #UDP and TCP scan
    if [[ $UDP_PORTS != "" && $TCP_PORTS != "" ]]; then
        nscan+=" -sU -sT -pT:${TCP_PORTS},U:${UDP_PORTS}"
    fi

    #ADD OUTPUT TYPES----------
    #add "normal" output
    if [[ $output == *"n"* ]]; then
        nscan+=" -oN ${log_dir}/scans/${ip}.nmap"
    fi

    #add xml output
    if [[ $output == *"x"* ]]; then
        nscan+=" -oX ${log_dir}/scans${ip}.xml"
    fi

    #add "greppable" output
    if [[ $output == *"g"* ]]; then
        nscan+=" -oG ${log_dir}/scans/${ip}.grep"
    fi

    #output in all formats
    if [[ $output == *"a"* ]]; then
        nscan+=" -oA ${log_dir}/scans/${ip}"
    fi

    echo -e "${GREEN}[+]${RESET} ${nscan}"
    echo ""

    $nscan > ${log_dir}/tmp_dir/tmp.txt

    print

}

function web_scan {
    if [[ $HTTP_PORTS == "" ]]; then
        echo -e "${RED}[!]${RESET} No HTTP ports found, skipping Nikto scan..."
    else
        echo -e "${BLUE}[+]${RESET} Scanning HTTP ports with Nikto..."
        echo -e "${GREEN}[+]${RESET} nikto -output ${log_dir}/scans/${ip}.html -h ${ip} -p ${HTTP_PORTS}"
        echo ""

        nikto -output ${log_dir}/scans/${ip}-nikto.html -ask no -h ${ip} -p ${HTTP_PORTS} > ${log_dir}/tmp_dir/nik_tmp.txt

        while read line; do
            echo "	${line}"
        done <${log_dir}/tmp_dir/nik_tmp.txt
        echo ""

    fi

}


#-------------- END SCANS --------------

#print results from scans
function print {
    while read line; do
        echo "	${line}"
    done <${log_dir}/tmp_dir/tmp.txt
    echo ""

}

#remove tmp directory
function clean {
    echo -e "${BLUE}[+]${RESET} Cleaning up..."
    rm -rf $log_dir/tmp_dir
    chmod -R o+w $log_dir				#let other users delete scans, it was annoying to have to sudo
    echo -e "${BLUE}[+]${RESET} Done cleaning!"
    echo ""

}



######################################################
#----------------------- MAIN -----------------------#
######################################################

banner

#print usage if no options are specified
if [[ -z $1 ]]; then
    usage
    exit 0
fi

#process user options
while getopts "p:i:t:f:n:l:o:w:h" OPT; do
    case $OPT in
        p) proto=${OPTARG};;
        i) iface=${OPTARG};;
        t) target=${OPTARG};;
        f) targets=${OPTARG};;
        n) nmap_opt=${OPTARG};;
        l) log_dir=${OPTARG};;
        o) output=${OPTARG};;
        w) web=1;;
        h) usage; exit 0;;
        *) usage; exit 0;;
    esac
done

error_check
prep

#split into single target (-t) and multiple targets (-f)
if [[ -n $targets ]]; then
    #multiple targets are specified, repeat for each target
    scan_banner
    while read ip; do
        echo -e "${YELLOW}[-]${RESET} Currently scanning: ${ip}"
	echo ""
        #do scan stuff
        trigger_scan
    done <${targets}

    echo -e "${BLUE}[+]${RESET} Scans completed"
    echo ""
    echo -e "${BLUE}[+]${RESET} Results saved to ${log_dir}"
    clean

elif [[ -n $target ]]; then
    #single target is specified
    ip=$target

    #do scan stuff
    scan_banner
    trigger_scan
    echo -e "${BLUE}[+]${RESET} Scans completed"
    echo ""
    echo -e "${BLUE}[+]${RESET} Results saved to ${log_dir}"
    clean

else
    #ERROR
    echo "${RED}[!]${RESET} Error dealing with the target/targets variables!"
    exit 1
fi

