#!/bin/bash

# Initialize all necessary variables
export tmpVER=''
export tmpDIST=''
export tmpURL=''
export tmpWORD=''
export tmpMirror=''
export ipAddr=''
export ipMask=''
export ipGate=''
export ipDNS='1.1.1.1'
export IncDisk='default'
export interface=''
export interfaceSelect=''
export Release=''
export sshPORT='22'
export ddMode='0'
export setNet='0'
export setRDP='0'
export setIPv6='0'
export isMirror='0'
export FindDists='0'
export loaderMode='0'
export IncFirmware='0'
export distributionPackage='0'
export setInterfaceName='0'
export UNKNOWHW='0'
export UNVER='6.4'
export GRUBDIR=''
export GRUBFILE=''
export GRUBVER=''
export VER=''
export setCMD=''
export setConsole=''

# Parse command line arguments using case statements
while [[ $# -ge 1 ]]; do
  case $1 in
    -v|--ver)
      shift
      tmpVER="$1"
      shift
      ;;
    -d|--debian)
      shift
      Release='Debian'
      tmpDIST="$1"
      shift
      ;;
    -u|--ubuntu)
      shift
      Release='Ubuntu'
      tmpDIST="$1"
      shift
      ;;
    -c|--centos)
      shift
      Release='CentOS'
      tmpDIST="$1"
      shift
      ;;
    -dd|--image)
      shift
      ddMode='1'
      tmpURL="$1"
      shift
      ;;
    -p|--password)
      shift
      tmpWORD="$1"
      shift
      ;;
    -i|--interface)
      shift
      interfaceSelect="$1"
      shift
      ;;
    --ip-addr)
      shift
      ipAddr="$1"
      shift
      ;;
    --ip-mask)
      shift
      ipMask="$1"
      shift
      ;;
    --ip-gate)
      shift
      ipGate="$1"
      shift
      ;;
    --ip-dns)
      shift
      ipDNS="$1"
      shift
      ;;
    --dev-net)
      shift
      setInterfaceName='1'
      ;;
    --loader)
      shift
      loaderMode='1'
      ;;
    -apt|-yum|--mirror)
      shift
      isMirror='1'
      tmpMirror="$1"
      shift
      ;;
    -rdp)
      shift
      setRDP='1'
      WinRemote="$1"
      shift
      ;;
    -cmd)
      shift
      setCMD="$1"
      shift
      ;;
    -console)
      shift
      setConsole="$1"
      shift
      ;;
    -firmware)
      shift
      IncFirmware="1"
      ;;
    -port)
      shift
      sshPORT="$1"
      shift
      ;;
    --noipv6)
      shift
      setIPv6='1'
      ;;
    -a|--auto|-m|--manual|-ssl)
      shift
      ;;
    *)
      if [[ "$1" != 'error' ]]; then 
        echo -ne "\nInvalid option: '$1'\n\n"; 
      fi
      
      echo -ne " Usage:\n\tbash $(basename $0)\t-d/--debian [\033[33m\033[04mdists-name\033[0m]\n\t\t\t\t-u/--ubuntu [\033[04mdists-name\033[0m]\n\t\t\t\t-c/--centos [\033[04mdists-name\033[0m]\n\t\t\t\t-v/--ver [32/i386|64/\033[33m\033[04mamd64\033[0m] [\033[33m\033[04mdists-verison\033[0m]\n\t\t\t\t--ip-addr/--ip-gate/--ip-mask\n\t\t\t\t-apt/-yum/--mirror\n\t\t\t\t-dd/--image\n\t\t\t\t-p [linux password]\n\t\t\t\t-port [linux ssh port]\n"
      exit 1;
      ;;
    esac
  done

# Check whether the script is running as root
[[ "$EUID" -ne '0' ]] && echo -e "\e[31mError:\e[0m This script can only be executed with root privileges." && exit 1;

# Define a function to check for dependencies
function checkDependencies(){
  Full='0';
  for BIN_DEP in `echo "$1" |sed 's/,/\n/g'`
  do
    if [[ -n "$BIN_DEP" ]]; then
      Found='0';
      for BIN_PATH in `echo "$PATH" |sed 's/:/\n/g'`
      do
        ls $BIN_PATH/$BIN_DEP >/dev/null 2>&1;
        if [ $? == '0' ]; then
          Found='1';
          break;
        fi
      done
      if [ "$Found" == '1' ]; then
        echo -en "[\033[32mOk\033[0m]\t";
      else
        Full='1';
        echo -en "[\033[31mNot Installed\033[0m]";
      fi
      echo -en "\t$BIN_DEP\n";
    fi
  done
  if [ "$Full" == '1' ]; then
    echo -ne "\n\033[31mError! \033[0mPlease use '\033[33mapt\033[0m' or '\033[33myum\033[0m' to install the missing dependencies.\n\n\n"
    exit 1;
  fi
}

