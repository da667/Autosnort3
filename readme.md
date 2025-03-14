# Autosnort3 - Make your swine run like it's *Divine*
## What is Autosnort3?
Hello.
Welcome to my little github project. Autosnort 3 is a bash shell script that takes all of the hard manual labor out of compiling Snort 3 from source, and does it all for you.

This script is primarily for students attempting to build Snort for my book, Building Virtual Machine Labs: A Hands-On Guide (Second Edition), and/or the very soon to be announced updated Applied Network Defense training, bearing the same name.

I'll get into the details of what this script does in a little bit.

## Supported Operating Systems
As of right now, Autosnort3 is supported on Ubuntu 20.04 and above. This script is 90% based on the work of Noah Dietrich, and his installation guide for Snort 3 on Ubuntu 18.04 *and* 20.04. A very special thank you and a link to Noah's work:

https://snort.org/documents/snort-3-1-17-0-on-ubuntu-18-20


## Prerequisites
**System Resource Recommendations:** at a minimum, I recommend a system with at least:

 - [ ] 1 CPU core
 - [ ] 4GB of RAM
 - [ ] 80GB of disk space
 - [ ] 3 network interfaces (one for management traffic, two for inline operation)

These are the specs for the VM I used to test this script and build snort. As the name **Snort** implies, **this software is a hog**. And like with most software, the more resources it has available, the better it will perform. In particular, Snort 3 is multi-threaded now, so multiple CPU cores are *extremely* valuable.

**OS Recommendations:** This script has been tested on Ubuntu 20.04 and above. If you want to use another Debian-based distro, be my guest. *However* that is entirely unsupported and untested.

**Other Recommendations:** 
**This script *requires* an oinkcode to run.** If you don't know what that is, head to https://snort.org/users/sign_up and register an account. When you complete the registration process, log in and view your account information. That oinkcode needs to be copied to the `full_autosnort.conf` file

**This script takes a significant period of time to run.** Snort 3 (and its prereqs) takes a long time to compile. If your system/VM has multiple cores, it'll go a bit faster. If you're using the minimum system requirements, you'll need at least 30+ minutes for it to compile and configure everything. That's also assuming a moderately decent internet connection required to download everything.

**This script defaults to assuming you want to run Snort3 in inline mode.** If you don't want that, I'll show you how to undo that in a little bit.

