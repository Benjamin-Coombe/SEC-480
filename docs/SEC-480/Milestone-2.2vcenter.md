# Prerequisites

* On MGMT1, you will need to change your IPv4 settings use your domain controller as DNS server with a search domain of yourname.local
* Ensure connectivity and nslookup for your super, which you can do by adding an entry for it in /etc/hosts

  * Nslookup to vcenter.yourname.local will need to resolve in order for the vcsa install to work properly
* Create DNS records for your vCenter & ESXi
* Make sure your ESXI host is synched to ntp.org

  * Host->manage>time & date> NTP Server: pool.ntp.org

## Step 1

On MGMT1 - Mount your VCSA ISO make sure that your CDROM is connected. Once mounted you can navigate to /media/user/VMWare VCSA/vcsa-ui-installer/lin64. Then you can run ./installer **You may need to add `--no-sandbox` to the installer command**

## Step 2

Run through installer (this may take some time, 2 stages…)

* Thin Disk!!, select the new datastore you created. don’t lose your VCSA root pass OR default SSO admin password, these are not recoverable. Luckily you can use the same password for both logins. Create your default vcenter domain & admin.


Most of this milestone is following what the vcsa installer tells you to do with the information that you already have, so all in all this was not very technical so i do not know what to put down here.