# Define a function to select the mirror
function selectMirror(){
  [ $# -ge 3 ] || exit 1
  
  Release=$(echo "$1" |sed -r 's/(.*)/\L\1/')
  DIST=$(echo "$2" |sed 's/\ //g' |sed -r 's/(.*)/\L\1/')
  VER=$(echo "$3" |sed 's/\ //g' |sed -r 's/(.*)/\L\1/')
  New=$(echo "$4" |sed 's/\ //g')
  
  [ -n "$Release" ] && [ -n "$DIST" ] && [ -n "$VER" ] || exit 1
  
  if [ "$Release" == "debian" ] || [ "$Release" == "ubuntu" ]; then
    [ "$DIST" == "focal" ] && legacy="legacy-" || legacy=""
    TEMP="SUB_MIRROR/dists/${DIST}/main/installer-${VER}/current/${legacy}images/netboot/${Release}-installer/${VER}/initrd.gz"
  elif [ "$Release" == "centos" ]; then
    TEMP="SUB_MIRROR/${DIST}/os/${VER}/isolinux/initrd.img"
  fi
  
  [ -n "$TEMP" ] || exit 1
  
  mirrorStatus=0
  declare -A MirrorBackup
  MirrorBackup=(["debian0"]="" ["debian1"]="http://deb.debian.org/debian" ["debian2"]="http://archive.debian.org/debian" ["ubuntu0"]="" ["ubuntu1"]="http://archive.ubuntu.com/ubuntu" ["ubuntu2"]="http://ports.ubuntu.com" ["centos0"]="" ["centos1"]="http://mirror.centos.org/centos" ["centos2"]="http://vault.centos.org")
  
  echo "$New" |grep -q '^http://\|^https://\|^ftp://' && MirrorBackup[${Release}0]="$New"
  
  for mirror in $(echo "${!MirrorBackup[@]}" |sed 's/\ /\n/g' |sort -n |grep "^$Release")
    do
      Current="${MirrorBackup[$mirror]}"
      [ -n "$Current" ] || continue
      MirrorURL=`echo "$TEMP" |sed "s#SUB_MIRROR#${Current}#g"`
      wget --no-check-certificate --spider --timeout=3 -o /dev/null "$MirrorURL"
      [ $? -eq 0 ] && mirrorStatus=1 && break
    done
  
  [ $mirrorStatus -eq 1 ] && echo "$Current" || exit 1
}

# Define a function to calculate netmask
function netmask() {
  n="${1:-32}"
  b=""
  m=""
  
  for((i=0;i<32;i++)){
    [ $i -lt $n ] && b="${b}1" || b="${b}0"
  }
  
  for((i=0;i<4;i++)){
    s=`echo "$b"|cut -c$[$[$i*8]+1]-$[$[$i+1]*8]`
    [ "$m" == "" ] && m="$((2#${s}))" || m="${m}.$((2#${s}))"
  }
  
  echo "$m"
}

# Define a function to get the current network interface
function getInterface(){
  interface=""
  Interfaces=`cat /proc/net/dev |grep ':' |cut -d':' -f1 |sed 's/\s//g' |grep -iv '^lo\|^sit\|^stf\|^gif\|^dummy\|^vmnet\|^vir\|^gre\|^ipip\|^ppp\|^bond\|^tun\|^tap\|^ip6gre\|^ip6tnl\|^teql\|^ocserv\|^vpn'`
  defaultRoute=`ip route show default |grep "^default"`
  
  for item in `echo "$Interfaces"`
    do
      [ -n "$item" ] || continue
      echo "$defaultRoute" |grep -q "$item"
      [ $? -eq 0 ] && interface="$item" && break
    done
  
  echo "$interface"
}

# Define a function to get the first available disk
function getDisk(){
  disks=`lsblk | sed 's/[[:space:]]*$//g' |grep "disk$" |cut -d' ' -f1 |grep -v "fd[0-9]*\|sr[0-9]*" |head -n1`
  [ -n "$disks" ] || echo ""
  echo "$disks" |grep -q "/dev"
  [ $? -eq 0 ] && echo "$disks" || echo "/dev/$disks"
}

# Define a function to get the disk type
function diskType(){
  echo `udevadm info --query all "$1" 2>/dev/null |grep 'ID_PART_TABLE_TYPE' |cut -d'=' -f2`
}

# Define a function to get the path to the GRUB configuration file
function getGrub(){
  Boot="${1:-/boot}"
  folder=`find "$Boot" -type d -name "grub*" 2>/dev/null |head -n1`
  [ -n "$folder" ] || return
  fileName=`ls -1 "$folder" 2>/dev/null |grep '^grub.conf$\|^grub.cfg$'`
  if [ -z "$fileName" ]; then
    ls -1 "$folder" 2>/dev/null |grep -q '^grubenv$'
    [ $? -eq 0 ] || return
    folder=`find "$Boot" -type f -name "grubenv" 2>/dev/null |xargs dirname |grep -v "^$folder" |head -n1`
    [ -n "$folder" ] || return
    fileName=`ls -1 "$folder" 2>/dev/null |grep '^grub.conf$\|^grub.cfg$'`
  fi
  [ -n "$fileName" ] || return
  [ "$fileName" == "grub.cfg" ] && ver="0" || ver="1"
  echo "${folder}:${fileName}:${ver}"
}

# Check if system memory is low
function lowMem(){
  # Get total memory and store it in mem variable
  mem=`grep "^MemTotal:" /proc/meminfo 2>/dev/null | grep -o "[0-9]*"`

  # If mem variable is empty, return 0
  [ -n "$mem" ] || return 0

  # If mem variable is less than or equal to 524288 KB (512 MB), return 1, else return 0
  [ "$mem" -le "524288" ] && return 1 || return 0
}

# Check if loader mode is 0
if [[ "$loaderMode" == "0" ]]; then
  # Get Grub path and version from "/boot"
  Grub=`getGrub "/boot"`
  # If Grub is not found, print error message and exit with status 1
  [ -z "$Grub" ] && echo -e "\e[31mError:\e[0m GRUB bootloader was not found." && exit 1;
  # Extract Grub directory, file, and version
  GRUBDIR=`echo "$Grub" |cut -d':' -f1`
  GRUBFILE=`echo "$Grub" |cut -d':' -f2`
  GRUBVER=`echo "$Grub" |cut -d':' -f3`
fi

# If Release variable is empty, set it to "Debian"
[ -n "$Release" ] || Release='Debian'
# Convert Release to lowercase and remove whitespace
linux_release=$(echo "$Release" |sed 's/\ //g' |sed -r 's/(.*)/\L\1/')

# Clear terminal and print message indicating dependencies are being checked
clear && echo -e "\n\033[36m# Checking dependencies\033[0m\n"

# If ddMode is 1, check for iconv dependency and set temporary variables
if [[ "$ddMode" == '1' ]]; then
  checkDependencies iconv;
  linux_release='debian';
  tmpDIST='bullseye';
  tmpVER='amd64';
fi

# Set network configuration if IP address, subnet mask, and gateway are not empty
if [ -n "$ipAddr" ] && [ -n "$ipMask" ] && [ -n "$ipGate" ]; then
  setNet='1'
fi

# If network configuration is not set, check for dependencies and set IP address, subnet mask, gateway, and DNS server
if [ "$setNet" == "0" ]; then
  checkDependencies ip

  # If interface is not set, get it using getInterface function
  if [ -z "$interface" ]; then
    interface=$(getInterface)
  fi

  # Get IP address, subnet mask, and gateway from interface
  iAddr=$(ip addr show dev "$interface" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+')
  ipAddr=$(echo "$iAddr" | cut -d'/' -f1)
  ipMask=$(netmask "$(echo "$iAddr" | cut -d'/' -f2)")
  ipGate=$(ip route show default | grep -oE '^default .*' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
fi

# If interface is not set, check for dependencies and get it using getInterface function
if [ -z "$interface" ]; then
  checkDependencies ip
  interface=$(getInterface)
fi

# Set IPv4, subnet mask, gateway, and DNS server
IPv4="$ipAddr"
MASK="$ipMask"
GATE="$ipGate"

# If any of IPv4, subnet mask, gateway, or DNS server is empty, print error message, execute script with "error" argument, and exit with status 1
if [ -z "$IPv4" ] || [ -z "$MASK" ] || [ -z "$GATE" ] || [ -z "$ipDNS" ]; then
  echo -e "\nError: Invalid network configuration\n\n"
  bash "$0" error
  exit 1
fi


# Check dependencies based on Release variable
if [[ "$Release" == 'Debian' ]] || [[ "$Release" == 'Ubuntu' ]]; then
  checkDependencies wget,awk,grep,sed,cut,cat,lsblk,cpio,gzip,find,dirname,basename;
elif [[ "$Release" == 'CentOS' ]]; then
  checkDependencies wget,awk,grep,sed,cut,cat,lsblk,cpio,gzip,find,dirname,basename,file,xz;
fi

# If temporary password variable is not empty, check for OpenSSL dependency and generate password hash
[ -n "$tmpWORD" ] && checkDependencies openssl;
[[ -n "$tmpWORD" ]] && myPASSWORD="$(openssl passwd -1 "$tmpWORD")";
[[ -z "$myPASSWORD" ]] && myPASSWORD='$1$4BJZaD0A$y1QykUnJ6mXprENfwpseH0';

# Get temporary disk and set Incremental Disk variable if temporary disk is not empty
tempDisk=`getDisk`;
[ -n "$tempDisk" ] && IncDisk="$tempDisk";

# Determine architecture and set VER variable
case `uname -m` in
  aarch64|arm64) VER="arm64";;
  x86|i386|i686) VER="i386";;
  x86_64|amd64) VER="amd64";;
  *) VER="";;
