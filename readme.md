# Autosnort3 - Make your swine run like it's *Divine*
## What is Autosnort3?
Hello.
Welcome to my little github project. Autosnort 3 is a bash shell script that takes all of the hard manual labor out of compiling Snort 3 from source, and does it all for you.

This script is primarily for students attempting to built Snort for my book, Building Virtual Machine Labs: A Hands-On Guide (Second Edition), and/or the very soon to be announced updated Applied Network Defense training, bearing the same name.

I'll get into the details of what this script does in a little bit.

## Supported Operating Systems
As of right now, Autosnort3 is only supported on Ubuntu 20.04 *but*, This script is 90% based on the work of Noah Dietrich, and his installation guide for Snort 3 on Ubuntu 18.04 *and* 20.04. A very special thank you and a link to Noah's work:

https://snort.org/documents/snort-3-1-0-0-on-ubuntu-18-20

This means that hypothetically (until I actually bother to test it myself) this script *should* run on Ubuntu 18.04.

## Prerequisites
**System Resource Recommendations:** at a minimum, I recommend a system with at least:

 - [ ] 1 CPU core
 - [ ] 4GB of RAM
 - [ ] 80GB of disk space
 - [ ] 3 network interfaces (one for management traffic, two for inline operation)

These are the specs for the VM I used to test this script and build snort. As the name **Snort** implies, **this software is a hog**. And like with most software, the more resources has available, the better it will perform. In particular, Snort 3 is multi-threaded now, so multiple CPU cores are *extremely* valuable.

**OS Recommendations:** I used Ubuntu 20.04 to build and test this script, so its what I recommend using. If you want to use another Debian-based distro, be my guest. *However* that is entirely unsupported.

**Other Recommendations:** 
**This script *requires* an oinkcode to run.** If you don't know what that is, head to https://snort.org/users/sign_up and register an account. When you complete the registration process, log in and view your account information. That oinkcode needs to be copied to the `full_autosnort.conf` file

**This script takes a significant period of time to run.** Hyperscan takes a long time to compile, as does snort 3 itself. If you're using the minimum system requirements, you'll need at least 1-2 hours for it to compile and configure everything. That's also assuming a moderately decent internet connection required to download everything.

**This script defaults to assuming you want to run Snort3 in inline mode.** If you don't want that, I'll show you how to undo that in a little bit.

