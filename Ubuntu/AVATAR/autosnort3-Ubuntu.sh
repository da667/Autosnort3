#!/bin/bash
#Autosnort script for Ubuntu 18.04+
#Please note that this version of the script is specifically made available for students of Building Virtual Labs training on networkdefense.io, as well as the book, Building Virtual Machine Labs: A Hands-On Guide
#This work is based on the documentation written by Noah Dietrech for installing Snort 3 on Ubuntu 18.04 and 20.04: https://snort.org/documents/snort-3-1-0-0-on-ubuntu-18-20
#This script will configure Snort

#Functions, functions everywhere.

# Logging setup. Ganked this entirely from stack overflow. Uses FIFO/pipe magic to log all the output of the script to a file. Also capable of accepting redirects/appends to the file for logging compiler stuff (configure, make and make install) to a log file instead of losing it on a screen buffer. This gives the user cleaner output, while logging everything in the background, for troubleshooting, analysis, or sending it to me for help.

logfile=/var/log/autosnort3_install.log
mkfifo ${logfile}.pipe
tee < ${logfile}.pipe $logfile &
exec &> ${logfile}.pipe
rm ${logfile}.pipe

########################################

#metasploit-like print statements. Borrowed  Darkoperator's metasploit install script. Way back when.
#This causes a colored asterisk to appear to denote whether a good thing (green), bad thing (red), or something to pay attention to (yellow) has occurred.

function print_status ()
{
    echo -e "\x1B[01;34m[*]\x1B[0m $1"
}

function print_good ()
{
    echo -e "\x1B[01;32m[*]\x1B[0m $1"
}

function print_error ()
{
    echo -e "\x1B[01;31m[*]\x1B[0m $1"
}

function print_notification ()
{
	echo -e "\x1B[01;33m[*]\x1B[0m $1"
}
########################################

#This is a nice retry function by sj26 on github.
#link to original: https://gist.github.com/sj26/88e1c6584397bb7c13bd11108a579746
# Retry a command up to a specific numer of times until it exits successfully
function retry 
{
	local retries=$1
	shift
	local count=0
	until "$@"; do
		exit=$?
		count=$(($count + 1))
		if [ $count -lt $retries ]; then
			print_notification "Retry $count/$retries exited $exit, retrying.."
		else
			print_error "Retry $count/$retries exited with error code $exit, no more retries left."
		return $exit
		fi
	done
	return 0
}


#Script does a lot of error checking. Decided to insert an error check function. 
#If a task performed returns a non zero status code, something very likely went wrong.
#The output of all of the commands are logged to /var/log/autosnort_install.log to help debug script issues.

function error_check
{

if [ $? -eq 0 ]; then
	print_good "$1 successfully completed."
else
	print_error "$1 failed. Please check $logfile for more details, or contact deusexmachina667 at gmail dot com for more assistance."
exit 1
fi

}
########################################
#Package installation function.

function install_packages()
{

apt-get update &>> $logfile && apt-get install -y ${@} &>> $logfile
error_check 'Package installation'

}


#This script creates a lot of directories by default. This is a function that checks if a directory already exists and if it doesn't creates the directory (including parent dirs if they're missing).

########################################

function dir_check()
{

if [ ! -d $1 ]; then
	print_notification "Directory $1 does not exist. Creating.."
	mkdir -p $1
else
	print_notification "Directory $1 already exists."
fi

}

########################################
##BEGIN MAIN SCRIPT##

#Pre-checks: These are a couple of basic sanity checks the script does before proceeding.

########################################

#These lines establish where autosnort was executed. The config file _should_ be in this directory. the script exits if the config isn't in the same directory as the autosnort-ubuntu shell script.

print_status "Checking for config file.."
execdir=`pwd`
if [ ! -f "$execdir"/full_autosnort.conf ]; then
	print_error "full_autosnort.conf was NOT found in $execdir. The script relies HEAVILY on this config file. Please make sure it is in the same directory you are executing the autosnort-ubuntu script from!"
	exit 1
else
	print_good "Found config file."
fi

source "$execdir"/full_autosnort.conf &>> $logfile

########################################

print_status "Checking for root privs.."
if [ $(whoami) != "root" ]; then
	print_error "This script must be ran with sudo or root privileges."
	exit 1
else
	print_good "We are root."
fi
	 