esac

# Convert temporary version variable to lowercase
tmpVER="$(echo "$tmpVER" | sed -r 's/(.*)/\L\1/')"

# If architecture is not arm64 and temporary version is not empty, determine version based on temporary version
if [[ "$VER" != "arm64" ]] && [[ -n "$tmpVER" ]]; then
  case "$tmpVER" in
    i386|i686|x86|32) VER="i386";;
    amd64|x86_64|x64|64) 
      if [[ "$Release" == 'CentOS' ]]; then
        VER='x86_64'
      else
        VER='amd64'
      fi
      ;;
    *) VER='';;
  esac
fi

# If VER variable is empty, print error message, execute script with "error" argument, and exit with status 1
if [[ ! -n "$VER" ]]; then
  echo "Error: Unsupported architecture."
  bash $0 error
  exit 1
fi

if [[ -z "$tmpDIST" ]]; then
  if [[ "$Release" == 'Debian' ]]; then
    tmpDIST='buster'
  elif [[ "$Release" == 'Ubuntu' ]]; then
    tmpDIST='bionic'
  elif [[ "$Release" == 'CentOS' ]]; then
    tmpDIST='6.10'
  fi
fi

# Check if the temporary distribution is not empty
if [[ -n "$tmpDIST" ]]; then
  # If the release is Debian, set the distribution package to 0
  if [[ "$Release" == 'Debian' ]]; then
    distributionPackage='0'
    # Convert the temporary distribution to lowercase
    DIST="$(echo "$tmpDIST" | sed -r 's/(.*)/\L\1/')"
    # Check if the temporary distribution contains a number
    echo "$DIST" | grep -q '[0-9]'
    # If the temporary distribution contains a number, determine the corresponding Debian distribution
    [[ $? -eq '0' ]] && {
      # Extract the first number from the temporary distribution
      isDigital="$(echo "$DIST" | grep -o '[\.0-9]\{1,\}' | sed -n '1h;1!H;$g;s/\n//g;$p' | cut -d'.' -f1)"
      # If the first number is not empty, set the corresponding Debian distribution
      [[ -n $isDigital ]] && {
        case "$isDigital" in
          7) DIST='wheezy';;
          8) DIST='jessie';;
          9) DIST='stretch';;
          10) DIST='buster';;
          11) DIST='bullseye';;
          # 12) DIST='bookworm';;
        esac
      }
    }
    # Select the Linux mirror for the given release, distribution, version, and temporary mirror
    LinuxMirror=$(selectMirror "$Release" "$DIST" "$VER" "$tmpMirror")
  fi


  # If the release is Ubuntu, set the distribution package to 0
  if [[ "$Release" == 'Ubuntu' ]]; then
  distributionPackage='0'
  # Convert the temporary distribution to lowercase
  DIST="$(echo "$tmpDIST" | sed -r 's/(.*)/\L\1/')"
  # Check if the temporary distribution contains a number
  echo "$DIST" | grep -q '[0-9]'
  # If the temporary distribution contains a number, determine the corresponding Ubuntu distribution
  [[ $? -eq '0' ]] && {
      # Extract the version number from the temporary distribution
      isDigital="$(echo "$DIST" | grep -o '[\.0-9]\{1,\}' | sed -n '1h;1!H;$g;s/\n//g;$p')"
      # If the version number is not empty, set the corresponding Ubuntu distribution
      [[ -n $isDigital ]] && {
      case "$isDigital" in
          12.04) DIST='precise';;
          14.04) DIST='trusty';;
          16.04) DIST='xenial';;
          18.04) DIST='bionic';;
          20.04) DIST='focal';;
          # 22.04) DIST='jammy';;
      esac
      }
  }
  # Select the Linux mirror for the given release, distribution, version, and temporary mirror
  LinuxMirror=$(selectMirror "$Release" "$DIST" "$VER" "$tmpMirror")
  fi

  if [[ "$Release" == 'CentOS' ]]; then
      # Set distribution package to 1 for CentOS
      distributionPackage='1'
      # Extract version number from temporary DIST variable
      DISTCheck="$(echo "$tmpDIST" | grep -o '[\.0-9]\{1,\}' | head -n1)"
      # Select appropriate Linux mirror based on distribution and version
      LinuxMirror=$(selectMirror "$Release" "$DISTCheck" "$VER" "$tmpMirror")
      # Retrieve list of available distribution versions from mirror
      ListDIST="$(wget --no-check-certificate -qO- "$LinuxMirror/dir_sizes" | cut -f2 | grep '^[0-9]')"
      # Find the requested distribution version in the list
      DIST="$(echo "$ListDIST" | grep "^$DISTCheck" | head -n1)"
      # If the requested distribution version is not found, display an error message and exit
      [[ -z "$DIST" ]] && {
        echo -e "\n\e[31mError:\e[0m The distribution version was not found in this mirror. Please verify and try again.\n"
        bash $0 error
        exit 1
      }
      # Check if the requested distribution version is present in the mirror
      wget --no-check-certificate -qO- "$LinuxMirror/$DIST/os/$VER/.treeinfo" | grep -q 'general'
      # If the distribution version is not found, display an error message and exit
      [[ $? != '0' ]] && {
        echo -e "\n\e[31mError:\e[0m The version was not found in this mirror. Please change the mirror and try again.\n"
        exit 1
      }
  fi
