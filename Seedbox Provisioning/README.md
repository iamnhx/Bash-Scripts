# Seedbox Installation Script

### Please note that this script will create a new user account to contain the BitTorrent clients using the provided password. For security reasons, it is highly recommended that you choose a strong password.
### The unit of Cache Size has been changed from Gibibytes (GiB) to Mebibytes (MiB), allowing for finer tuning and the script to be used on machines with less than 1 GB of RAM. (1 GiB = 1024 MiB)
### These scripts are intended to run only on freshly installed Debian 10/11.

The Tweaked BBR can increase the packet retransmission rate and potentially waste bandwidth. On a 10 Gbps network, the waste can be around 30% of your actual upload amount, and around 10% on a 1 Gbps network. Please use with caution if you are on a metered network.

## Usage
### deploy.sh
`bash <(wget -qO- https://raw.githubusercontent.com/iamnhx/Bash-Scripts/master/Seedbox%20Provisioning/deploy.sh) <username> <password> <Cache Size(unit:MiB)>`

### tune.sh if you have already installed clients (Note: this script can potentially break something, so use with caution)

`bash <(wget -qO- https://raw.githubusercontent.com/iamnhx/Bash-Scripts/master/Seedbox%20Provisioning/tune.sh)`

## Functions
### deploy.sh
###### 1. Install Seedbox Environment
	BitTorrent Clients:
		1. qBittorrent with tuning
		2. Deluge with tuning
	Autoremove-torrents with minimal configuration
###### 2. Tweaks
	CPU Optimization:
		1. Tuned
	Network Optimization:
		1. NIC Configuration
		2. ifconfig
		3. ip route
	Kernel Values:
		1. /proc/sys/kernel/
		2. /proc/sys/fs/
		3. /proc/sys/vm
		4. /proc/sys/net/core
		5. /proc/sys/net/ipv4/
	Drive Optimization:
		1. I/O Scheduler
		2. File Open Limit
	Tweaked BBR

### tune.sh
###### Tuning Options:
	1. Deluge Libtorrent tweaking (Only works on Libtorrent 1.1.14 with ltconfig plugins installed)
	2. System Tuning
		CPU Optimization
		Network Optimization
		Kernel Parameters
		Drive Optimization
	3. Tweaked BBR Installation
	4. Configuring Boot Script for certain tunings

### Fine Tuning Notes
- The cache size should be set to around 1/4 of the machine's total available RAM. In the case of qBittorrent 4.3.x, it is important to take into account memory leakage and set the cache size to 1/8.

- The default setting for aio_threads is 4, which should be sufficient for HDDs. For SSDs or even NVMe servers, you may want to consider increasing it to 8 or even 16.
	- For qBittorrent 4.3.x - 4.5.x, you can change this setting in the advanced settings tab.
	- For qBittorrent 4.1.x, you can set it in /home/$username/.config/qBittorrent/qBittorrent.conf by adding `Session\AsyncIOThreadsCount=8` under the [BitTorrent] section.
		- Please shut down qBittorrent before editing.
	- For Deluge, you can install [ltconfig](https://github.com/ratanakvlun/deluge-ltconfig/releases/tag/v0.3.1) and edit the aio_threads setting through the plugins.
		- aio_threads=8

- If you are running on a machine with poor I/O, you can set send_buffer_low_watermark, send_buffer_watermark, and send_buffer_watermark_factor to a lower value.
	- For qBittorrent 4.3.x, you can change these settings in the advanced settings tab.
	- For qBittorrent 4.1.x, you can set them in /home/$username/.config/qBittorrent/qBittorrent.conf by adding `Session\SendBufferWatermark=5120`,`Session\SendBufferLowWatermark=1024`, and `Session\SendBufferWatermarkFactor=150` under the [BitTorrent] section.
		- Please shut down qBittorrent before editing.
	- For Deluge, you can install [ltconfig](https://github.com/ratanakvlun/deluge-ltconfig/releases/tag/v0.3.1) and edit these settings through the plugins.
		- send_buffer_low_watermark=1048576
		- send_buffer_watermark=5242880
		- send_buffer_watermark_factor=150

- The default setting for tick_internal is 100, which can be too high for some weaker CPUs. Consider changing it to 250 or 500.
	- Unfortunately, there is no way to change this setting in qBittorrent.
	- For Deluge, you can install [ltconfig](https://github.com/ratanakvlun/deluge-ltconfig/releases/tag/v0.3.1) and edit this setting through the plugins.
		- tick_interval=250

- Additional fine-tuning notes can be found in /etc/sysctl.conf.

- For the file system, it is highly recommended to use XFS.

### Credit
qBittorrent Installation - https://github.com/userdocs/qbittorrent-nox-static

qBittorrent Password Set - https://github.com/KozakaiAya/libqbpasswd & https://amefs.net/archives/2027.html

Deluge Password Set - https://github.com/amefs/quickbox-lite

autoremove-torrents - https://github.com/jerrymakesjelly/autoremove-torrents

BBR Installation - https://github.com/KozakaiAya/TCP_BBR