## What does this script do *exactly*?
Autosnort3 automates all of the following tasks:
 - Installs all of the prerequisites available from the Ubuntu repositories for both Snort3 as well as pulledpork, the recommended rule management software for Snort3.
 - Installs a whole bunch of prerequisites that Noah recommended compiling from source. Including:
	 - libsafec
	 - gperftools
	 - flatbuffers
	 - libdaq
 - Installs vectorscan, a drop-in replacement for hyperscan, a fast and powerful rule search method.
 - Installs Snort 3 (also takes a **long** time to compile)
	- Also installs the OpenAppID detectors, and OpenAppID listener plugin (via Snort3 extras)
	- Creates the `snort` system user and group in order for the snort process to drop its privileges after startup
 - Configures Snort 3 for operation through the included `virtual_labs_tweaks.lua` file, making the following configuration changes:
	 - Enables the built-in/preprocessor rules
	 - Uses the default variable settings
	 - Enables the IP blocklist via the IP reputation function
	 - Enables hyperscan as the preferred pattern matching engine
	 - Enables JSON logging for snort alerts (logs to: `/var/log/snort/alert_json.txt`, configured to rollover after 1GB)
	 - Enables JSON logging for the OpenAppID listener (logs to: `/var/log/snort/appid-output.log`)
	 - Configures the DAQ for inline mode operation, using the interface names defined in the `full_autosnort.conf` file
 - Installs, configures and runs pulledpork3, a rule download and configuration management script with the following arguments:
	 - `-vv` (high verbosity, logging all events to the `/var/log/autosnort3_install.log` file for debugging purposes)
	 - `-c /usr/local/etc/pulledpork/pulledpork.conf` (location of the primary configuration script)
	 - `-i` (ignore warnings. We don't stop for warnings. Crying is not an emergency)
	   - The pulledpork.conf that ships with Autosnort3 sets the IDS policy to "security"
 - A cron job is configured to run `/usr/local/etc/pulledpork3/pulledpork.py` daily at midnight
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
		 - `--plugin-path=/usr/local/etc/so_rules` (specifies where to find the shared object rules, which snort3 views as "plugins"
		 - `-s 65535` (sets the maximum ethernet frame length to the theoretical max of 65,535 to ensure that snort does not discard oversized frames.)
		 - `-k none` (do not drop packets with bad checksums)
		 - `-Q` (changes the DAQ operating mode from passive to inline, in addition to all of the custom DAQ configurations made in `virtual_labs_tweaks.lua`)

## Instructions for use
 1. If you are running this script behind a proxy, make sure you run your export commands to set the http_proxy and https_proxy variables.
 - e.g. `export http_proxy=172.16.1.1:3128`
 - e.g. `export https_proxy=`
 2. Clone this repo (`git clone https://github.com/da667/Autosnort3`)
 3. cd into `Autosnort3/Ubuntu/AVATAR`
 4. using your favorite text editor, open `full_autosnort.conf`
 5. input the names of the network interfaces you'd like to bridge together for inline mode (if you want to use inline mode) in the `snort_iface_1=` (line 12) and `snort_iface_2=` (line 20) fields. For example, the script defaults to the interface names `eth1` and `eth2`.
 6. copy your oinkcode to the `o_code=` field (line 32)
 7. the script file, autosnort3-Ubuntu.sh needs to specifically be ran with the `bash` interpreter, and with `root` permissions.
- If you downloaded the script as the `root` user, `bash autosnort3-Ubuntu.sh` will work
- Alternatively, as the `root` user: `chmod u+x autosnort3-Ubuntu.sh && ./autosnort3-Ubuntu.sh`
- or via `sudo`: `sudo bash autosnort3-Ubuntu.sh`, etc.

That's all there is to it. Once the script starts running, you'll get status updates printed to the screen to let you know what tasks is currently being executed. If you want to make sure the script isn't hanging, you can run `tail -f /var/log/autosnort3_install.log` to view detailed command output.

## The script bombed on me. Wat do?
Every task the script performs gets logged to `/var/log/autosnort3_install.log`. This will *hopefully* make debugging problems with the script much easier. Take a look and see if you can figure out what caused the installer script to vomit.

## I am not interested in inline mode operation at all. Wat do?
Fun fact: the `snort_iface_1` and `snort_iface_2` options in `full_autosnort.conf` aren't technically required. If you leave these fields blank, or their default values (assuming you don't have an `eth1` or `eth2` interface) the script will still finish. However, there are a couple of minor things you'll need to fix:
- Either modify or remove `/etc/systemd/system/snort3.service` . 
	- To remove, the service file entirely, run:
		- `systemctl disable snort3.service`
		- `rm -rf /etc/systemd/system/snort3.service`
	- To modify the file for passive operation, perform the following actions:
		- To stop inline mode operation, the `-Q` option will need to be removed from the snort command (line 17 in the `snort3.service` file). 
		- Add the `-i [interface_name]` command line argument to line 17 define the network interface you'd like to use for IDS mode operation.
		- On lines 13 and 15, make sure you add the interface name you defined on line 17.
			- e.g. `/usr/sbin/ip link set up promisc on arp off multicast off dev [interface name]`
			- e.g. `/usr/sbin/ethtool -K [interface name] rx off tx off gro off lro off`
		- Remove lines 14 and 16.
- Either modify or remove the file `/usr/local/etc/snort/virtual_labs_tweaks.lua`
	- to remove the file,  run `rm -rf /usr/local/etc/snort/virtual_labs_tweaks.lua`
		- You'll also need to remove the `include 'virtual_labs_tweaks.lua'` statement at the very end of the `/usr/local/etc/snort/snort.lua` file.
	- If you want to keep the other configuration options while converting to passive mode operation, **in addition to the changes you made to snort3.service file**, remove the following section from the `virtual_labs_tweaks.lua` file, using your favorite text editor:
``` 
daq =
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
```
## Licensing

This script is released under the MIT license. There is no warranty for this software, implied or otherwise.

## Acknowledgements

A big thanks to Noah for all of his hard work documenting the installation process on Ubuntu. I relied heavily on his work in order to create this lazy of shell script.

## Known Problems
- The script may occasionally fail to download libdaq or snort 3. Reviewing `/var/log/autosnort3_install.log` may reveal an HTTP 500 error.
	- This denotes a problem with Cisco's servers lacking the capacity to service the request. The only recommendation I can offer at this time is to  re-run the script in the hope that the servers aren't busy.
- The script may occasionally fail to download the latest snortrules-snapshot via pulledpork.pl. Reviewing the `/var/log/autosnort3_install.log` may reveal pulledpork failed with Error 422: Unprocessable Entity.
	- According to an old github issue, they tried to blame this on the user inputting an invalid oinkcode into the `pulledpork.conf` file, but I've experienced this problem with a perfectly valid oinkcode. Personally, I think the 422 errorcode also masks a 500 code on the server-side. The snortrules-snapshots are hosted on amazon via snort.org, just like the libdaq and snort3 tarballs.
		- My recommendation is to check `full_autosnort.conf` and confirm that you've entered a valid oinkcode on line 32. As of mine writing this, oinkcodes are 40 character alphanumeric strings, so line 32 should read: `o_code=[40-character oinkcode here]`
		- If you've confirmed that your oinkcode is valid, my only other recommendation is to re-run the script.
 - If you're trying to run Snort3 in AFPACKET bridging mode on Proxmox, and you notice the bridge is only carrying ICMP and/or ARP requests, and devices are NOT communicating across the bridge, Be aware of the following:
    - As of right now, if your Snort3 VM (or Suricata for that matter) are using the virtio network cards, there are compatibility problems with virtio, promisc mode and AFPACKET bridging. There is no bug documented for this for Snort, but there is a Suricata bug... that is a few years old now: https://redmine.openinfosecfoundation.org/issues/5871
    - Switch to E1000, E1000E, RTL8139, or VMXNET3 driver for the NICs that will be in AFPACKET bridging mode **on your snort3/suricata VM**.
    - Yes, this is going to impact your throughput. In my testing, Max speed for E1000, E1000E and VMXNET3 are 1gbps. RTL8139 is 10/100Mbps only, according to the docs. I wouldn't use that if I were you.
    - You may need to set promisc mode on the bridge interfaces **on the proxmox console**:
      - `ip link set vmbr* promisc on`, replacing `vmbr*` with the names of the bridge interfaces the snort3/suricata VM are bridging. You'll need to run this command once for each bridge interface.
    - If things are still not working, several guides recommend running running these brctl commands **on the proxmox console**:
	  - `brctl setageing vmbr* 0`
	  - `brctl setfd vmbr* 0`
	- Again, these commands need to be for each proxmox Linux bridge your are attempting to bridge via Snort3/Suricata. Replace `vmbr*` with the names of the linux bridge interfaces that Snort3/Suricata are trying to bridge.
    - These config changes may not persist between reboots of proxmox. Look into editing `/etc/network/interfaces` to make them permanent.
## Patch Notes
 - 5/13/25
    - User Praetorian saw fit to remind me that Autosnort3 has been broken for some time. Thank you for the reminder, and making me get off my ass to improve this script.
	- Put the `apt-get` packages grabbed by this script in alphabetical order. Also added some pre-reqs to compile `vectorscan` libraries. More on this in a minute.
	- Replaced the Intel Hyperscan package with a compiled-from-source copy of vectorscan. Why? well a couple of reasons. First off, [There was an issue I pushed to the Snort3 github] (https://github.com/snort3/snort3/issues/366) regarding some changes made to libhyperscan that caused it to not play nice with Snort. I was essentially told `not my yob, use a different pattern matching engine if you can't get it to work` by the Snort team, and found out that 1) Hyperscan is no longer open-source, nor is the open-source version supported 2) vectorscan is the drop-in replacement.
	  - And so, here we are. We grab the prereqs, grab it from github, compile and install it.
	- We're using pulledpork3 now. Why? Using the Talos Lightspd with PP3 allows us to automatically grab the correct SO rules for the version, OS, and arch Snort3 is running on. We don't have to avoid SO rules anymore. Or do insane safety dances to get the right SO rules for the right engine. It's a good day to die.
	  - Don't get me wrong shared object rules still are absolutely awful.
	- The cron job that tries to run pulledpork daily now tries to run pulledpork3 instead. I have no idea if this works. Good luck. If it's not working remove the entry from `/etc/crontab`.
	- For those who insist on wanting to use the old perl-based pulledpork, I have a file `pulledpork.conf.pl.old` that you can use for reference purposes if you really want to. The new `pulledpork.conf` is formatted for use with pulledpork3.
    - Speaking of SO rules, the `snort3.service` file has a second `plugin-path=` directive set to `/usr/local/etc/so_rules/` because for some reason, even after editing it, I couldn't get `snort_defaults.lua` to see the so_rules directory. I hate snort3 so much.
	- replaced most `make` compile statements to `make -j $(nproc).` 
	  - `We multithreaded now.`and in less time than it took Snort3 to release.
 - 4/15/24
	- Had some reports from users over the weekend that safeclib download/compile was failing. I think they changed the filename format for safeclib, and also the order in which the files are listed, and that resulted in jq parsing attempting to download the wrong file.
	- Additionally, after I fixed that, the directory name was no longer correct because the tarball name and the directory name are different now, so now the script creates a directory and untars the file using the `-C` option to specify the directory the script creates, and `--strip-components=1` to ensure the files are exactly where the script expects it.
	- After I fix *that*, I introduced another problem by adding an `*` to the `cd` command to change directories to the safeclib directory. Remove the `*`, everything is working fine again.
	- Still looking at implementing pulledpork3 into the script. I'm torn right now, because pulledpork3 doesn't support the modification of rules right now. But pulledpork2 isn't actually parsing shared object rules for snort 3 correctly, and adding them to the rule config. Not to mention, I didn't know you had to specify the SO rules directory as a plugin path for shared object rules to actually do anything, but now I do.
		- I also recently learned the purpose of the talos_LightSPD ruleset. Its documented in one place. In a blog post from four years ago. The TL;DR is that if you use that instead of the `snortrules-snapshot-3.x.x.tar.gz` file, there's a manifest file that points where the correct SO rules for the OS and version of you are running. Turns out pulledpork3 handles all of that pretty well. Only downside is because it includes so many more SO rules, the filesize is considerably bigger (120ish MB, vs around 15 MB for a snortrules-snapshot file) I'm leaning towards adding it to the script in the near future. Again, stay tuned.
 - 10/16/23 (again)
	- Thanks to `@krishean@tech.lgbt`, I figured out how to use `jq` and the github API to pull the "latest" release version string via the github API for libdaq and snort3. Snort_extras was a little more work, but the bottom line is that the script is a lot less dependant on parsing raw HTML for pulling down the latest version of Snort3, libdaq, and snort_extras.
		- we still have to parse the HTML to determine what rule tarballs to attempt to download via pulledpork.
		- TODO: update to pulledpork3 (not yet completed)
	- Updated the readme to reflect that we are no longer compiling hyperscan from source, and also to confirm we no longer support Ubuntu 18.04
 - 10/16/23
	- Hey hey, Analysts. Its been a hot minute. 
	- A couple of users reported problems with the script failing to pull down the Snort3 source tarball. Due to them changing the snort.org page ever-so-slightly once more. Of course, my ability to parse HTML is impeccable. I mean, its not like Cisco doesn't have the resources to make a snort3/latest.tar.gz URI or anything. No, that would wouldn't be helpful _at_ _all_.
	- Made a couple of slight changes to the precompiled packages the script acquires. Some of these are just to ensure that certain packages Snort3 needs are present, while others are to greatly reduce the amount of time it takes to actually it actually takes to install Snort 3.
	- No more manually compiling Intel's hyperscan libraries. We just download `libhyperscan-dev`. I'm sick of wasting your time, and mine.
	- Made a slight change that will hopefully reduce the amount of time snort needs to compile slightly. I discovered that `$(nproc)` is a thing, so we can compile snort3 with `make -j $(nproc)` and have it auto-adjust for the number of cores available on your system. If all you have is a single core VM, you won't notice any changes, but if you have more than one core available... it'll help push things along much faster.
		- Sure, this will make your laptop fans start _*REEEEEEEEEEEEE*_'ing for a minute, but better than waiting 20-30 minutes for Snort to compile.
 - 5/20/23
    - Users are reporting an issue with compiling the flatbuffers library. If you get an error stating that the `test_assert.h` file does not exist, this is a known bug with flatbuffers. 
	- To make a long story short: there are some assumptions made as to where flatbuffers is being built, and that its not looking in the correct directory for the `test_assert.h` header file during compilation (https://github.com/google/flatbuffers/issues/7947). Two options to fix this problem:
		- Wait for google to push a new release of flatbuffers in which the fix is rolled in. By looking at their release cadence, they seem to push a new release of flat buffers bi-weekly or monthly. Its been about two weeks since this issue was found, so maybe they'll be doing a new release soon? Or... 
		- Run `autosnort3-Ubuntu.sh` as normal, and wait for flatbuffers to fail to compile. Afterwards, run the command:
	 `cp /usr/src/flatbuffers-[current_version]/tests/test_assert.h /usr/src/flatbuffers-[current_version]/flatbuffers-build/tests/` then run the `autosnort3-Ubuntu.sh` script again, as normal. With most of the other libraries and prereqs already compiled and in place, re-running the script up to this point will be much faster.
	- I'm getting a feeling of de ja vu. In troubleshooting the problem above, I noticed that libdaq was failing to download. I had to make a slight change to the URL used to pull down libdaq tarballs, but hopefully it should be working as intended now
 - 6/23/22
	- A user reported a problem with the openappid listener not operating properly. Wasn't even creating a log file. After going through some troubleshooting, I was able to reproduce the issue. It turns out this is because new versions of the openappid listener in the snort_extras tarball are installed to the `snort` directory, instead of `snort_extras` like it use to be. Yay for arbitrary directory changes! The `snort3.service` file has been updated to reflect this change, resolving the problem. Thanks to @Smicker_RS for reporting this problem.
 - 3/23/22
	- The maintainer for the safec github has changed the name of their tarball, and have also changed how they are listed on the releases page. Fixed an issue reported by Vito Ferrara where safec was failing to download due to this change in file listing and filename. The script should properly parse the github releases page, download the right package, and automatically unpack it like normal. Thank you!
 - 1/6/22
	- Happy new year! Several users of Autosnort3 have reported that the script fails to run on Ubuntu Server 21.10. While officially the script is only supported on Ubuntu 18.04 and 20.04, I'm a firm believer in situational awareness. That is, if there's a problem with the interim "look at the new technology we'll be jamming into future Ubuntu releases", then there's a pretty good chance these problems will make it into the next LTS release if they aren't fixed or worked around.
	- This issue centers around Intel's Hyperscan library, a pretty integral part of Snort3. For some reason, it fails to compile on 21.10, where it was perfectly fine in Ubuntu 20.04. Unfortunately, fixing this problem is beyond my feeble brain, so I've opened in issue on github for the intel hyperscan project.
	- https://github.com/intel/hyperscan/issues/344
	- I have no idea what the root cause is, or what the resolution is. In the interim however, I've discovered that Canonical provides a libhyperscan software package that comes pre-compiled. I don't know why Noah Dietrich specifically recommends compiling hyperscan, but I DO know that by using apt to install libhyperscan-devel, Snort3 WILL compile and `Snort -V` confirms that it was compiled against hyperscan.
	- Sooo I just created a small if/then that detects if the make command failed to run and if it does, falls back and attempts to install the libhyperscan-devel package via apt-get. Yeah, its grody, but it works.
	- Noticed the `unzip` command, used to decompress the pcre source code, defaults to prompting to overwriting pre-existing files and folders. This is probably good design, but not in a script that is supposed to be completely hands-free. If users have ran the autosnort script, and it fails after having unzipped the PCRE sources from a previous run, the script stops, waiting for user input as to whether or not it should overwrite the unzipped PCRE source directory. To fix this, Changed line 269 to run `zip -o` (blindly overwrite files without prompting).
	- Fixed the dead link to Noah's documentation on how to build Snort on Ubuntu 18/20.04. The link above now points to a newer version of the document. 
	- Unfortunately, this link is NOT on the snort.org site as of 1/6, and hasn't been there since Snort 3.17 was released in November. 
	- What's even better is that the previous document is NOT available via the internet archive, because it wasn't able to crawl the AWS link to where the PDF is actually hosted. 
	- Not sure if  this is a hosting configuration option that Cisco dreamt up, or if this is a default configuration for AWS hosted content, but I can't say I like it. Anyhoo I informed that powers that be™ about the lack of a link to the updated documentation, and allegedly it will be fixed soon™.
 - 11/28/21
	- pcre.org, the maintainers of the pcre version 1 library and source code decided they no longer wish to maintain their FTP server. This resulted in the script failing to download the latest PCRE 1 sources to compile.
	- autosnort3 requires the PCRE 1 sources specifically to compile hyperscan. Fortunately, they've decided to mirror the PCRE 1 source code over at sourceforge. 
	- The good news is that sourceforge has a "/latest" URI I can use to download the latest PCRE 1 source package, instead of having to  try and parse HTML using command-line tools to determine the latest version of the library available for download.
	- The bad news is that some people don't particularly like sourceforge. I'm not one of those people.
	- I've heard that there are problems running this script on Ubuntu 21.04. My official response is that 21.04 isn't supported by this script. Only Ubuntu Server 18.04 and 20.04 are officially supported at this time. My unofficial response is that, whatever is causing problems with 21.04 could potentially be a problem with the next LTS release (22.04), soooo I'm going to try and find a solution.
 - 6/4/21
    - Discovered that the libdaq download URL has an extra "v" that should not be in the download URL. The fix was just removing the extra "v" from libdaq download URL on line 212.
	- also had to modify the tarball name for libdaq on line 209. The name of the directory changed compared to the filename scraped from snort.org for the latest libdaq, so I needed to fix that as well.
 - 5/21/21
	- The hosting provider for the C++ boost source code changed. The script has been updated to reflect this.
 - 4/30/21
	- Fixed the problems I was having with the reputation preprocessor.
	- https://github.com/snort3/snort3/issues/178
	- This was a cut and dry case of RTFM. The proper terminology is now "blocklist = 'blah'" when using the reputation preprocessor. The reputation preprocessor has been re-enabled.
 - 4/29/21
	- Cisco changed where they are hosting the snort3 tarballs. the URLs on snort.org now redirect to official github releases. I complained about this when I submitted a recently pulledpork bug, but didn't think they'd actually bother doing anything. This means that everything is consistently hosted on github. Good on them! But also means that they broke the HTML parsing in my script that handles finding the latest libdaq, snort3, and snort3-extras downloads and actually downloading them. I've since fixed this problem.
	- Thanks to Raymond Kyte for reporting this issue.
	- I found a really great function for bash scripts called retry https://gist.github.com/sj26/88e1c6584397bb7c13bd11108a579746
	- Every single tarball download the script performs is now wrapped in retry and will attempt to wget/download the requested tarball at least 3 times before exiting the script entirely. Hopefully this will make the 500 server errors that snort.org has been throwing lately a little more bearable
	- Added a retry function to pulledpork to try downloading the latest rules tarball 3 times, and if it fails, try downloading a snortrules tarball for the previous snort 3 release as a last resort. This should help to deal with pulledpork failing to download rules, hopefully.
	- ~~Something is wrong with the reputation preprocessor. Either the `virtual_labs_tweaks.lua` file is configuring it incorrectly and I'm incompetent, or something is wrong with snort 3.1.4.0. Snort fails to start, and the only error in the log is that it can't file the file `reputation.blacklist` the only problem is that snort.lua, nor any of the files included in snort.lua define ANY file named reputation.blacklist. anywhere. Commenting out lines 50-53 in virtual_labs_tweaks.lua fixed this problem, however that means the IP reputation preprocessor is disabled until this problem can be fixed. Submitted a bug to snort3:  https://github.com/snort3/snort3/issues/178~~ (**fixed - turns out the syntax changed**)
 - 4/18/21
	- Added support for Ubuntu 18.04 by adding a small check to see if `/usr/sbin/ip` and `/usr/sbin/ethtool` exist. The `ip` command should already be on most modern Linux distros, and this script installs `ethtool`.  If they don't exist in `/usr/sbin`, create a symlink using the `which` command to figure out where the binaries actually are. 
	- The reason we have to do this is because systemd service files require absolute paths to any binaries or scripts you call. This is an easier work-around then having multiple `snort3.service` files for different linux distros.