########################################	 

#this is a nice little hack I found in stack exchange to suppress messages during package installation.
export DEBIAN_FRONTEND=noninteractive

# System updates
print_status "Performing apt-get update and upgrade (May take a while if this is a fresh install).."
apt-get update &>> $logfile && apt-get -y upgrade &>> $logfile
error_check 'System updates'

########################################
#Need to do an OS version check.

print_status "OS Version Check.."
release=`lsb_release -r|awk '{print $2}'`
if [[ $release == "20."* || "22."* ]]; then
	print_good "OS is Ubuntu 20.x+. Good to go."
else
    print_notification "This is not Ubuntu 20.x, this script has NOT been tested on other platforms."
	print_notification "You continue at your own risk!(Please report your successes or failures!)"
fi

########################################
#Installing pre-requisites
#We begin by installing the software packages and libraries available in the Ubuntu repos.

print_status "Installing base packages: autoconf autotools-dev bison build-essential cmake cpputest ethtool flex git jq libcmocka-dev libboost-all-dev libcrypt-ssleay-perl libdumbnet-dev libhwloc-dev libluajit-5.1-dev liblwp-useragent-determined-perl liblzma-dev libmnl-dev libnetfilter-queue-dev libpcap-dev libpcre2-dev libpcre3 libpcre3-dbg libpcre3-dev libpcap-dev libsqlite3-dev libssl-dev libtool libunwind-dev openssl pkg-config ragel uuid-dev unzip xz-utils zlib1g-dev.."
	
declare -a packages=( autoconf autotools-dev bison build-essential cmake cpputest ethtool flex git jq libcmocka-dev libboost-all-dev libcrypt-ssleay-perl libdumbnet-dev libhwloc-dev libluajit-5.1-dev liblwp-useragent-determined-perl liblzma-dev libmnl-dev libnetfilter-queue-dev libpcap-dev libpcre2-dev libpcre3 libpcre3-dbg libpcre3-dev libpcap-dev libsqlite3-dev libssl-dev libtool libunwind-dev openssl pkg-config ragel uuid-dev unzip xz-utils zlib1g-dev );
	
install_packages ${packages[@]}

########################################
#Acquiring pre-requisite sources to compile
#Noah's instructions for building snort3 call for compiling a bunch of prereqs (libsafec, gperftools, pcre, c++ boost, hyperscan, flatbuffers, and libdaq)
#along with snort3 itself, as well as the snort3-extra
#this section involves a lot of html and json parsing from a couple of different websites in order to find the latest version of each software package
#if the github api, the download pages, or the urls change, this script will likely break horribly. but that's a problem for future me.

safec_latest_url=`curl --silent "https://api.github.com/repos/rurban/safeclib/releases/latest" | jq -r '.assets[].browser_download_url' | egrep ".tar.bz2$"`
safec_ver=`echo $safec_latest_url | cut -d"/" -f9 | sed -e 's/.tar.bz2//'`

gperftools_latest_url=`curl --silent "https://api.github.com/repos/gperftools/gperftools/releases/latest" | jq -r '.assets[0].browser_download_url'`
gperftools_ver=`echo $gperftools_latest_url | cut -d"/" -f9 | sed 's/.tar.gz//'`

flatbuffers_latest_url=`curl --silent "https://api.github.com/repos/google/flatbuffers/releases/latest" | jq -r .tarball_url`
flatbuffers_latest_version=`echo $flatbuffers_latest_url | cut -d"/" -f8 | sed 's/v//'`

#Using a new method to pull the latest version of the snort3 and libdaq tarballs using the github api and jq to parse out the "latest" tag name. I'm not a programmer by trade, so thank you to @krishean@tech.lgbt for sharing this method. Unfortunately, we still have to pull the downloads page from snort.org to rectify what rule tarballs we should attempt to download.

cd /tmp &>> $logfile
wget https://www.snort.org/downloads &>> $logfile
error_check 'Download of snort.org downloads page'

snort3_version_string=`curl -fsSL https://api.github.com/repos/snort3/snort3/releases/latest | jq -r .tag_name`
snort3_version_tarball=snort3-$snort3_version_string.tar.gz
snort3_dirstring=snort3-$snort3_version_string
snort3_latest_url="https://github.com/snort3/snort3/archive/refs/tags/$snort3_version_string.tar.gz"