fi

# If no Linux mirror is set, display an error message and exit
if [[ -z "$LinuxMirror" ]]; then
  echo -e "\e[31mError:\e[0m Invalid mirror detected."
  # Display examples of valid mirrors for Debian, Ubuntu, and CentOS distributions
  [ "$Release" == 'Debian' ] && echo -en "\033[33mexample:\033[0m http://deb.debian.org/debian\n\n";
  [ "$Release" == 'Ubuntu' ] && echo -en "\033[33mexample:\033[0m http://archive.ubuntu.com/ubuntu\n\n";
  [ "$Release" == 'CentOS' ] && echo -en "\033[33mexample:\033[0m http://mirror.centos.org/centos\n\n";
  bash $0 error;
  exit 1;
fi


# If the distribution package is set to 0 (Debian or Ubuntu)
if [[ "$distributionPackage" == '0' ]]; then
  # Retrieve the list of available distribution versions from the Linux mirror
  DistsList="$(wget --no-check-certificate -qO- "$LinuxMirror/dists/" | grep -o 'href=.*/"' | cut -d'"' -f2 | sed '/-\|old\|Debian\|experimental\|stable\|test\|sid\|devel/d' | grep '^[^/]' | sed -n '1h;1!H;$g;s/\n//g;s/\//\;/g;$p')"
  # Check if the requested distribution version is in the list
  for CheckDEB in `echo "$DistsList" | sed 's/;/\n/g'`
    do
      [[ "$CheckDEB" == "$DIST" ]] && FindDists='1' && break;
    done
  # If the distribution version is not found, display an error message and exit
  [[ "$FindDists" == '0' ]] && {
   echo -e "\n\e[31mError:\e[0m The distribution version was not found. Please verify and try again.\n"
    bash $0 error;
    exit 1;
  }
fi

# If ddMode is set to 1, validate the image URL
if [[ "$ddMode" == '1' ]]; then
  if [[ -n "$tmpURL" ]]; then
    DDURL="$tmpURL"
    # Check if the URL has a valid protocol (http, ftp, or https)
    echo "$DDURL" | grep -q '^http://\|^ftp://\|^https://';
    # If the URL is invalid, display an error message and exit
    [[ $? -ne '0' ]] && echo "Please provide a valid URL. Only 'http://', 'ftp://', and 'https://' protocols are supported." && exit 1;
  else
    # If the URL is empty, display an error message and exit
    echo "Please provide a valid image URL."
    exit 1;
  fi
fi

clear
echo -e "\n\033[36m# Install\033[0m\n"

# Display auto mode installation for Windows if ddMode is set to 1
[[ "$ddMode" == '1' ]] && echo -ne "\033[34mAuto Mode\033[0m install \033[33mWindows\033[0m\n[\033[33m$DDURL\033[0m]\n"

# Set default interface selection based on Linux release
if [ -z "$interfaceSelect" ]; then
  if [[ "$linux_release" == 'debian' ]] || [[ "$linux_release" == 'ubuntu' ]]; then
    interfaceSelect="auto"
  elif [[ "$linux_release" == 'centos' ]]; then
    interfaceSelect="link"
  fi
fi

# If Linux release is CentOS, perform version checks
if [[ "$linux_release" == 'centos' ]]; then
  if [[ "$DIST" != "$UNVER" ]]; then
    # Check if the requested version is lower than the unknown version
    awk 'BEGIN{print '${UNVER}'-'${DIST}'}' | grep -q '^-'
    if [ $? != '0' ]; then
      UNKNOWHW='1';
      echo -en "\033[33mThe version lower than \033[31m$UNVER\033[33m may not be supported in auto mode! \033[0m\n";
    fi
    # Check if the requested version is higher than 6.10
    awk 'BEGIN{print '${UNVER}'-'${DIST}'+0.59}' | grep -q '^-'
    if [ $? == '0' ]; then
      echo -en "\n\033[31mVersions beyond \033[33m6.10 \033[31mare presently unsupported! \033[0m\n\n"
      exit 1;
    fi
  fi
fi

# Display downloading progress for the selected distribution
echo -e "\n[\033[33m$Release\033[0m] [\033[33m$DIST\033[0m] [\033[33m$VER\033[0m] Downloading..."

# Download initrd.img and vmlinuz files for Debian, Ubuntu, and CentOS
if [[ "$linux_release" == 'debian' ]] || [[ "$linux_release" == 'ubuntu' ]]; then
  [ "$DIST" == "focal" ] && legacy="legacy-" || legacy=""
  # Download initrd.img
  wget --no-check-certificate -qO '/tmp/initrd.img' "${LinuxMirror}/dists/${DIST}/main/installer-${VER}/current/${legacy}images/netboot/${linux_release}-installer/${VER}/initrd.gz"
  [[ $? -ne '0' ]] && echo -ne "\033[31mError! \033[0mDownload of 'initrd.img' for \033[33m$linux_release\033[0m was unsuccessful! \n" && exit 1
  # Download vmlinuz
  wget --no-check-certificate -qO '/tmp/vmlinuz' "${LinuxMirror}/dists/${DIST}${inUpdate}/main/installer-${VER}/current/${legacy}images/netboot/${linux_release}-installer/${VER}/linux"
  [[ $? -ne '0' ]] && echo -ne "\033[31mError! \033[0mDownload 'vmlinuz' for \033[33m$linux_release\033[0m fwas unsuccessful! \n" && exit 1
  # Extract mirror host and folder
  MirrorHost="$(echo "$LinuxMirror" |awk -F'://|/' '{print $2}')";
  MirrorFolder="$(echo "$LinuxMirror" |awk -F''${MirrorHost}'' '{print $2}')";
  [ -n "$MirrorFolder" ] || MirrorFolder="/"
elif [[ "$linux_release" == 'centos' ]]; then
  # Download initrd.img
  wget --no-check-certificate -qO '/tmp/initrd.img' "${LinuxMirror}/${DIST}/os/${VER}/isolinux/initrd.img"
  [[ $? -ne '0' ]] && echo -ne "\033[31mError! \033[0mDownload 'initrd.img' for \033[33m$linux_release\033[0m was unsuccessful! \n" && exit 1
  # Download vmlinuz
  wget --no-check-certificate -qO '/tmp/vmlinuz' "${LinuxMirror}/${DIST}/os/${VER}/isolinux/vmlinuz"
  [[ $? -ne '0' ]] && echo -ne "\033[31mError! \033[0mDownload 'vmlinuz' for \033[33m$linux_release\033[0m was unsuccessful! \n" && exit 1
