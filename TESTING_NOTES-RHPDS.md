# RHPDS Testing Notes

RHPDS can be used to test and evaluate this. There is not a service with
this in place, obviously, but can be installed into one of services provided.

"Infrastructure Migration 1.1 GA" is suitable, as it contains 3 providers:
VMWare, RHV and OpenStack.

* Build a "Infrastructure Migration 1.1 GA" service
* An ssh.cfg file can be very helpful. Consider:
    ~~~~
    Host workstation-<uid>.rhpds.opentlc.com
      Hostname workstation-<uid>.rhpds.opentlc.com
      User jwarnica-redhat.com
      IdentityFile ~/.ssh/lab_key

    Host *rhpds.opentlc.com
        ProxyCommand ssh -W %h:%p jwarnica-redhat.com@workstation-<uid>.rhpds.opentlc.com -i ~/.ssh/csb_key

    ~~~~
    This allows you to SSH directly to hosts inside the lab, through the
    workstation, at the cost of the inside hosts no longer having SSH keys.

    SSH to the CF appliance with, e.g.
    `ssh -F ssh.cfg root@cf-e5e1.rhpds.opentlc.com` - first time with the lab password.
    Put your id_rsa.pub into /root/.ssh/authorized_keys for sanity.

* From CF UI:
  * Enable ' Git Repositories Owner' role.
  * Import GIT Automate repositories:
    * https://github.com/rhtconsulting/miq-Utilities.git
        * BLEEDING EDGE: https://github.com/jeffwarnica/miq-Utilities.git with some branch
    * https://github.com/jeffwarnica/rhc-miq-quickstart.git
  * If you plan on making any changes, my convention is to have matching xxx_working domains, just above in priority, to git
  backed things.
  * Create a "variables" domain, top priority
    * Copy in settings and settingsstore, and for settings, configure Embedded Methods
      for settings from miq-Utilities and rhc-miq-quickstart
  * Datstores might look like this:
    ![like this][Docs/AutomateSetup.png]
  * Import the Dialogs from this project, with the command line tools or the UI
  *