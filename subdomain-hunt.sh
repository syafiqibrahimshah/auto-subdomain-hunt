#!/bin/bash

url=$1
# fonts
bold=$(tput bold)
normal=$(tput sgr0)

if [ "$url" == "" ]; then
	echo "[-] domain required to run script"
	exit 1
fi

command -v assetfinder >/dev/null 2>&1 || { echo >&2 "[-] assetfinder required to run script.  Aborting."; exit 1; }
command -v amass >/dev/null 2>&1 || { echo >&2 "[-] amass required to run script.  Aborting."; exit 1; }
command -v sublist3r >/dev/null 2>&1 || { echo >&2 "[-] sublist3r required to run script.  Aborting."; exit 1; }
command -v subfinder >/dev/null 2>&1 || { echo >&2 "[-] subfinder required to run script.  Aborting."; exit 1; }
command -v httprobe >/dev/null 2>&1 || { echo >&2 "[-] httprobe required to run script.  Aborting."; exit 1; }
#command -v subjack >/dev/null 2>&1 || { echo >&2 "[-] subjack required to run script.  Aborting."; exit 1; }
#command -v wayback >/dev/null 2>&1 || { echo >&2 "[-] wayback required to run script.  Aborting."; exit 1; }
#command -v whatweb >/dev/null 2>&1 || { echo >&2 "[-] whatweb required to run script.  Aborting."; exit 1; }
#command -v meg >/dev/null 2>&1 || { echo >&2 "[-] meg required to run script.  Aborting."; exit 1; }
command -v eyewitness >/dev/null 2>&1 || { echo >&2 "[-] eyewitness required to run script.  Aborting."; exit 1; }
command -v nmap >/dev/null 2>&1 || { echo >&2 "[-] nmap required to run script.  Aborting."; exit 1; }

if [ ! -d "$url" ];then
	mkdir $url
fi

if [ ! -d "$url/recon" ];then
    mkdir $url/recon
fi

if [ ! -d "$url/recon/3rd-lvls" ];then
    mkdir $url/recon/3rd-lvls
fi

if [ ! -d "$url/recon/scans" ];then
    mkdir $url/recon/scans
fi

if [ ! -d "$url/recon/httprobe" ];then
    mkdir $url/recon/httprobe
fi

if [ ! -d "$url/recon/potential_takeovers" ];then
        mkdir $url/recon/potential_takeovers
fi

if [ ! -d "$url/recon/wayback" ];then
    mkdir $url/recon/wayback
fi

if [ ! -d "$url/recon/wayback/params" ];then
    mkdir $url/recon/wayback/params
fi

if [ ! -d "$url/recon/wayback/extensions" ];then
    mkdir $url/recon/wayback/extensions
fi

if [ ! -d "$url/recon/whatweb" ];then
    mkdir $url/recon/whatweb
fi

if [ ! -f "$url/recon/httprobe/alive.txt" ];then
    touch $url/recon/httprobe/alive.txt
fi

if [ ! -f "$url/recon/final.txt" ];then
    touch $url/recon/final.txt
fi

echo "[+] Harvesting subdomains with ${bold}assetfinder"
assetfinder $url | grep '.$url' | sort -u | tee -a $url/recon/unsorted-subdomains-list.txt

echo "[+] Harvesting more subdomains with ${bold}amass"
amass enum -d $url | tee -a $url/recon/unsorted-subdomains-list.txt

echo "[+] Harvesting more subdomains with ${bold}subfinder"
subfinder -d $url | tee -a $url/recon/unsorted-subdomains-list.txt

sort -u $url/recon/unsorted-subdomains-list.txt >> $url/recon/final.txt

echo "[+] Compile 3rd level domains"
cat $url/recon/final.txt | grep -Po '(\w+\.\w+\.\w+)$' | sort -u >> /$url/recon/3rd-lvl-domains.txt
for line in $(cat $url/recon/3rd-lvl-domains.txt);do echo $line | sort -u | tee -a $url/recon/final.txt;done

echo "[+] Harvesting 3rd level domains with ${bold}sublist3r"
for domain in $(cat $url/recon/3rd-lvl-domains.txt);do sublist3r -d $domain -o $url/recon/3rd-lvls/$domain.txt;done

echo "[+] Probing live domains with ${bold}httprobe"
cat $url/recon/final.txt | sort -u | httprobe -s -p https:443 | sed 's/https\?:\/\///' | tr -d ':443' | sort -u >> $url/recon/httprobe/alive.txt

echo "[+] Scanning domains with ${bold}whatweb"
for domain in $(cat /$url/recon/httprobe/alive.txt); do
    if [ ! -d  "$url/recon/whatweb/$domain" ];then
        mkdir $url/recon/whatweb/$domain
    fi
    if [ ! -d "$url/recon/whatweb/$domain/output.txt" ];then
        touch $url/recon/whatweb/$domain/output.txt
    fi
    if [ ! -d "$url/recon/whaweb/$domain/plugins.txt" ];then
        touch $url/recon/whatweb/$domain/plugins.txt
    fi
    echo "[*] Running whatweb on $domain $(date +'%Y-%m-%d %T')"
    whatweb -t 50 -v $domain >> $url/recon/whatweb/$domain/output.txt; sleep 3
done

echo "[+] Scanning for open ports with ${bold}nmap"
nmap -iL $url/recon/httprobe/alive.txt -T4 -oA $url/recon/scans/scanned.txt

echo "[+] Taking screenshots with ${bold} EyeWitness"
python3 EyeWitness/EyeWitness.py --web -f $url/recon/httprobe/alive.txt -d $url/recon/eyewitness --resolve