## What does this script do *exactly*?
Autosnort3 automates all of the following tasks:
 - Installs all of the prerequisites available from the Ubuntu repositories for both Snort3 as well as pulledpork, the recommended rule management software for Snort3.
 - Installs a whole bunch of prerequisites that Noah recommended compiling from source. Including:
	 - libsafec
	 - pcre
	 - gperftools
	 - ragel (specifically, version 6.10)
	 - downloads and unpacks the C++ boost source (for use with hyperscan)
	 - hyperscan (takes a **long** time to compile)
	 - flatbuffers
	 - libdaq
 - Installs Snort 3 (also takes a **long** time to compile)
	- Also installs the OpenAppID detectors, and OpenAppID listener plugin (via Snort3 extras)
	- Creates the snort system user and group in order for the snort process to drop its privileges after startup
 - Configures Snort 3 for operation through the included `virtual_labs_tweaks.lua` file, making the following configuration changes:
	 - Enables the built-in/preprocessor rules
	 - Uses the default variable settings
	 - Enables the IP blacklist via the IP reputation function
	 - Enables hyperscan as the preferred pattern matching engine
	 - Enables JSON logging for snort alerts (logs to: `/var/log/snort/alert_json.txt`, configured to rollover after 1GB)
	 - Enables JSON logging for the OpenAppID listener (logs to: `/var/log/snort/appid-output.log`)
	 - Configures the DAQ for inline mode operation, using the interface names defined in the `full_autosnort.conf` file
 - Installs, configures and runs pulledpork, a rule download and configuration management script with the following arguments:
	 - `-W` (this option is used to work around strange bugs where LWP doesn't appear to honor the http_proxy and https_proxy variables)
	 - `-vv` (high verbosity, logging all events to the `/var/log/autosnort3_install.log` file for debugging purposes)
	 - `-c /usr/local/etc/pulledpork/pulledpork.conf` (location of the primary configuration script)
		 - The pulledpork.conf that ships with Autosnort3 sets the IDS policy to "security"
	- `-l` (log major successes or failures to syslog)
	- `-P` (process rules even if no new rules were downloaded)
 - A cron job is configured to run `pulledpork.pl` daily at midnight with all of the arguments above, except for `-vv`
 - Configures the service `snort3.service` that performs the following tasks
	 - Enables service persistence for snort3, and will also try to re-start the service if the snort process dies, and retries every 60 seconds
	 - runs `ethtool` on service startup against both network interfaces defined in `full_autosnort.conf` to disable both the LRO and GRO settings
	 - runs `ip link` against both network interfaces defined in `full_autosnort.conf`, configuring them to: 
		 - ignore arp requests
		 - ignore multicast requests
		 - run in promiscuous mode. 
			 - This effectively means that these network interfaces will listen to any and all network traffic it can see on their respective network segments, they invisibly forward traffic in inline mode.
			 - The interfaces will **NOT** respond to any network traffic directed specifically towards either interface.
	- Runs snort with the following arguments:
		- `-c /usr/local/etc/snort/snort.lua` (where the configuration file lives)
		 - `-D` (daemonize)
		 - `-u snort -g snort` (run as the `snort` user and group after startup)
		 - `-l /var/log/snort` (drop log files and pid files into the `/var/log/snort` directory)
		 - `-m 0x1b` (create files with a `umask` of `033 (rw-r--r--)`)
		 - `--create-pidfile` (creates a pid file for service management in `/var/log/snort` named `snort.pid`)
		 - `--plugin-path=/usr/local/lib/snort_extra` (specifies the directory where additional custom snort3 plugins can be found such as the appid_listener plugin)
		 - `-s 65535` (sets the maximum ethernet frame length to the theoretical max of 65,535 to ensure that snort does not discard oversized frames.)
		 - `-k none` (do not drop packets with bad checksums)
		 - `-Q` (changes the DAQ operating mode from passive to inline, in addition to all of the custom DAQ configurations made in `virtual_labs_tweaks.lua`)

## Instructions for use
 1. Clone this repo (`git clone https://github.com/da667/Autosnort3`)
 2. cd into `Autosnort3/Ubuntu/AVATAR`
 3. using your favorite text editor, open `full_autosnort.conf`
 4. input the names of the network interfaces you'd like to bridge together for inline mode (if you want to use inline mode) in the `snort_iface_1=` (line 12) and `snort_iface_2=` (line 20) fields. For example, the script defaults to the interface names `eth1` and eth2.
 5. copy your oinkcode to the `o_code=` field (line 32)
 6. the script file, autosnort3-Ubuntu.sh needs to specifically be ran with the `bash` interpreter, and with `root` permissions.
- If you downloaded the script as the `root` user, bash autosnort3-Ubuntu.sh will work
- Alternatively, as the root user: `chmod u+x autosnort3-Ubuntu.sh && ./autosnort3-Ubuntu.sh`
- or via `sudo`: `sudo bash autosnort3-Ubuntu.sh`, etc.

That's all there is to it. Once the script starts running, you'll get status updates printed to the screen to let you know what tasks is currently being executed. If you want to make sure the script isn't hanging you can run `tail -f /var/log/autosnort3_install.log` to command output.

## The script bombed on me. Wat do?
Every tasks the script performs gets logged to `/var/log/autosnort3_install.log`. This will *hopefully* make debugging problems with the script much easier. Take a look and see if you can figure out what caused the installer script to vomit.

## I am not interested in inline mode operation at all. Wat do?
Fun fact: the `snort_iface_1` and `snort_iface_2` options in `full_autosnort.conf` aren't technically required. If you leave these fields blank, or their default values (assuming you don't have an `eth1` or `eth2` interface) the script will still finish. However, there are a couple of minor things you'll need to fix:
- Either modify or remove `/etc/systemd/system/snort3.service` . 
	- To remove, the service file entirely, run:
		- `systemctl disable snort3.service`
		- `rm -rf /etc/systemd/system/snort3.service`
	- To modify the file for passive operation, perform the following actions:
		- To stop inline mode operation, the `-Q` option will need to be removed from the snort command (line 17). 
		- Add the `-i [interface_name]` command line argument to line 17 define the network interface you'd like to use for IDS mode operation.
		- On lines 13 and 15, make sure you add the interface name you defined on line 17.
			- e.g. `/usr/sbin/ip link set up promisc on arp off multicast off dev [interface name]`
			- e.g. `/usr/sbin/ethtool -K [interface name] rx off tx off gro off lro off`
		- Remove lines 14 and 16.
- Either modify or remove the file `/usr/local/etc/snort/virtual_labs_tweaks.lua`
	- to remove the file,  run `rm -rf /usr/local/etc/snort/virtual_labs_tweaks.lua`
		- You'll also need to remove the `include 'virtual_labs_tweaks.lua'` statement at the very end of the `/usr/local/etc/snort/snort.lua` file.
	- If you want to keep the other configuration options while converting to passive mode operation, **in addition ot the changes you made to snort3.service**, remove the following section from the file, using your favorite text editor:
> daq =
{
    module_dirs =
    {
        '/usr/local/lib/daq',
    },
    modules =
    {
        {
            name = 'afpacket',
            mode = 'inline',
            variables =
            {
                'fanout_type=hash'
            }
        }
    },
    inputs =
    {
        '[network interface1]:[network interface 2]',
    }
}

## Licensing

This script is released under the MIT license. There is no warranty for this software, implied or otherwise.

## Acknowledgements

A big thanks to Noah for all of his hard work documenting the installation process on Ubuntu. I relied heavily on his work in order to create this lazy bunch of shell scripts.
