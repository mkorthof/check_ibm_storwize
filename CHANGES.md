# Changes

## 2020-09-21

- changed: warn instead of crit for raidstatus=0 (unknown/expand)

## 2020-08-25

- added: vol capacity
- added: perfdata
- changed: warn/crit/skip

## 2020-08-07

- fixed: warn for sync/init mdisk
- fixed: warn for 1 port down, >2 critical
- added: skip option for iogrp
- added: critical for >95% pool usage
- added: bytes optie
- cleanup/syntax

## 2019-06-15

- fixed: warn en crit opties
- changed: disks without Status 2 'OK' (or 'online') = CRITICAL
- changed: no EnclosureIDGoal or SlotIDGoal = UNKNOWN
- added: skip element option with regex (e.g. for "test" pools/disks)
- added: exception handling (failed connection or login)
- added: debug option

