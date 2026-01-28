# Milestone 1

Milestone 1 is initial set-up of our server, and our firewall and managment vm. I will be adding most of the images later as most of them are not on my local machine, so this may look a little sparse until then.

## Prerequisites

1. A USB drive,preferably over 8 gigabytes in size
   1. This will be **wiped clean**, so transfer any data you would like to keep.
2. An already working computer that has a USB port and network connectivity with admin permissions
3. An ESXI iso
4. A server/computer that you want to run ESXI on

## Boot media

First, download a program that can format bootable media. In our case we used a utility named [RUFUS](https://rufus.ie/en/). Rufus can be aquired  either from the web or the microsoft store.  Rufus is a program that helps create and format bootable USB drives. *This is where you need admin privlages as rufus needs them to run.*

When opened rufus presents the window below. The Device input is for the drive that is being formated into a boot drive, **make sure this is not a drive you care about, it will be wiped clean.** In our case boot selection does not change as we had an ESXI .iso file provided, how to aquire one can be found [here](https://knowledge.broadcom.com/external/article/372545/download-esxi-patch-and-the-isos-for-lat.html).

The select drop down opens the file browser, an issue that was found and addressed was that the ISO was not showing in the file browser opened by Rufus. To remedy this open the file browser in a different window and navigate to the folder where the ISO is located, then click and drag the .iso file onto the Rufus window.

In our instance all other configuration options were left blank. After all previous steps were completed click the start button, this will take some time, when it is finished the **READY** bar at the bottom will be green. Do not hit the start button again.

![](assets/20260127_230900_image.png)

If no issues arose the boot media should be properly formatted. Insert the created boot media in the appropriate port on the host machine.

## Installing VMware ESXI

Once the boot media is inserted either power on or power cycle the host system. If there were no issues you should be brought to the installer.

# Images at the lab go in this section

# Submission video

[20260128_001112_20260128-0508-42.8046950.mp4](assets/20260128_001112_20260128-0508-42.8046950.mp4)

### Useful links

* [BROADCOM-Installing ESXi on a supported USB flash drive or SD flash card](https://knowledge.broadcom.com/external/article?legacyId=2004784)
* [NVIDIA-Installing VMware ESXI](https://docs.nvidia.com/ai-enterprise/deployment/vmware/latest/installing-esxi.html)
* [BROADCOM-Download latest ISOs and patches for vSphere ESXI](https://knowledge.broadcom.com/external/article/372545/download-esxi-patch-and-the-isos-for-lat.html)