else
  bash $0 error;
  exit 1;
fi

# Check if the Linux release is Debian
if [[ "$linux_release" == 'debian' ]]; then
  # If including firmware, download it
  if [[ "$IncFirmware" == '1' ]]; then
    wget --no-check-certificate -qO '/tmp/firmware.cpio.gz' "http://cdimage.debian.org/cdimage/unofficial/non-free/firmware/${DIST}/current/firmware.cpio.gz"
    [[ $? -ne '0' ]] && echo -ne "\033[31mError!\033[0m Download 'firmware' for \033[33m$linux_release\033[0m was unsuccessful! \n" && exit 1
  fi
  # If in DD mode, get the udeb kernel version
  if [[ "$ddMode" == '1' ]]; then
    vKernel_udeb=$(wget --no-check-certificate -qO- "http://$DISTMirror/dists/$DIST/main/installer-$VER/current/images/udeb.list" |grep '^acpi-modules' |head -n1 |grep -o '[0-9]\{1,2\}.[0-9]\{1,2\}.[0-9]\{1,2\}-[0-9]\{1,2\}' |head -n1)
    [[ -z "$vKernel_udeb" ]] && vKernel_udeb="4.19.0-17"
  fi
fi

# If loader mode is 0, perform the following operations
if [[ "$loaderMode" == "0" ]]; then
  # If the GRUBFILE is not found, display an error and exit
  [[ ! -f "${GRUBDIR}/${GRUBFILE}" ]] && echo "Error! ${GRUBFILE} not found." && exit 1;
  
  # If GRUBFILE.old does not exist and GRUBFILE.bak does, rename GRUBFILE.bak to GRUBFILE.old
  [[ ! -f "${GRUBDIR}/${GRUBFILE}.old" ]] && [[ -f "${GRUBDIR}/${GRUBFILE}.bak" ]] && mv -f "${GRUBDIR}/${GRUBFILE}.bak" "${GRUBDIR}/${GRUBFILE}.old";
  
  # Move the current GRUBFILE to GRUBFILE.bak
  mv -f "${GRUBDIR}/${GRUBFILE}" "${GRUBDIR}/${GRUBFILE}.bak";
  
  # If GRUBFILE.old exists, copy its contents to GRUBFILE; otherwise, copy GRUBFILE.bak contents to GRUBFILE
  [[ -f "${GRUBDIR}/${GRUBFILE}.old" ]] && cat "${GRUBDIR}/${GRUBFILE}.old" >"${GRUBDIR}/${GRUBFILE}" || cat "${GRUBDIR}/${GRUBFILE}.bak" >"${GRUBDIR}/${GRUBFILE}";
else
  # If loader mode is not 0, set GRUBVER to -1
  GRUBVER='-1'
fi


# If GRUBVER is 0, perform the following operations
if [[ "$GRUBVER" == '0' ]]; then
  READGRUB='/tmp/grub.read'
  # Extract the first menu entry from the GRUB configuration
  cat $GRUBDIR/$GRUBFILE | sed -n '1h;1!H;$g;s/\n/%%%%%%%/g;$p' | grep -om 1 'menuentry\ [^{]*{[^}]*}%%%%%%%' | sed 's/%%%%%%%/\n/g' > $READGRUB

  # Count the number of menu entries
  LoadNum="$(cat $READGRUB | grep -c 'menuentry ')"

  # If there is only one menu entry, copy it to a new file
  if [[ "$LoadNum" -eq '1' ]]; then
    cat $READGRUB | sed '/^$/d' > /tmp/grub.new;
  # If there are multiple menu entries, extract the first one and copy it to a new file
  elif [[ "$LoadNum" -gt '1' ]]; then
    CFG0="$(awk '/menuentry /{print NR}' $READGRUB|head -n 1)";
    CFG2="$(awk '/menuentry /{print NR}' $READGRUB|head -n 2 |tail -n 1)";
    CFG1=""

    for tmpCFG in $(awk '/}/{print NR}' $READGRUB); do
      [ "$tmpCFG" -gt "$CFG0" -a "$tmpCFG" -lt "$CFG2" ] && CFG1="$tmpCFG";
    done

    if [[ -z "$CFG1" ]]; then
      echo "Error! Could not read $GRUBFILE."
      exit 1
    fi

    sed -n "$CFG0,$CFG1"p $READGRUB > /tmp/grub.new;

    if [[ -f /tmp/grub.new ]] && [[ "$(grep -c '{' /tmp/grub.new)" -eq "$(grep -c '}' /tmp/grub.new)" ]]; then
      :
    else
      echo -ne "\033[31mError! \033[0mConfiguration of $GRUBFILE was unsuccessful. \n"
      exit 1
    fi
  fi

  # If the new file was not created, display an error and exit
  if [ ! -f /tmp/grub.new ]; then
    echo "Error! Could not read $GRUBFILE."
    exit 1
  fi
fi

  sed -i "/menuentry.*/c\menuentry\ \'Install OS \[$DIST\ $VER\]\'\ --class debian\ --class\ gnu-linux\ --class\ gnu\ --class\ os\ \{" /tmp/grub.new
  sed -i "/echo.*Loading/d" /tmp/grub.new;
  INSERTGRUB="$(awk '/menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"

# If GRUBVER is 1, perform the following operations
if [[ "$GRUBVER" == '1' ]]; then
  CFG0="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)";
  CFG1="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 2 |tail -n 1)";

  if [[ -n $CFG0 ]] && ( [[ -z $CFG1 ]] || [[ $CFG1 == $CFG0 ]] ); then
    sed -n "$CFG0,$"p $GRUBDIR/$GRUBFILE > /tmp/grub.new;
  elif [[ -n $CFG0 ]] && [[ $CFG1 != $CFG0 ]]; then
    sed -n "$CFG0,$[$CFG1-1]"p $GRUBDIR/$GRUBFILE > /tmp/grub.new;
  fi

  if [ ! -f /tmp/grub.new ]; then
    echo "Error! Failed to configure append $GRUBFILE."
    exit 1
  fi

  sed -i "/title.*/c\title\ \'Install OS \[$DIST\ $VER\]\'" /tmp/grub.new;
  sed -i '/^#/d' /tmp/grub.new;
  INSERTGRUB="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