snort3_libdaq_version_string=`curl -fsSL https://api.github.com/repos/snort3/libdaq/releases/latest | jq -r .tag_name`
snort3_libdaq_tarball=libdaq-$snort3_libdaq_version_string.tar.gz
snort3_libdaq_dirstring=`echo libdaq-$snort3_libdaq_version_string | sed 's/v//'`
snort3_libdaq_latest_url="https://github.com/snort3/libdaq/archive/refs/tags/$snort3_libdaq_version_string.tar.gz"

#curses to the snort3 team for failing to use releases on the snort3_extra repo. We have to do a little extra work here to pull releases with actual version strings in them (the grep with the PCRE is to ensure a 4-digit version string in the .name field is returned), then we assume that the API is going to show us the latest 4-digit version string first (at least it did when I tested it) and we use the head command to pull the first (newest) result.
snort3_extras_version_string=`curl -fsSL https://api.github.com/repos/snort3/snort3_extra/tags | jq -r .[].name | grep -P "\d+\.\d+\.\d+\.\d+" | head -1`
snort3_extras_tarball=snort3_extra-$snort3_extras_version_string.tar.gz
snort3_extras_dirstring=snort3_extra-$snort3_extras_version_string
snort3_extras_latest_url="https://github.com/snort3/snort3_extra/archive/refs/tags/$snort3_extras_version_string.tar.gz"

#Added this in to account for instances where the snortrules tarball has not yet caught up with the current release of snort3 on snort.org.
#grep for snortrules-snapshot-3 for snort3 rule tarballs. pull out just the 4-digit version string, then add periods (.) between each of the numbers.
#We use this number to set the "-S" flag for pulledpork.
#This is an ancient, but necessary evil.
pp_s_flag=`grep snortrules-snapshot-3 downloads | cut -d"-" -f3 | cut -d"." -f1 |sed -e 's/[[:digit:]]\{3\}/&./'| sed -e 's/[[:digit:]]\{2\}/&./' | sed -e 's/[[:digit:]]/&./' | head -1`

rm -rf /tmp/downloads

########################################
#installing vectorscan
#vectorscan is the supported drop-in replacement for hyperscan, since Intel just kinda pulled the plug on the open-source version..

print_status "Downloading, compiling, and install vectorscan.."

cd /usr/src &>> $logfile

#if the vectorscan library already exists, git clone fails. So we remove it, if it exists.
if [ -d /usr/src/vectorscan ]; then
	rm -rf /usr/src/vectorscan
fi

git clone https://github.com/VectorCamp/vectorscan &>> $logfile
error_check "Download of vectorscan repo"

cd /usr/src/vectorscan &>> $logfile
dir_check vectorscan-build
cd /usr/src/vectorscan/vectorscan-build &>> $logfile
cmake ../ &>> $logfile
error_check "CMake of vectorscan"

make -j $(nproc) &>> $logfile
error_check 'Make vectorscan'

make install &>> $logfile
error_check 'Installation of vectorscan'

########################################
#installing libsafec

print_status "Downloading, compiling, and installing $safec_ver.."

cd /usr/src &>> $logfile

wget $safec_latest_url &>> $logfile
error_check "Download of $safec_ver.tar.bz2"

#sooo... the maintainers of safec decided to save the directory name of the latest safeclib to...
#What I'm guessing is the code commit that is being shipped in the "latest" release.
#As a result the directory name is ugly as sin (e.g. libsafec-02092020.0-g6d921f is the untarred directory name)
#so we create a directory named after the current version of libsafec (e.g. libsafec-02092020)
#and pass arguments to tar to dump everything into that directory, and strip everything down one top-level directory.

dir_check $safec_ver
tar -xjvf $safec_ver.tar.bz2 -C $safec_ver --strip-components=1 &>> $logfile
error_check "Untar of $safec_ver.tar.bz2"
cd /usr/src/$safec_ver &>> $logfile

./configure &>> $logfile
error_check 'Configure safec libraries'

make -j $(nproc) &>> $logfile
error_check 'Make safec libraries'

make install &>> $logfile
error_check 'Installation of safec libraries'

########################################
#Download, compile and install gperftools

print_status "Downloading, compiling, and installing $gperftools_ver.."

cd /usr/src &>> $logfile

