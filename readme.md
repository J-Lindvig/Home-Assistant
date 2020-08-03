
# Home Assistant by J-Lindvig
![Main screen](https://github.com/J-Lindvig/Home-Assistant-Master/raw/master/www/images/screenshots/scr_main_1.png)
This is my implementation of Home Assistant, it may not be for the faint of heart - but it is mine and I like it....
Please enjoy my madness and use what you can.
## Introduction
In my setup I have 2 instances of Home Assistant, a master and a slave. They are connected using [remote homeassistant](https://github.com/lukas-hetzenecker/home-assistant-remote).
The reason why I am using 2 Home Assistants is that I have 2 IKEA TRÅDFRI Gateways and each Home Assistant can *only* control one. Off course I could use another Zigbee gateway solution, but I was offered a second Gateway very cheap and wanted to distribute the payload.
## Master
The is the one in control, storing the recorder, having all the automations and scripts. Basically everything.
Furthermore it is the master who is serving the nicely formed GUI.
### Hardware
 - Raspberry Pi 3B+
   - PNY 240 GB SSD USB3.1
 - IKEA TRÅDFRI Gateway
	 - 34 Bulbs
	 - 1 Driver
	 - 4 Plugs
	 - 9 Remotes
	 - 1 Sensor
	 - 2 Dimmers
 - 2 Tuya Smartswitches
 - 3 Broadlink 3 rm mini
### Software
I have the following add-ons installed:
- MariaDB
- Google Drive Backup
- File editor
- SSH & Web Terminal
- Samba share
- RPC Shutdown
- Check Home Assistant configuration
## Slave ( in lack of better word )
### Hardware
 - Raspberry Pi 3B+
   - Kingston A1 32 GB microSD card
 - IKEA TRÅDFRI Gateway
	 - 36 Bulbs
	 - 1 Driver
	 - 5 Plugs
	 - 7 Remotes
	 - 4 Sensor
	 - 3 Dimmers
### Software
This Pi only has a IKEA integration and a few addons:

- File editor
- SSH & Web Terminal
- Check Home Assistant configuration
- AdGuard Home
- WireGuard
## Configuration
Since it is the master that is the **brain** of my setup I will solely focus on this setup.
My setup is heavily divided with `!include` and *packages* in multiple directories.
### Files
[configuration.yaml](https://github.com/J-Lindvig/Home-Assistant-Master/blob/master/configuration.yaml)
> Written with [StackEdit](https://stackedit.io/).