fi

if [[ "$loaderMode" == "0" ]]; then

  # Ascertain the presence of a Linux installation within the boot directory
  [[ -n "$(grep 'linux.*/\|kernel.*/' /tmp/grub.new | awk '{print $2}' | tail -n 1 | grep '^/boot/')" ]] && Type='InBoot' || Type='NoBoot';

  # Extract kernel and initrd images from the GRUB configuration
  LinuxKernel="$(grep 'linux.*/\|kernel.*/' /tmp/grub.new | awk '{print $1}' | head -n 1)";
  [[ -z "$LinuxKernel" ]] && echo "Error! Unable to parse GRUB configuration!" && exit 1;
  LinuxIMG="$(grep 'initrd.*/' /tmp/grub.new | awk '{print $1}' | tail -n 1)";
  [ -z "$LinuxIMG" ] && sed -i "/$LinuxKernel.*\//a\\\tinitrd\ \/" /tmp/grub.new && LinuxIMG='initrd';

  # Configure additional kernel options
  [[ "$setInterfaceName" == "1" ]] && Add_OPTION="net.ifnames=0 biosdevname=0" || Add_OPTION=""
  [[ "$setIPv6" == "1" ]] && Add_OPTION="$Add_OPTION ipv6.disable=1"
  lowMem || Add_OPTION="$Add_OPTION lowmem=+2"

  # Set boot options based on the Linux distribution
  if [[ "$linux_release" == 'debian' ]] || [[ "$linux_release" == 'ubuntu' ]]; then
    BOOT_OPTION="auto=true $Add_OPTION hostname=$linux_release domain=$linux_release quiet"
  elif [[ "$linux_release" == 'centos' ]]; then
    BOOT_OPTION="ks=file://ks.cfg $Add_OPTION ksdevice=$interfaceSelect"
  fi
  
  # Define console option if specified
  [ -n "$setConsole" ] && BOOT_OPTION="$BOOT_OPTION --- console=$setConsole"

  # Update GRUB configuration with the new kernel and initrd images
  [[ "$Type" == 'InBoot' ]] && {
    sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/boot\/vmlinuz $BOOT_OPTION" /tmp/grub.new;
    sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/boot\/initrd.img" /tmp/grub.new;
  }

  [[ "$Type" == 'NoBoot' ]] && {
    sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/vmlinuz $BOOT_OPTION" /tmp/grub.new;
    sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/initrd.img" /tmp/grub.new;
  }

  # Append a newline character to the end of the file
  sed -i '$a\\n' /tmp/grub.new;
  
  # Integrate the modified GRUB configuration at the designated line
  sed -i ''${INSERTGRUB}'i\\n' $GRUBDIR/$GRUBFILE;
  sed -i ''${INSERTGRUB}'r /tmp/grub.new' $GRUBDIR/$GRUBFILE;

  # Comment the saved_entry directive in grubenv
  [[ -f  $GRUBDIR/grubenv ]] && sed -i 's/saved_entry/#saved_entry/g' $GRUBDIR/grubenv;

fi

# Remove old /tmp/boot directory if it exists
[[ -d /tmp/boot ]] && rm -rf /tmp/boot;

# Create /tmp/boot directory
mkdir -p /tmp/boot;
cd /tmp/boot;

# Determine the compression type of the initrd image and rename it accordingly
if [[ "$linux_release" == 'debian' ]] || [[ "$linux_release" == 'ubuntu' ]]; then
  COMPTYPE="gzip";
elif [[ "$linux_release" == 'centos' ]]; then
  COMPTYPE="$(file ../initrd.img | grep -o ':.*compressed data' | cut -d' ' -f2 | sed -r 's/(.*)/\L\1/' | head -n1)"
  [[ -z "$COMPTYPE" ]] && echo "Failed to detect compressed type." && exit 1;
fi

CompDected='0'
for COMP in `echo -en 'gzip\nlzma\nxz'`
do
  if [[ "$COMPTYPE" == "$COMP" ]]; then
    CompDected='1'
    if [[ "$COMPTYPE" == 'gzip' ]]; then
      NewIMG="initrd.img.gz"
    else
      NewIMG="initrd.img.$COMPTYPE"
    fi
    mv -f "/tmp/initrd.img" "/tmp/$NewIMG"
    break;
  fi
done

# Check if the compression type is supported
[[ "$CompDected" != '1' ]] && echo "Unsupported compressed type detected." && exit 1;

# Set the decompression command based on the compression type
[[ "$COMPTYPE" == 'lzma' ]] && UNCOMP='xz --format=lzma --decompress';
[[ "$COMPTYPE" == 'xz' ]] && UNCOMP='xz --decompress';
[[ "$COMPTYPE" == 'gzip' ]] && UNCOMP='gzip -d';

# Extract the initrd image using the decompression command and cpio
$UNCOMP < /tmp/$NewIMG | cpio --extract --verbose --make-directories --no-absolute-filenames >> /dev/null 2>&1

# If the Linux release is Debian or Ubuntu, execute the following commands
if [[ "$linux_release" == 'debian' ]] || [[ "$linux_release" == 'ubuntu' ]]; then
cat >/tmp/boot/preseed.cfg<<EOF
d-i debian-installer/locale string en_US
d-i debian-installer/country string US
d-i debian-installer/language string en

d-i console-setup/layoutcode string us

d-i keyboard-configuration/xkb-keymap string us
d-i lowmem/low note

d-i netcfg/choose_interface select $interfaceSelect

d-i netcfg/disable_autoconfig boolean true
d-i netcfg/dhcp_failed note
d-i netcfg/dhcp_options select Configure network manually
d-i netcfg/get_ipaddress string $IPv4
d-i netcfg/get_netmask string $MASK
d-i netcfg/get_gateway string $GATE
d-i netcfg/get_nameservers string $ipDNS
d-i netcfg/no_default_route boolean true
d-i netcfg/confirm_static boolean true

d-i hw-detect/load_firmware boolean true

d-i mirror/country string manual
d-i mirror/http/hostname string $MirrorHost
d-i mirror/http/directory string $MirrorFolder
d-i mirror/http/proxy string

d-i passwd/root-login boolean ture
d-i passwd/make-user boolean false
d-i passwd/root-password-crypted password $myPASSWORD
d-i user-setup/allow-password-weak boolean true
d-i user-setup/encrypt-home boolean false

d-i clock-setup/utc boolean true
d-i time/zone string US/Eastern
d-i clock-setup/ntp boolean false

