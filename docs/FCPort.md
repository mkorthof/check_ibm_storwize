# FCPort

Notes about port status and mof file (Managed Object Format)

## MOF

- FCIOPortID "The FC IO port ID of the port."
- PortID "Platform port ID supporting the port.
- NodeName "Name of the node containing the p

### OperationalStatus

> Indicates the current status of the port.
>
> Possible values are 2 ("OK") if the port is "active",  
> 6 ("Error") if the port is in "failure",  
> 10 ("Stopped") if the port is "inactive" or  
> 12 ("No contact") if the port is "not installed".

```
ValueMap            Values
 "0"                "Unknown"
 "1"                "Other"
 "2"                "OK"
 "3"                "Degraded"
 "4"                "Stressed"
 "5"                "Predictive Failure"
 "6"                "Error"
 "8"                "Starting"
 "7"                "Non-Recoverable Error"
 "9"                "Stopping"
 "10"               "Stopped"                  (Port unconfigured inactive)
 "11"               "In Service"
 "12"               "No Contact"
 "13"               "Lost Communication"
 "14"               "Aborted"
 "15"               "Dormant"
 "16"               "Supporting Entity in Error"
 "17"               "Completed"
 "18"               "Power Mode"
 ".."               "DMTF Reserved"
 "0x8000.."         "Vendor Reserved"
```

### StatusDescriptions

> "Strings describing the various OperationalStatus array "
> "values. For example, if "Stopping" is the value assigned "
> "to OperationalStatus, then this property may contain an "
> "explanation as to why an object is being stopped. "
> "Entries in this array are correlated with those at the same "
> "array index in OperationalStatus."

StatusDescriptions will show e.g. "OK", "Unknown" or "", so not really more info than OperationalStatus.

# IBM Support site

<https://www.ibm.com/support/pages/fc-ports-show-inactinnveconfigured-if-system-not-use>


Question
Why are ports displayed as inactive? FC Ports show "inactive_configured" if system is not in use

Cause
This is how system/code is designed/written.
Any FC port with an SFP installed is shown as 'configured' by design. The SFP is detected when the canister is started.

Answer

- lsportfc shows all FC connected ports active.
- From main GUI "system" all FC connected ports were active.

--- 

<https://www.ibm.com/support/pages/gui-shows-fc-ports-offline-information-about-port-status-lsportfc>

GUI shows fc ports as offline. Information about port status in lsportfc

Troubleshooting

Problem
Sometimes, the GUI shows a warning on the GUI Dashboard page, even though the ports are intentionally not use

Symptom
When you click more details, you see the unused ports highlighted in red.

Cause
In the GUI or the CLI output by using the CLI command lsportfc, for the Fibre Channel Port Status, there are three statuses possible.
 
Active_Configured  =  The port is connected via fiber (switch or direct connection) to a host fiber port, negotiated speed, and a Logical Drive is served to the host.

Inactive_Unconfigured  =  No SFP is installed in this fiber port

Inactive_Configured  =   An SFP is installed in the fiber port but there is no host device connected to the port or no LUN served down this port's path.

The fiber port status is based on the existence of SFPs and stable Fibre Channel connection to other devices. There are no CLI or GUI options to change this behavior.

Resolving The Problem
"Inactive_Configured" status for unused SFPs in ports is expected per the firmware design.

To change the status to "inactive_unconfigured" and to remove the alerts from the GUI, remove the SFPs from the unused ports.  Then, reset the adapters for those ports

GUI shows warning when ports Offline (unused) "Inactive configured"

- From Network --> Fiber Channel Connectivity FC ports show inactive_configured.
- This is because system is not in use, as soon as IOPS start, status of the FC ports change to "active", this is how system/code is designed.

---

lsportfc:
https://www.ibm.com/docs/en/flashsystem-9x00/8.2.x?topic=commands-lsportfc