wget $gperftools_latest_url &>> $logfile
error_check "Download of $gperftools_ver.tar.gz"

tar -xzvf $gperftools_ver.tar.gz &>> $logfile
error_check "Untar of $gperftools_ver.tar.gz"

cd /usr/src/$gperftools_ver

./configure &>> $logfile
error_check "Configure $gperftools_ver"

make -j $(nproc) &>> $logfile
error_check "Make $gperftools_ver"

make install &>> $logfile
error_check "Installation of $gperftools_ver"

########################################
#need to install flatbuffers
#once again, downloading the tarball and untarring it results in an ugly directory name
#so, as always, I have to work around that.

cd /usr/src &>> $logfile

print_status "Downloading, compiling, and installing flatbuffers-$flatbuffers_latest_version.."

retry 3 wget $flatbuffers_latest_url -O flatbuffers-$flatbuffers_latest_version.tar.gz &>> $logfile
error_check "Download of flatbuffers-$flatbuffers_latest_version"


dir_check flatbuffers-$flatbuffers_latest_version
tar -xzvf flatbuffers-$flatbuffers_latest_version.tar.gz -C flatbuffers-$flatbuffers_latest_version --strip-components=1 &>> $logfile
error_check "Untar of flatbuffers-$flatbuffers_latest_version.tar.gz"
cd /usr/src/flatbuffers-$flatbuffers_latest_version &>> $logfile

dir_check flatbuffers-build
cd /usr/src/flatbuffers-$flatbuffers_latest_version/flatbuffers-build &>> $logfile
cmake ../ &>> $logfile
error_check "cmake of flatbuffers-$flatbuffers_latest_version"

make -j $(nproc) &>> $logfile
error_check "Make of flatbuffers-$flatbuffers_latest_version"

make install &>> $logfile
error_check "Installation of flatbuffers-$flatbuffers_latest_version"

########################################
#Need to install libdaq

cd /usr/src &>> $logfile

print_status "Downloading, compiling, and installing libdaq-$snort3_libdaq_version_string.."

retry 3 wget -O $snort3_libdaq_tarball $snort3_libdaq_latest_url &>> $logfile
error_check "Download of libdaq-$snort3_libdaq_version_string"

tar -xzvf $snort3_libdaq_tarball &>> $logfile
error_check "Untar of $snort3_libdaq_tarball"

cd /usr/src/$snort3_libdaq_dirstring

./bootstrap &>> $logfile
error_check "Bootstrap of libdaq-$snort3_libdaq_version_string"

./configure &>> $logfile
error_check "Configure libdaq-$snort3_libdaq_version_string"

make -j $(nproc) &>> $logfile
error_check "Make of libdaq-$snort3_libdaq_version_string"

make install &>> $logfile
error_check "Installation of libdaq-$snort3_libdaq_version_string"

########################################
#Finally, its time for the swine, snort3

cd /usr/src &>> $logfile

print_status "Downloading, compiling, and installing snort-$snort3_version_string.."

retry 3 wget -O $snort3_version_tarball $snort3_latest_url &>> $logfile
error_check "Download of snort-$snort3_version_string"

tar -xzvf $snort3_version_tarball &>> $logfile
error_check "Untar of snort-$snort3_version_tarball"
cd /usr/src/$snort3_dirstring

./configure_cmake.sh --prefix=/usr/local --enable-tcmalloc &>> $logfile
error_check "Configure snort-$snort3_version_string"

cd build &>> $logfile
print_notification "Compiling snort-$snort3_version_string.."
print_notification "This may take some time to complete."
print_notification "Users can view progress in another terminal window with the command: tail -f /var/log/autosnort3_install.log."

make -j $(nproc) &>> $logfile
error_check "Make snort-$snort3_version_string"

make install &>> $logfile
error_check "Installation of snort-$snort3_version_string"

#in my testing, I found that trying to run /usr/local/bin/snort -V failed.
#because snort couldn't find libdaq.so.3
#ldconfig fixes this, so I'm opting to run it now.

ldconfig &>> $logfile

########################################
#I'm going to take time now to install openappID detectors
#As well as the openappID listener and logging facilities.
#Noah does this a little later in this guide, but that results in having to reconfigure service files, as well as going back to modify the snort config.
#I'd rather handle that all in one go.
#This is a two-part thing. First we download the latest detectors from snort.org,
#Then we download and compile the snort3 extras package.

