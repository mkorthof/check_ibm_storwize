# Sources

This script is based on different previous versions which have been worked on by a different couple people over the years. It got updated several times, adding e.g. new checks and other features.

## Shinken version (2015)

Called "pack-storwize" by [Forlot Romain](https://github.com/claneys)

### README

Shinken configuration pack for IBM Storwize Vxxxx 
You must install Standard Based Linux Instrumentation package:
- sblim-wbemcli

### Repository

[https://github.com/claneys/pack-storwize](https://github.com/claneys/pack-storwize)

# Templates

Nagios Templates examples are located in "pack" dir (and time_templates.cfg in "etc"), use as you see fit.

- time_templates.cfg (schedule, retries)
- commands.cfg (check_command)
- template.cfg (host, user, password)
- discovery.cfg (mgmt https check)
- services/cluster.cfg
- services/hotspare.cfg
- services/iogroup.cfg
- services/array.cfg
- services/backendvolume.cfg
- services/storagevolume.cfg
- services/node.cfg
- services/fcport.cfg
- services/enclosure.cfg
- services/arraysparecoverage.cfg
- services/ethernetport.cfg
- services/masterconsole.cfg
- services/storagepool.cfg
- services/disk.cfg
- services/mirrorextent.cfg

---

## Original Version (2013)

Script [check_ibm_svc.pl](<https://www.bityard.org/blog/_media/2013/12/28/check_ibm_storwize.pl>) by [Frank Fegert](https://www.bityard.org/blog/about) (SVN Id: "u09422fra")

As far is I know, this is the original first version

### Blog posts:

- [https://www.bityard.org/blog/2014/12/24/nagios_monitoring_ibm_svc_storwize_update](https://www.bityard.org/blog/2014/12/24/nagios_monitoring_ibm_svc_storwize_update)
- [https://www.bityard.org/blog/2013/12/28/nagios_monitoring_ibm_svc_storwize](https://www.bityard.org/blog/2013/12/28/nagios_monitoring_ibm_svc_storwize)