d-i preseed/early_command string anna-install libfuse2-udeb fuse-udeb ntfs-3g-udeb libcrypto1.1-udeb libpcre2-8-0-udeb libssl1.1-udeb libuuid1-udeb zlib1g-udeb wget-udeb
d-i partman/early_command string [[ -n "\$(blkid -t TYPE='vfat' -o device)" ]] && umount "\$(blkid -t TYPE='vfat' -o device)"; \
debconf-set partman-auto/disk "\$(list-devices disk |head -n1)"; \
wget -qO- '$DDURL' |gunzip -dc |/bin/dd of=\$(list-devices disk |head -n1); \
mount.ntfs-3g \$(list-devices partition |head -n1) /mnt; \
cd '/mnt/ProgramData/Microsoft/Windows/Start Menu/Programs'; \
cd Start* || cd start*; \
cp -f '/net.bat' './net.bat'; \
/sbin/reboot; \
umount /media || true; \

d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/mount_style select uuid
d-i partman/choose_partition select finish
d-i partman-auto/method string regular
d-i partman-auto/init_automatically_partition select Guided - use entire disk
d-i partman-auto/choose_recipe select All files in one partition (recommended for new users)
d-i partman-md/device_remove_md boolean true
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

d-i debian-installer/allow_unauthenticated boolean true

tasksel tasksel/first multiselect minimal
d-i pkgsel/update-policy select none
d-i pkgsel/include string openssh-server
d-i pkgsel/upgrade select none

popularity-contest popularity-contest/participate boolean false

d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string $IncDisk
d-i grub-installer/force-efi-extra-removable boolean true
d-i finish-install/reboot_in_progress note
d-i debian-installer/exit/reboot boolean true
d-i preseed/late_command string	\
sed -ri 's/^#?Port.*/Port ${sshPORT}/g' /target/etc/ssh/sshd_config; \
sed -ri 's/^#?PermitRootLogin.*/PermitRootLogin yes/g' /target/etc/ssh/sshd_config; \
sed -ri 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/g' /target/etc/ssh/sshd_config; \
echo '@reboot root cat /etc/run.sh 2>/dev/null |base64 -d >/tmp/run.sh; rm -rf /etc/run.sh; sed -i /^@reboot/d /etc/crontab; bash /tmp/run.sh' >>/target/etc/crontab; \
echo '' >>/target/etc/crontab; \
echo '${setCMD}' >/target/etc/run.sh;
EOF

if [[ "$loaderMode" != "0" ]] && [[ "$setNet" == '0' ]]; then
  sed -i '/netcfg\/disable_autoconfig/d' /tmp/boot/preseed.cfg
  sed -i '/netcfg\/dhcp_options/d' /tmp/boot/preseed.cfg
  sed -i '/netcfg\/get_.*/d' /tmp/boot/preseed.cfg
  sed -i '/netcfg\/confirm_static/d' /tmp/boot/preseed.cfg
fi

if [[ "$linux_release" == 'debian' ]]; then
  sed -i '/user-setup\/allow-password-weak/d' /tmp/boot/preseed.cfg
  sed -i '/user-setup\/encrypt-home/d' /tmp/boot/preseed.cfg
  sed -i '/pkgsel\/update-policy/d' /tmp/boot/preseed.cfg
  sed -i 's/umount\ \/media.*true\;\ //g' /tmp/boot/preseed.cfg
  [[ -f '/tmp/firmware.cpio.gz' ]] && gzip -d < /tmp/firmware.cpio.gz | cpio --extract --verbose --make-directories --no-absolute-filenames >>/dev/null 2>&1
else
  sed -i '/d-i\ grub-installer\/force-efi-extra-removable/d' /tmp/boot/preseed.cfg
fi