cd /usr/src &>> $logfile

print_status "Download and installing openappid detectors.."
retry 3 wget https://snort.org/downloads/openappid/snort-openappid.tar.gz &>> $logfile
error_check "Download of snort-openappid.tar.gz"

tar -xzvf snort-openappid.tar.gz &>> $logfile
error_check "Untar of snort-openappid"

cp -R /usr/src/odp /usr/local/lib &>> $logfile
error_check "odp directory copy to /usr/local/lib"

########################################
#Now, let's download and compile the snort3_extra stuff


print_status "Downloading, compiling, and installing snort3-extra.."

retry 3 wget -O $snort3_extras_tarball $snort3_extras_latest_url &>> $logfile
error_check "Download of $snort3_extras_tarball"

tar -xzvf $snort3_extras_tarball &>> $logfile
error_check "Untar of $snort3_extras_tarball"

cd /usr/src/$snort3_extras_dirstring &>> $logfile
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig &>> $logfile
./configure_cmake.sh --prefix=/usr/local &>> $logfile
error_check "Configure snort3_extra-$snort3_extras_version_string"

cd build &>> $logfile
make -j $(nproc) &>> $logfile
error_check "Make snort3_extra-$snort3_extras_version_string"

make install &>> $logfile
error_check "Installation of snort3_extra-$snort3_extras_version_string"

#In my (admittedly) limited testing, its entirely possible to put all of your major configuration options into a custom lua file
#Then all ya gotta do is just include a tiny include statement at the end of snort.lua to point to it.

#double check to make sure the virtual_labs_tweaks.lua file included in the git repo exists.

cd "$execdir" &>> $logfile
if [ ! -f "$execdir"/virtual_labs_tweaks.lua ]; then
	print_error "Unable to find $execdir/vm_labs_tweaks.lua. Please ensure the vm_labs_tweaks.lua file that shipped with Autosnort3 is there and try again."
	exit 1
else	
	print_good "Found $execdir/vm_labs_tweaks.lua."
fi

#run the grep command looking for the include line to our custom virtual_labs_tweaks.lua file in /usr/local/etc/snort/snort.lua
#If the grep command finds it (exit code 0), that means the include statment has already been appended to snort.lua.
#If the statement isn't found (exit code 1), append the include statement.

grep virtual_labs_tweaks.lua /usr/local/etc/snort/snort.lua &>> $logfile
if [ $? -eq 0 ]; then
	print_good '/usr/local/etc/snort/snort.lua already has the include statement to virtual_labs_tweaks.lua'
else
	print_status 'adding include statement for virtual_labs_tweaks.lua..'
	echo "include 'virtual_labs_tweaks.lua'" >> /usr/local/etc/snort/snort.lua
	error_check 'modification of snort.lua'
fi

#check to see of /usr/local/etc/snort/virtual_labs_tweaks.lua exists
#if it's already there, no further actions needed
#if it's not there, copy and make some minor modifications to the virtual_labs_tweaks file included in the autosnort3 repo (based on information users provide in full_autosnort.conf)
#once the temporary file has been modified, copy it to /usr/local/etc/snort/virtual_labs_tweaks.lua

print_status 'checking to see of /usr/local/etc/snort/virtual_labs_tweaks.lua exists..'
if [ -f /usr/local/etc/snort/virtual_labs_tweaks.lua ]; then
	print_good '/usr/local/etc/snort/virtual_labs_tweaks.lua already exists. No further changes needed.'
else
	cp virtual_labs_tweaks.lua virtual_labs_tweaks.lua.tmp &>> $logfile
	sed -i "s#snort_iface1#$snort_iface_1#g" virtual_labs_tweaks.lua.tmp &>> $logfile
	sed -i "s#snort_iface2#$snort_iface_2#g" virtual_labs_tweaks.lua.tmp &>> $logfile
	cp virtual_labs_tweaks.lua.tmp /usr/local/etc/snort/virtual_labs_tweaks.lua &>> $logfile
	error_check 'Copy of virtual_labs_tweaks.lua copied to /usr/local/etc/snort/virtual_labs_tweaks.lua'
	rm -rf virtual_labs_tweaks.lua.tmp &>> $logfile
fi

########################################
#downloading and configuring pulledpork

