# Changes

## 2022-12-16

- added: TriggerAlert setting for FCPort (rcmap)

## 2022-12-02

- changed: moved nagios templates to "/etc"

## 2022-12-01

- fixed: "half count" of ports/hosts, would always trigger on first interation (`0 < 1`)

## 2022-11-26

- added: tests
    - [test](/test) dir with mock txt files and `test_checks.sh` to test all Checks
    - flags for mocks and local cim server (see [docs/Development.md](docs/Development.md))
- changed: FCPort
    - show status "Stopped" (`OperationStatus=10`), do not alert ([#1](https://github.com/mkorthof/check_ibm_storwize/issues/1))
    - show "Not installed" (status 12), do no alert
    - show "Configured inactive" and alert (uses `StatusDescriptions` if set)
    - name uses node-portid if elementname unset
- changed: warning and critical thresholds 
    - added default vars
    - separated between percentage and failed items (see `-h`)
- added: docs dir

## 2021-01-19

- changed: small fix for convSpeed, typos and clearified readme

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
- added: bytes option
- cleanup/syntax

## 2019-06-15

- fixed: warn en crit options
- changed: disks without Status 2 'OK' (or 'online') = CRITICAL
- changed: no EnclosureIDGoal or SlotIDGoal = UNKNOWN
- added: skip element option with regex (e.g. for "test" pools/disks)
- added: exception handling (failed connection or login)
- added: debug option