[[ "$ddMode" == '1' ]] && {
WinNoDHCP(){
  echo -ne "for\0040\0057f\0040\0042tokens\00753\0052\0042\0040\0045\0045i\0040in\0040\0050\0047netsh\0040interface\0040show\0040interface\0040\0136\0174more\0040\00533\0040\0136\0174findstr\0040\0057I\0040\0057R\0040\0042本地\0056\0052\0040以太\0056\0052\0040Local\0056\0052\0040Ethernet\0042\0047\0051\0040do\0040\0050set\0040EthName\0075\0045\0045j\0051\r\nnetsh\0040\0055c\0040interface\0040ip\0040set\0040address\0040name\0075\0042\0045EthName\0045\0042\0040source\0075static\0040address\0075$IPv4\0040mask\0075$MASK\0040gateway\0075$GATE\r\nnetsh\0040\0055c\0040interface\0040ip\0040add\0040dnsservers\0040name\0075\0042\0045EthName\0045\0042\0040address\00758\00568\00568\00568\0040index\00751\0040validate\0075no\r\n\r\n" >>'/tmp/boot/net.tmp';
}
WinRDP(){
  echo -ne "netsh\0040firewall\0040set\0040portopening\0040protocol\0075ALL\0040port\0075$WinRemote\0040name\0075RDP\0040mode\0075ENABLE\0040scope\0075ALL\0040profile\0075ALL\r\nnetsh\0040firewall\0040set\0040portopening\0040protocol\0075ALL\0040port\0075$WinRemote\0040name\0075RDP\0040mode\0075ENABLE\0040scope\0075ALL\0040profile\0075CURRENT\r\nreg\0040add\0040\0042HKLM\0134SYSTEM\0134CurrentControlSet\0134Control\0134Network\0134NewNetworkWindowOff\0042\0040\0057f\r\nreg\0040add\0040\0042HKLM\0134SYSTEM\0134CurrentControlSet\0134Control\0134Terminal\0040Server\0042\0040\0057v\0040fDenyTSConnections\0040\0057t\0040reg\0137dword\0040\0057d\00400\0040\0057f\r\nreg\0040add\0040\0042HKLM\0134SYSTEM\0134CurrentControlSet\0134Control\0134Terminal\0040Server\0134Wds\0134rdpwd\0134Tds\0134tcp\0042\0040\0057v\0040PortNumber\0040\0057t\0040reg\0137dword\0040\0057d\0040$WinRemote\0040\0057f\r\nreg\0040add\0040\0042HKLM\0134SYSTEM\0134CurrentControlSet\0134Control\0134Terminal\0040Server\0134WinStations\0134RDP\0055Tcp\0042\0040\0057v\0040PortNumber\0040\0057t\0040reg\0137dword\0040\0057d\0040$WinRemote\0040\0057f\r\nreg\0040add\0040\0042HKLM\0134SYSTEM\0134CurrentControlSet\0134Control\0134Terminal\0040Server\0134WinStations\0134RDP\0055Tcp\0042\0040\0057v\0040UserAuthentication\0040\0057t\0040reg\0137dword\0040\0057d\00400\0040\0057f\r\nFOR\0040\0057F\0040\0042tokens\00752\0040delims\0075\0072\0042\0040\0045\0045i\0040in\0040\0050\0047SC\0040QUERYEX\0040TermService\0040\0136\0174FINDSTR\0040\0057I\0040\0042PID\0042\0047\0051\0040do\0040TASKKILL\0040\0057F\0040\0057PID\0040\0045\0045i\r\nFOR\0040\0057F\0040\0042tokens\00752\0040delims\0075\0072\0042\0040\0045\0045i\0040in\0040\0050\0047SC\0040QUERYEX\0040UmRdpService\0040\0136\0174FINDSTR\0040\0057I\0040\0042PID\0042\0047\0051\0040do\0040TASKKILL\0040\0057F\0040\0057PID\0040\0045\0045i\r\nSC\0040START\0040TermService\r\n\r\n" >>'/tmp/boot/net.tmp';
}
  echo -ne "\0100ECHO\0040OFF\r\n\r\ncd\0056\0076\0045WINDIR\0045\0134GetAdmin\r\nif\0040exist\0040\0045WINDIR\0045\0134GetAdmin\0040\0050del\0040\0057f\0040\0057q\0040\0042\0045WINDIR\0045\0134GetAdmin\0042\0051\0040else\0040\0050\r\necho\0040CreateObject\0136\0050\0042Shell\0056Application\0042\0136\0051\0056ShellExecute\0040\0042\0045\0176s0\0042\0054\0040\0042\0045\0052\0042\0054\0040\0042\0042\0054\0040\0042runas\0042\0054\00401\0040\0076\0076\0040\0042\0045temp\0045\0134Admin\0056vbs\0042\r\n\0042\0045temp\0045\0134Admin\0056vbs\0042\r\ndel\0040\0057f\0040\0057q\0040\0042\0045temp\0045\0134Admin\0056vbs\0042\r\nexit\0040\0057b\00402\0051\r\n\r\n" >'/tmp/boot/net.tmp';
  [[ "$setNet" == '1' ]] && WinNoDHCP;
  [[ "$setNet" == '0' ]] && [[ "$AutoNet" == '0' ]] && WinNoDHCP;
  [[ "$setRDP" == '1' ]] && [[ -n "$WinRemote" ]] && WinRDP
  echo -ne "ECHO\0040SELECT\0040VOLUME\0075\0045\0045SystemDrive\0045\0045\0040\0076\0040\0042\0045SystemDrive\0045\0134diskpart\0056extend\0042\r\nECHO\0040EXTEND\0040\0076\0076\0040\0042\0045SystemDrive\0045\0134diskpart\0056extend\0042\r\nSTART\0040/WAIT\0040DISKPART\0040\0057S\0040\0042\0045SystemDrive\0045\0134diskpart\0056extend\0042\r\nDEL\0040\0057f\0040\0057q\0040\0042\0045SystemDrive\0045\0134diskpart\0056extend\0042\r\n\r\n" >>'/tmp/boot/net.tmp';
  echo -ne "cd\0040\0057d\0040\0042\0045ProgramData\0045\0057Microsoft\0057Windows\0057Start\0040Menu\0057Programs\0057Startup\0042\r\ndel\0040\0057f\0040\0057q\0040net\0056bat\r\n\r\n\r\n" >>'/tmp/boot/net.tmp';
  iconv -f 'UTF-8' -t 'GBK' '/tmp/boot/net.tmp' -o '/tmp/boot/net.bat'
  rm -rf '/tmp/boot/net.tmp'
}

[[ "$ddMode" == '0' ]] && {
  sed -i '/anna-install/d' /tmp/boot/preseed.cfg
  sed -i 's/wget.*\/sbin\/reboot\;\ //g' /tmp/boot/preseed.cfg
}

# Else if the Linux release is Centos
elif [[ "$linux_release" == 'centos' ]]; then
cat >/tmp/boot/ks.cfg<<EOF
#platform=x86, AMD64, or Intel EM64T
firewall --enabled --ssh
install
url --url="$LinuxMirror/$DIST/os/$VER/"
rootpw --iscrypted $myPASSWORD
auth --useshadow --passalgo=sha512
firstboot --disable
lang en_US
keyboard us
selinux --disabled
logging --level=info
reboot
text
unsupported_hardware
vnc
skipx
timezone --isUtc Asia/Hong_Kong
#ONDHCP network --bootproto=dhcp --onboot=on
network --bootproto=static --ip=$IPv4 --netmask=$MASK --gateway=$GATE --nameserver=$ipDNS --onboot=on
bootloader --location=mbr --append="rhgb quiet crashkernel=auto"
zerombr
clearpart --all --initlabel 
autopart

%packages
@base
%end

%post --interpreter=/bin/bash
rm -rf /root/anaconda-ks.cfg
rm -rf /root/install.*log
%end

EOF

[[ "$UNKNOWHW" == '1' ]] && sed -i 's/^unsupported_hardware/#unsupported_hardware/g' /tmp/boot/ks.cfg
[[ "$(echo "$DIST" |grep -o '^[0-9]\{1\}')" == '5' ]] && sed -i '0,/^%end/s//#%end/' /tmp/boot/ks.cfg
fi

find . | cpio -H newc --create --verbose | gzip -9 > /tmp/initrd.img;
cp -f /tmp/initrd.img /boot/initrd.img || sudo cp -f /tmp/initrd.img /boot/initrd.img
cp -f /tmp/vmlinuz /boot/vmlinuz || sudo cp -f /tmp/vmlinuz /boot/vmlinuz

chown root:root $GRUBDIR/$GRUBFILE
chmod 444 $GRUBDIR/$GRUBFILE

if [[ "$loaderMode" == "0" ]]; then
  sleep 3 && reboot || sudo reboot >/dev/null 2>&1
else
  rm -rf "$HOME/loader"
  mkdir -p "$HOME/loader"
  cp -rf "/boot/initrd.img" "$HOME/loader/initrd.img"
  cp -rf "/boot/vmlinuz" "$HOME/loader/vmlinuz"
  [[ -f "/boot/initrd.img" ]] && rm -rf "/boot/initrd.img"
  [[ -f "/boot/vmlinuz" ]] && rm -rf "/boot/vmlinuz"
  echo && ls -AR1 "$HOME/loader"
fi