cd /usr/src &>> $logfile

print_status "Downloading and installing pulledpork3 rule manager.."

#git clone refuses to download if the directory is already there and has files in it, so this check is to see if the directory is there, and nuke it.
if [ -d /usr/src/pulledpork3 ]; then
	rm -rf /usr/src/pulledpork3
fi

git clone https://github.com/shirkdog/pulledpork3 &>> $logfile
error_check 'Download of pulledpork3'

#Creating a bunch of files and directories that pulledpork wants to exist before it will run successfully.
dir_check /usr/local/etc/lists
dir_check /usr/local/etc/rules
dir_check /usr/local/etc/so_rules
dir_check /var/log/snort
dir_check /usr/local/etc/pulledpork3

touch /usr/local/etc/rules/snort.rules
touch /usr/local/etc/rules/local.rules
touch /usr/local/etc/lists/default.blocklist
touch /usr/local/etc/pulledpork3/enablesid.conf
touch /usr/local/etc/pulledpork3/disablesid.conf
touch /usr/local/etc/pulledpork3/enablesid.conf
touch /usr/local/etc/pulledpork3/dropsid.conf
touch /usr/local/etc/pulledpork3/modifysid.conf


cp /usr/src/pulledpork3/pulledpork.py /usr/local/etc/pulledpork3/ &>> $logfile
error_check 'Copy of pulledpork.py to /usr/local/etc/pulledpork3'
cp -r /usr/src/pulledpork3/lib /usr/local/etc/pulledpork3
error_check 'Copy of pulledpork lib directory to /usr/local/etc/pulledpork3'

#Autosnort ships with an almost complete pulledpork.conf for pulledpork3. We use sed to add in the oinkcode
#And grab the CONFIGURATION_NUMBER variable from the pulledpork.conf that ships with pulledpork3.
#These values, along with the other configuration lines in pulledpork.conf are REQUIRED for pulledpork.py to work.

cd "$execdir" &>> $logfile

if [ ! -f "$execdir"/pulledpork.conf ]; then
	print_error "Unable to find $execdir/pulledpork.conf. Please ensure the pulledpork.conf file that shipped with Autosnort3 is there and try again."
	exit 1
else
	print_good "Found $execdir/pulledpork.conf. Configuring.."
	cp pulledpork.conf pulledpork.conf.tmp &>> $logfile
	sed -i "s/<oinkcode>/$o_code/" pulledpork.conf.tmp &>> $logfile
	grep "^CONFIGURATION_NUMBER =" /usr/src/pulledpork/etc/pulledpork.conf >> pulledpork.conf.tmp
	cp pulledpork.conf.tmp /usr/local/etc/pulledpork3/pulledpork.conf &>> $logfile
	error_check 'Copy pulledpork.conf to /usr/local/etc/pulledpork3'
fi

print_status "Running pulledpork.py.."
print_notification "This may take some time based on internet connection speed, etc."
print_notification "If you notice this portion of the script appears to be hanging, check /var/log/autosnort3_install.log to confirm"
print_notification "If the script CONTINUES to hang, consider checking network connectivity, including the http_proxy and https_proxy variables."

#pulled pork options:
#-vv for extra verbose mode. I want logs in the autosnort3_install.log file if this command croaks
#-c pointing to the config file we just copied/created in /usr/local/etc/pulledpork
#-i ignore warnings

retry 3 /usr/local/etc/pulledpork3/pulledpork.py -c /usr/local/etc/pulledpork3/pulledpork.conf -i -vv &>> $logfile
error_check 'pulledpork.py rule download'
	
#If a crontab backup we've made already exists, restore it so we don't end up with duplicate crontab entries
if [ -f /etc/crontab_bkup ]; then
	print_notification "Found /etc/crontab_bkup. Restoring original crontab to prevent duplicate cron entries.."
	cp /etc/crontab_bkup /etc/crontab &>> $logfile
	chmod 644 /etc/crontab &>> $logfile
	error_check 'crontab restore'
fi

#Make a backup of the existing crontab before we munge it.
print_status "Backup up crontab to /etc/crontab_bkup.."
cp /etc/crontab /etc/crontab_bkup &>> $logfile
chmod 600 /etc/crontab_bkup &>> $logfile
error_check 'crontab backup'

#Adding job that runs each day at midnight to download rules
#bear in mind, for virtual labs students this script will absolutely fail without the http_proxy and/or https_proxy variables being set.
print_status "Adding entry to /etc/crontab to run pulledpork Sunday at midnight (once weekly).."
echo "#This line has been added by Autosnort to run pulledpork for the latest rule updates." >> /etc/crontab
echo "  0  0  *  *  *  root /usr/local/etc/pulledpork3/pulledpork.py -c /usr/local/etc/pulledpork3/pulledpork.conf -i -vv" >> /etc/crontab

print_notification "crontab has been modified. If you want to modify when pulled pork runs to check rule updates, modify /etc/crontab."


print_status "Checking for snort user and group.."

getent passwd snort &>> $logfile
if [ $? -eq 0 ]; then
	print_notification "snort user exists. Verifying group exists.."
	id -g snort &>> $logfile
	if [ $? -eq 0 ]; then
		print_notification "snort group exists."
	else
		print_notification "snort group does not exist. Creating and adding snort user to group.."
		groupadd snort &>> $logfile
		usermod -G snort snort &>> $logfile
	fi
else
	print_status "Creating snort user and group.."
	groupadd snort
	useradd -r -s /sbin/nologin -g snort snort &>> $logfile
	error_check 'snort user creation'
fi

print_status "Tightening permissions to /var/log/snort.."
chmod 5775 /var/log/snort &>> $logfile
chown -R snort:snort /var/log/snort &>> $logfile

########################################
#Installing the snort3 startup script.
#Before we begin, we verify that the service file isn't already in /etc/systemd/system
#and that the snort3.service file exists in the directory users executed the main script from (for us to copy/modify it)
#We make a second copy of the snort3.service script, make some changes based on the full_autosnort.conf file, then move that copy to enable the service.

#4/18/21: one slight difference between Ubuntu 20.04 and 18.04 is where the ip and sbin binaries live.
#18.04: they lived in /sbin 20.04: they live in /usr/sbin.
#this matters, because systemd needs to know the absolute path for any binaries or scripts you need to execute for a service file.
#to make the snort3.service script compatible with both 18.04 and 20.04
#we'll check for the existence of /usr/sbin/ip and /usr/sbin/ethtool
#if they don't exist, we'll run ln -s `which ip` /usr/sbin/ip and ln -s `which ethtool` /usr/sbin/ethtool
#this'll create symlinks so that snort3.service works on either 18.04 or 20.04 (and hypothetically, other distros)

if [ ! -f /usr/sbin/ip ]; then
	print_notification "creating symlink from `which ip` to /usr/sbin/ip.."
	ln -s `which ip` /usr/sbin/ip
	error_check 'symlink creation'
fi

if [ ! -f /usr/sbin/ethtool ]; then
	print_notification "creating symlink from `which ethtool` to /usr/sbin/ethtool.."
	ln -s `which ethtool` /usr/sbin/ethtool
	error_check 'symlink creation'
fi

cd "$execdir" &>> $logfile

if [ -f /etc/systemd/system/snort3.service ]; then
	print_notification "Snort3 startup script already installed."
else
	if [ ! -f "$execdir"/snort3.service ]; then
		print_error" Unable to find $execdir/snort3.service. Please ensure  the snort3.service file is there and try again."
		exit 1
	else
		print_good "Found snort3 systemd service script. Configuring.."
	fi
	
	cp snort3.service snort3_2 &>> $logfile
	sed -i "s#snort_iface1#$snort_iface_1#g" snort3_2 &>> $logfile
	sed -i "s#snort_iface2#$snort_iface_2#g" snort3_2 &>> $logfile
	cp snort3_2 /etc/systemd/system/snort3.service &>> $logfile
	chown root:root /etc/systemd/system/snort3.service &>> $logfile
	chmod 644 /etc/systemd/system/snort3.service &>> $logfile
	systemctl daemon-reload &>> $logfile
	error_check 'snort3.service installation'
	print_notification "Location: /etc/systemd/system/snort3.service"
	systemctl enable snort3.service &>> $logfile
	error_check 'snortd.service enable'	
	rm -rf snort3_2 &>> $logfile
fi

########################################

print_status "Rebooting now.."
init 6
print_notification "The log file for autosnort is located at: $logfile" 
print_good "We're all done here. Have a nice day."

exit 0