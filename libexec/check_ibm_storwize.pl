#!/usr/bin/perl -w
# nagios: +epn
#
# IBM Storwize & FlashSystem health status plugin for Nagios
#
# Updated version: tested with v8.3.1, V7000 G3 model and iSCSI
# Needs: wbemcli to query the Storwize Arrays CIMOM server
#

use warnings;
use strict;
use Getopt::Std;
use Time::Local;

#
# Variables
#
my $version = "v20221202-test-mk";
my %conf = (
    namespace => '/root/ibm',
    service => 'IBMTSSVC',
    wbemcli => '/usr/bin/wbemcli',
    wbemcli_opt => '-noverify -nl',
    debug => '0',
    test => '0',
    bytes => '0',
    skip => '',
    DEFAULTS => {
        ArrayBasedOnDiskDrive => { w => '0', c => '0' },    # no spare
        ConcreteStoragePool => { w => '80', c => '90' },    # %usage (c 100 to warn only)
        IOGroup => { w => '0', c => '0' },                  # nodes down
        iSCSIProtocolEndpoint => { w => '1', c => '2' },    # ports down
        ProtocolController => { w => '3',  c => '4' },      # hosts down
        StorageVolume => { w => '85', c => '95' },          # %usage
    },
    SNAME => {
        Array => 'Array',
        ArrayBasedOnDiskDrive => 'Array Spare Coverage',
        BackendController => 'BE Ctrl',
        BackendTargetSCSIProtocolEndpoint => 'BE Target',
        BackendVolume => 'BE Volume',
        Cluster => 'Cluster',
        ConcreteStoragePool => 'Storage Pool',
        DiskDrive => 'Disk Drive',
        Enclosure => 'Enclosure',
        EthernetPort => 'Ethernet Port',
        FCPort => 'FC Port',
        HostCluster=> 'Host Cluster',
        FCPortStatistics => 'FC Port Stats',
        IOGroup => 'I/O Group',
        IPProtocolEndpoint => 'IP Endpoint',
        iSCSIProtocolEndpoint => 'iSCSI Endpoint',
        IsSpare => 'Hot Spares',
        MasterConsole => 'Management GUI',
        MirrorExtent => 'VDisk Mirrors',
        NetworkPort => 'Network Port',
        Node => 'Node',
        QuorumDisk => 'Quorum Disk',
        RemoteCluster => 'Remote Cluster',
        StorageVolume => 'Storage Volume',
        ProtocolController => 'Protocol Controller',
        CIMOMStatisticalData => 'Test Local CIM Server'
    },
    RC => {
        OK => '0',
        WARNING => '1',
        CRITICAL => '2',
        UNKNOWN => '3'
    },
    STATUS => {
        0 => 'OK',
        1 => 'WARNING',
        2 => 'CRITICAL',
        3 => 'UNKNOWN'
    }
);
# A hash map of CIMOM return codes to human readable strings according to the "V6.4.0 CIM Agent
# Developer's Guide for IBM System Storage SAN Volume Controller" and the "Managed Object Format
# Documents" in particular. 
# The 'default' hash tree referes to mappings used commonly.
my %rcmap_default = (
    OperationalStatus => {
        0 => 'Unknown',
        1 => 'Other',
        2 => 'OK',
        3 => 'Degraded',
        4 => 'Stressed',
        5 => 'Predictive Failure',
        6 => 'Error',
        7 => 'Non-Recoverable Error',
        8 => 'Starting',
        9 => 'Stopping',
        10 => 'Stopped',
        11 => 'In Service',
        12 => 'No Contact',
        13 => 'Lost Communication',
        14 => 'Aborted',
        15 => 'Dormant',
        16 => 'Supporting Entity in Error',
        17 => 'Completed',
        18 => 'Power Mode',
        32768 => 'Vendor Reserved'
    }
);
my %rcmap = (
    Array => {
        NativeStatus => {
            0 => 'Offline',
            1 => 'Online',
            2 => 'Degraded'
        },
        OperationalStatus => $rcmap_default{'OperationalStatus'},
        RaidStatus => {
            0 => 'unknown',
            1 => 'offline',
            2 => 'degraded',
            3 => 'syncing',
            4 => 'initting',
            5 => 'online'
        }
    },
    ConcreteStoragePool => {
        NativeStatus => {
            0 => 'Offline',
            1 => 'Online',
            2 => 'Degraded',
            3 => 'Excluded',
            4 => 'Degraded Paths',
            5 => 'Degraded Port Errors'
        },
        OperationalStatus => $rcmap_default{'OperationalStatus'}
    },
    Cluster => {
        OperationalStatus => $rcmap_default{'OperationalStatus'}
    },
    DiskDrive => {
        OperationalStatus => $rcmap_default{'OperationalStatus'},
        OperationalStatus => {
            32768 => 'online',
            32769 => 'degraded',
            32770 => 'offline',
        },
        Use => {
            0 => 'unused',
            1 => 'candidate',
            2 => 'spare',
            3 => 'failed',
            4 => 'member',
        }
    },
    Enclosure => {
        EnclosureStatus => {
            0 => 'online',
            1 => 'offline',
            2 => 'degraded',
        }
    },
    EthernetPort => {
        OperationalStatus => {
            0 => 'unknown',
            1 => 'Other',
            2 => 'OK',
            6 => 'Error',
            10 => 'Stopped',
            11 => 'In Service'
        }
    },
    FCPort => {
        OperationalStatus => $rcmap_default{'OperationalStatus'}
    },
    HostCluster => {
        OperationalStatus => $rcmap_default{'OperationalStatus'}
    },
    IPProtocolEndpoint => {
        OperationalStatus => $rcmap_default{'OperationalStatus'}
    },
    iSCSIProtocolEndpoint => {
        OperationalStatus => $rcmap_default{'OperationalStatus'}
    },
    IsSpare => {
        SpareStatus => {
            0 => 'Unknown',
            2 => 'Hot Standby',
            3 => 'Cold Standby'
        }
    },
    MasterConsole => {
        OperationalStatus => $rcmap_default{'OperationalStatus'}
    },
    MirrorExtent => {
        Status => {
            0 => 'Offline',
            1 => 'Online'
        },
        Sync => {
            TRUE => 'In sync',
            FALSE => 'Out of sync'
        }
    },
    Node => {
        NativeStatus => {
            0 => 'Offline',
            1 => 'Online',
            2 => 'Pending',
            3 => 'Adding',
            4 => 'Deleting',
            5 => 'Flushing'
        },
        OperationalStatus => $rcmap_default{'OperationalStatus'}
    },
    NetworkPort => {
        LinkTechnology => {
            0 => 'Unknown',
            1 => 'Other',
            2 => 'Ethernet',
            3 => 'IB',
            4 => 'FC',
            5 => 'FDDI',
            6 => 'ATM',
            7 => 'Token Ring',
            8 => 'Frame Relay',
            9 => 'Infrared',
            10 => 'BlueTooth',
            11 => 'Wireless LAN'
        },
        OperationalStatus => $rcmap_default{'OperationalStatus'}
    },
    ProtocolController => {
        OperationalStatus => $rcmap_default{'OperationalStatus'}
    },
    RemoteCluster => {
        Partnership => {
            fully_configured => 'Fully_Configured',
            partially_configured_local => 'Partially_Configured_Local',
            partially_configured_local_stopped => 'Partially_Configured_Local_Stopped',
            not_present => 'Not_Present',
            fully_configured_stopped => 'Fully_Configured_Ctopped',
            fully_configured_remote_stopped => 'Fully_Configured_Remote_Stopped',
            fully_configured_local_excluded => 'Fully_Configured_Local_Excluded',
            fully_configured_remote_excluded => 'Fully_Configured_Remote_Excluded',
            fully_configured_exceeded => 'Fully_Configured_Exceeded',
            blank => 'Blank'
        },
    },
    StorageVolume => {
        CacheState => {
            0 => 'Empty',
            1 => 'Not empty',
            2 => 'Corrupt',
            3 => 'Repairing'
        },
        NativeStatus => {
            0 => 'Offline',
            1 => 'Online',
            2 => 'Degraded',
            3 => 'Formatting'
        },
        OperationalStatus => $rcmap_default{'OperationalStatus'}
    },
    BackendVolume => {
        Access => {
            0 => 'Unknown',
            1 => 'Readable',
            2 => 'Writable',
            3 => 'Read/Write Supported',
            4 => 'Write Once',
        },
        NativeStatus => {
            0 => 'Offline',
            1 => 'Online',
            2 => 'Degraded',
            3 => 'Excluded',
        },
        OperationalStatus => $rcmap_default{'OperationalStatus'}
    },
);
my %output = (
    perfStr => '',
    retRC => $conf{'RC'}{'OK'},
    retStr => '',
);

#
# Functions
#
# Command line processing
# Takes: reference to conf hash
# Returns: nothing
sub cli {
    my ($cfg) = @_;
    my %opts;
    my $optstring = "bp:C:H:P:Dp:c:dp:hp:u:w:s:tp:Tp:";
    getopts( "$optstring", \%opts) or usage();
    usage() if ($opts{h} );
    $$cfg{'debug'} = 1  if ($opts{d} );     # show debug output
    $$cfg{'debug'} = 2  if ($opts{D} );     # more verbose
    $$cfg{'test'} = 1  if ($opts{t} );      # mock tests (txt files)
    $$cfg{'test'} = 2  if ($opts{T} );      # use local cim server
    $$cfg{'bytes'} = 1  if ($opts{b} );
    if (exists $opts{H} && $opts{H} ne '') {
        $$cfg{'host'} = $opts{H};
        if (exists $opts{P} && $opts{P} ne '') {
            $$cfg{'port'} = $opts{P};
        } else {
            $$cfg{'port'} = '5989';
        }
        if ((exists $$cfg{'test'} && $$cfg{'test'} == 2) || ((exists $opts{u} && $opts{u} ne '') && (exists $opts{p} && $opts{p} ne ''))) {
            $$cfg{'user'} = $opts{u};
            $$cfg{'password'} = $opts{p};
            if (exists $opts{C} && $opts{C} ne '') {
                $$cfg{'check'} = $opts{C};
                if (!(exists $conf{'SNAME'}{$conf{'check'}})) {
                    print ("ERROR: invalid option\n");
                    exit 3;
                }
            } else {
                print ("ERROR: 'Check' missing ('-C')\n");
                usage();
                exit 3;
            }
        } else {
            print ("ERROR: user/password missing\n");
            usage();
            exit 3;
        }
        if (exists $opts{c} && $opts{c} ne '' ) {
            $$cfg{'critical'} = $opts{c};
        } elsif (exists $conf{'DEFAULTS'}{$$cfg{'check'}}{'w'} && $conf{'DEFAULTS'}{$$cfg{'check'}}{'w'} ne '') {
            $$cfg{'critical'} = $conf{'DEFAULTS'}{$$cfg{'check'}}{'w'};
            print ("WARN: missing argument \"-c crit\", using default value '$$cfg{'critical'}'\n");
        }
        if (exists $opts{w} && $opts{w} ne '' ) {
            $$cfg{'warning'} = $opts{w};
        } elsif (exists $conf{'DEFAULTS'}{$$cfg{'check'}}{'c'} && $conf{'DEFAULTS'}{$$cfg{'check'}}{'c'} ne '') {
            $$cfg{'warning'} = $conf{'DEFAULTS'}{$$cfg{'check'}}{'c'};
            print ("WARN: missing argument \"-w warn\", using default value '$$cfg{'warning'}'\n");
        }
        if (exists $opts{s} && $opts{s} ne '' ) {
            $$cfg{'skip'} = $opts{s};
        }
    } else {
        usage();
    }
}

#
# Convert size to rounded KiB MiB GiB TiB (1024)
# Takes: bytes
# Returns: size
sub convSize {
   my( $cfg, $s, $n ) = ( \%conf, shift, 0 );
   if ( $$cfg{'bytes'} ne 1 ) {
        my $size = 0;
        $size = $s if ($s =~ /^\d+$/);
        ++$n and $size /= 1024 until $size < 1024;
        if ($n > 0) {
            return sprintf "%.0f%s", $size, ( qw[ b KiB MiB GiB TiB ] )[$n] if ($n > 0);
        }
        return $size
    }
    return $s;
}

#
# Convert speed to rounded KB MB GB TB (1000)
# Takes: bytes
# Returns: speed
sub convSpeed {
    my( $cfg, $s, $n ) = ( \%conf, shift, 0 );
    if ( $$cfg{'bytes'} ne 1 ) {
        my $speed = 0;
        $speed = $s if ($s =~ /^\d+$/);
        ++$n and $speed /= 1000 until $speed < 1000;
        if ($n > 0) {
            return sprintf "%.0f%s", $speed, ( qw[ bit Kbit Mbit Gbit Tbit ] )[$n] if ($n > 0);
        }
        return $speed
    }
    return $s;
}

#
# Query Storwize for check output
# Takes: reference to conf and output hash
# Returns: nothing
#
sub queryStorwize {
    my ($cfg, $out, $rcmap) = @_;
    my ($objectPath, $fh, $cmd);
    # Special case: different Class name 'CIM' for NetworkPort
    if ($$cfg{'check'} eq 'NetworkPort') {
        $$cfg{'service'} = "CIM";
    }
    $objectPath = "https://$$cfg{'user'}:$$cfg{'password'}\@$$cfg{'host'}:$$cfg{'port'}$$cfg{'namespace'}:$$cfg{'service'}_$$cfg{'check'}";
    $cmd = "$$cfg{'wbemcli'} $$cfg{'wbemcli_opt'} ei \'$objectPath\' 2>&1";
    # TEST mode 1: replace cmd with mock
    if ($$cfg{'test'} == 1) {
        print("TEST1: using mock \"../test/$$cfg{'check'}.txt\" .. \n" );
        $cmd = "cat ../test/$$cfg{'check'}.txt";
    }
    # TEST mode 2: use local test server (replace objectpath)
    if ($$cfg{'test'} == 2) {
        $$cfg{'port'} = "5988";
        $$cfg{'namespace'} = '/root/cimv2';
        $$cfg{'service'} = "CIM";
        $objectPath = "http://$$cfg{'host'}:$$cfg{'port'}$$cfg{'namespace'}:$$cfg{'service'}_$$cfg{'check'}";
        print("TEST2: using local server (objectPath=$objectPath)\n");
    }
    if ($$cfg{'debug'} > 0) {
        print("DEBUG: cmd=\"$cmd\" (debug=$$cfg{'debug'})\n");
    }
    open( $fh, "-|", $cmd ) or die "Can't fork\n";
    my %obj;
    my $obj_begin;
    my $prop_name = '';
    my $prop_value = '';
    my $inst_count = 0;
    my $inst_count_half = 0;
    my $inst_count_nok = 0;
    my $inst_count_ok = 0;
    my $path_count = 0;
    my $path_count_max = 0;
    my $path_count_half = 0;
    my $quorum_active = '';
    my $stopped_count = 0;
    my $unused_count = 0;
    my $used_count_warn = 0;
    my $used_count_crit = 0;
    my $skipped_count = 0;
    my $perfWarnStr = '';
    my $perfCritStr = '';
    while( my $line = <$fh> ) {
        if ($$cfg{'debug'} > 2) {
            if (defined($obj_begin)) {
                print("DEBUG: obj_begin=$obj_begin inst_count=$inst_count line: $line");
            } else {
                print("DEBUG: obj_begin=UNDEFINED inst_count=$inst_count line: $line");
            }
        }
        if (($line =~ /.*Exception/) == 1) {
            print ("ERROR: $line\n");
            exit 2;
        }
        if (($line =~ /\*/) == 1) {
            print ("ERROR: missing output\n");
            exit 2;
        }
        # Check both CIM_* and IBMTSSVC_* Classes, e.g. /^host:5989/root/ibm:(IBMTSSVC_Array|(CIM|IBMTSSVC)_.*)\.(.*)$/
        #   if (( $line =~ /^$$cfg{'host'}:$$cfg{'port'}\/root\/ibm:($$cfg{'service'}_$$cfg{'check'}|(CIM|IBMTSSVC)_.*)\.(.*)$/ ) == 1) {
        if (( $line =~ /^$$cfg{'host'}:$$cfg{'port'}$$cfg{'namespace'}:$$cfg{'service'}_$$cfg{'check'}\.(.*)$/ ) == 1) {
            $obj_begin = 1;
        } elsif ((($prop_name, $prop_value) = $line =~ /^-(.*)=(.*)$/ ) == 2) {
            $prop_value =~ s/"//g;
            $obj{$prop_name} = $prop_value;
        } elsif ($line =~ /^\s*$/ && $obj_begin == 1) {
            $obj_begin = 0;
            $inst_count++;
            # Test: Use local CIMON server (e.g. OpenPegasus)
            #
            # Simulates Check for:
            #   CIMOMStatisticalData
            #
            if ($$cfg{'check'} eq 'CIMOMStatisticalData') {
                if ($$cfg{'debug'} eq 1) {
                    print("DEBUG: InstanceID=$obj{'InstanceID'} OperationType=$obj{'OperationType'}\n");
                }
                if ($obj{'OperationType'} != 1) {
                    $$out{'retStr'} .= " $obj{'InstanceID'}";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
            }
            # This should be the end of the paragraph/instance so we should
            # have gathered all properties at this point
            #
            # Masking view of host cluster
            #
            # Check for:
            #   OperationalStatus
            #
            if ($$cfg{'check'} eq 'HostCluster') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    $skipped_count++;
                    next;
                }
                if ($$cfg{'debug'} eq 1) {
                    print("DEBUG: $obj{'ElementName'} OperationalStatus=$$rcmap{'HostCluster'}{'OperationalStatus'}{$obj{'OperationalStatus'}} " .
                        "skip=$$cfg{'skip'} PortCount=$obj{'PortCount'} MappingCount=$obj{'MappingCount'}\n");
                }
                if ($obj{'OperationalStatus'} != 2) {
                    $$out{'retStr'} .= " $obj{'ElementName'}($$rcmap{'HostCluster'}{'OperationalStatus'}{$obj{'OperationalStatus'}})";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
            }
            # A component of a Network Entity that has a TCP/IP network address. It might be used by
            # an iSCSI Node within that Network Entity for the connections within one of its iSCSI sessions.
            # A Network Portal in a Target is identified by its IP address.
            # IPProtocolEndpoint contains the IP address of the Network Portal in the IPv4Address property.
            #
            # Check for:
            #   State
            #   OperationalStatus
            #
            if ($$cfg{'check'} eq 'IPProtocolEndpoint') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    $skipped_count++;
                    next;
                }
                my $name = join(':', (split ':', "$obj{'Name'}")[-3..-1]);
                if ($$cfg{'debug'} eq 1) {
                    print("DEBUG: $obj{'ElementName'} $obj{'Name'}_port$obj{'PortID'} name=$name OperationalStatus=$$rcmap{'IPProtocolEndpoint'}{'OperationalStatus'}{$obj{'OperationalStatus'}} ");
                    print("PortID=$obj{'PortID'} IP4vAddress=$obj{'IPv4Address'} Failover=$obj{'Failover'} IP=$obj{'IPv4Address'} Speed=$obj{'Speed'} State=$obj{'State'}\n");
                }
                if ($obj{'State'} eq 'configured') {
                    if ($obj{'OperationalStatus'} != 2) {
                        $$out{'retStr'} .= " $obj{'ElementName'}_port$obj{'PortID'}($$rcmap{'IPProtocolEndpoint'}{'OperationalStatus'}{$obj{'OperationalStatus'}})";
                        $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                        $inst_count_nok++;
                    } else {
                        $inst_count_ok++;
                    }
                } elsif ($obj{'OperationalStatus'} == 10) {
                    if ($$out{'retRC'} != $$cfg{'RC'}{'CRITICAL'}) {
                        $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                    }
                    $stopped_count++;
                }
                $$out{'perfStr'} .= " $obj{'ElementName'}port$obj{'PortID'}_status=$obj{'OperationalStatus'};;;;";
                #$$out{'perfStr'} .= " name=$obj{'Name'};;;;";
                #$$out{'perfStr'} .= " state=$obj{'State'};;;;";
                $$out{'perfStr'} .= " $obj{'ElementName'}port$obj{'PortID'}_ip=$obj{'IPv4Address'};;;;";
                #$$out{'perfStr'} .= " $obj{'ElementName'}port$obj{'PortID'}_failover=$obj{'Failover'};;;;";
                $$out{'perfStr'} .= " $obj{'ElementName'}port$obj{'PortID'}_speed=$obj{'Speed'};;;;";
            }
            # A SCSI Port with an iSCSI service delivery subsystem. A collection of Network Portals that together
            # acts as a SCSI Target or target.
            #
            # Check for:
            #   OperationalStatus
            #
            if ($$cfg{'check'} eq 'iSCSIProtocolEndpoint') {
                my $_element = (split '\.', "$obj{'ElementName'}")[-1];
                my $_name = (split ',', (split '\.', "$obj{'Name'}")[-1])[-1];
                if ($$cfg{'debug'} eq 1) {
                    print("DEBUG: $obj{'ElementName'} _element=$_element Name=$obj{'Name'} _name=$_name OperationalStatus=$$rcmap{'iSCSIProtocolEndpoint'}{'OperationalStatus'}{$obj{'OperationalStatus'}}\n");
                    print("\n\nDEBUG: inst_count=$inst_count\n\n");
                }
                if ($obj{'OperationalStatus'} != 2 && $obj{'OperationalStatus'} != 10) {
                    $$out{'retStr'} .= " ${_element},${_name}($$rcmap{'iSCSIProtocolEndpoint'}{'OperationalStatus'}{$obj{'OperationalStatus'}})";
                    $inst_count_nok++;
                } elsif ($obj{'OperationalStatus'} == 10) {
                    $stopped_count++;
                } else {
                    $inst_count_ok++;
                }
                if ($inst_count_nok >= $$cfg{'warning'} && $inst_count_nok <= $$cfg{'critical'}) {
                    $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                } elsif ($inst_count_nok >= $$cfg{'critical'}) {
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                }
                $$out{'perfStr'} .= " $obj{'ElementName'}_status=$obj{'OperationalStatus'};;;;";
                #$$out{'perfStr'} .= " $obj{'ElementName'}_identifier=$obj{'Identifier'};;;;";
            }
            # The iSCSI Node represents a single iSCSI Target. There are one or more
            # iSCSI Nodes within a Network Entity. The iSCSI Node is accessible through
            # one or more Network Portals. An iSCSI Node is identified by its iSCSI Name.
            # Separating the iSCSI Name from the addresses allows multiple iSCSI nodes to
            # use the same address, and the same iSCSI node to use multiple addresses.
            #
            # Check for:
            #   OperationalStatus
            #
            if ($$cfg{'check'} eq 'ProtocolController') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                if ($$cfg{'debug'} eq 1) {
                    print("DEBUG: $obj{'ElementName'} OperationalStatus=$$rcmap{'ProtocolController'}{'OperationalStatus'}{$obj{'OperationalStatus'}} ");
                    print("Name=$obj{'Name'} HostClusterId=$obj{'HostClusterId'} HostClusterName=$obj{'HostClusterName'} DeviceID=$obj{'DeviceID'}\n");
                }
                if ($obj{'OperationalStatus'} != 2) {
                    $$out{'retStr'} .= " $obj{'ElementName'}($$rcmap{'ProtocolController'}{'OperationalStatus'}{$obj{'OperationalStatus'}})";
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
                if ($inst_count_nok >= $$cfg{'warning'} && $inst_count_nok <= $$cfg{'critical'}) {
                    $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                } elsif ($inst_count_nok >= $$cfg{'critical'}) {
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                }
                $$out{'perfStr'} .= " $obj{'ElementName'}_status=$obj{'OperationalStatus'};;;;";
                $$out{'perfStr'} .= " $obj{'ElementName'}_cluster:$obj{'HostClusterName'}_id=$obj{'HostClusterId'};;;;";
                #$$out{'perfStr'} .= " hostcount=$obj{'HostCount'};;;;";
                #$$out{'perfStr'} .= " mappingcount=$obj{'MappingCount'};;;;";
                if ($obj{'PortCount'} ne '') {
                    $$out{'perfStr'} .= " $obj{'ElementName'}_portcount=$obj{'PortCount'};;;;";
                }
            }
            # States of IP partnership. Two systems that are partnered to perform remote copy over native IP links.
            #
            # State                                Systems  Support for active 
            #                                    connected    remote copy I/O     Comments
            # ----------------------------------------------------------------------------------------------------------------------------------------------------------
            # Partially_Configured_Local             No            No             This state indicates that the initial discovery is complete.
            # Fully_Configured                      Yes           Yes             Discovery successfully completed between two systems, and the two systems can establish remote copy relationships.
            # Fully_Configured_Stopped              Yes           Yes             The partnership is stopped on the system.
            # Fully_Configured_Remote_Stopped       Yes            No             The partnership is stopped on the remote system.
            # Not_Present                           Yes            No             The two systems cannot communicate with each other. This state is also seen when data paths between the two systems are not established.
            # Fully_Configured_Exceeded             Yes            No             There are too many systems in the network, and the partnership from the local system to remote system is disabled.
            # Fully_Configured_Excluded              No            No             The connection is excluded because of too many problems, or either system cannot support the I/O work load for the Metro Mirror and Global
            #                                                                     Mirror relationships.
            # Check for:
            #   PartnershipStatus
            #
            if ($$cfg{'check'} eq 'RemoteCluster') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                if ($$cfg{'debug'} eq 1) {
                    print("DEBUG: $obj{'ElementName'} skip=$$cfg{'skip'} ");
                    print("Name=$obj{'Name'} PartnershipStatus=$obj{'PartnershipStatus'} IP=$obj{'IP'} PartnershipBandwidth=$obj{'PartnershipBandwidth'}\n");
                }
                if ($obj{'PartnershipStatus'} eq 'fully_configured') {
                    $$out{'retStr'} .= " $obj{'ElementName'}($obj{'PartnershipStatus'})";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
            }
            # An array is a term used to refer to a mdisk that is made from a set of local
            # disks. This is not to be confused with externally managed logical units. These
            # mdisks are in the array mode and command lines associated with these mdisks
            # only use the term array in their names.
            #
            # Values RaidStatus:
            #   "0", "unknown"
            #   "1", "offline - array is offline on all nodes"
            #   "2", "degraded - array has deconfigured or offline members (array is not fully redundant)"
            #   "3", "syncing - array members all online, array is syncing parity or mirrors to acheive redundancy"
            #   "4", "initting - array members all online, array is innitting, array is fully redundant"
            #   "5", "online - array members all online and array is fully redundant"
            #
            # Check for:
            #   NativeStatus, OperationalStatus, RaidStatus
            #
            # CRITICAL: (1)offline, (2)degraded | WARN: (0)unknown (3)sync, (4)init
            if ($$cfg{'check'} eq 'Array') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                if ($$cfg{'debug'} eq 1) {
                    print("DEBUG: $obj{'ElementName'} NativeStatus=$obj{'NativeStatus'} OperationalStatus=$obj{'OperationalStatus'} RaidStatus=$obj{'RaidStatus'}\n");
                }
                if ($obj{'NativeStatus'} != 1 || $obj{'OperationalStatus'} != 2 || $obj{'RaidStatus'} == 1 || $obj{'RaidStatus'} == 2) {
                    $$out{'retStr'} .= " $obj{'ElementName'}($$rcmap{'Array'}{'NativeStatus'}{$obj{'NativeStatus'}}," . 
                        "$$rcmap{'Array'}{'OperationalStatus'}{$obj{'OperationalStatus'}},$$rcmap{'Array'}{'RaidStatus'}{$obj{'RaidStatus'}})";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } elsif ($obj{'RaidStatus'} == 0 || $obj{'RaidStatus'} == 3 || $obj{'RaidStatus'} == 4) {
                    $$out{'retStr'} .= " $obj{'ElementName'}($$rcmap{'Array'}{'NativeStatus'}{$obj{'NativeStatus'}},";
                    $$out{'retStr'} .= "$$rcmap{'Array'}{'OperationalStatus'}{$obj{'OperationalStatus'}},$$rcmap{'Array'}{'RaidStatus'}{$obj{'RaidStatus'}})";
                    if ($$out{'retRC'} != $$cfg{'RC'}{'CRITICAL'}) {
                        $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                    }
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
            }
            # This specialization defines how data is striped across StorageExtents.
            # Additionally, it includes information on distribution of check data so that
            # the 'usual case' RAID devices can be created in one step.
            #
            # Check for:
            #   -
            #
            elsif ($$cfg{'check'} eq 'ArrayBasedOnDiskDrive') {
                if (($obj{'EnclosureIDGoal'} eq '') || ($obj{'SlotIDGoal'} eq '')) {
                    print ("$$cfg{'STATUS'}{'3'}: No EnclosureIDGoal or SlotIDGoal found (Spares:$obj{'SpareProtection'})\n");
                    exit $$cfg{'RC'}{'UNKNOWN'};
                }
                if ($obj{'SpareProtection'} <= $$cfg{'critical'}) {
                    $$out{'retStr'} .= " Enc:$obj{'EnclosureIDGoal'},Slot:$obj{'SlotIDGoal'}(Spares:$obj{'SpareProtection'})";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } elsif ($obj{'SpareProtection'} <= $$cfg{'warning'} && $obj{'SpareProtection'} > $$cfg{'critical'}) {
                    $$out{'retStr'} .= " Enc:$obj{'EnclosureIDGoal'},Slot:$obj{'SlotIDGoal'}(Spares:$obj{'SpareProtection'})";
                    if ($$out{'retRC'} != $$cfg{'RC'}{'CRITICAL'}) {
                        $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                    }
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
            }
            # u09422fra
            # BackendVolumes that are needed to form StoragePools in the SAN Volume Controller.
            # Check for:
            #   OperationalStatus
            #
            if ($$cfg{'check'} eq 'BackendController') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                if ($obj{'OperationalStatus'} != 2) {
                    $$out{'retStr'} .= " $obj{'ElementName'}($$rcmap{'BackendController'}{'OperationalStatus'}{$obj{'OperationalStatus'}})";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
            }
            # u09422fra
            # A SCSIProtocolEndpoint represents the protocol (command) aspects of a logical
            # SCSI port, independent of the connection/transport. SCSIProtocolEndpoint is
            # either directly or indirectly associated with one or more instances of LogicalPort
            # (via PortImplementsEndpoint) depending on the underlying transport. Indirect
            # associations aggregate one or more LogicalPorts using intermediate Protocol-
            # Endpoints (iSCSI, etc). SCSIProtocolEndpoint is also associated to a SCSIProtocol-
            # Controller, representing the SCSI device. This is impelementation that represents
            # the SCSIProtocolEndpoint (RemoteServiceAccessPoint) of the Backend Storage.
            #
            # Check for:
            #   Status
            #
            elsif ($$cfg{'check'} eq 'BackendTargetSCSIProtocolEndpoint') {
                if ($obj{'Status'} ne 'Active') {
                    $$out{'retStr'} .= " $obj{'ElementName'}($$cfg{'STATUS'}{$$out{'retRC'}},$obj{'Name'})";
                    $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
            }
            # A BackendVolume is a SCSI LUN which is exposed on the fabric by a Storage
            # Controller (typically a RAID array) to the SAN Volume Controller. It can
            # be a raid array made from local drives or it can be an logical unit from
            # a external SAN attached controller that SVC manages.
            #
            # In other words, these are the SVC MDisks
            #
            # Check for:
            #   Access, NativeStatus, OperationalStatus, PathCount
			#
            elsif ( $$cfg{'check'} eq 'BackendVolume' ) {
                if ($obj{'MaxPathCount'} ne '') {
                    $path_count_max = $obj{'MaxPathCount'};
                    $path_count_half = $obj{'MaxPathCount'}/2;
                }
                if ($obj{'PathCount'} ne '') {
                    $path_count = $obj{'PathCount'};
                }
                if ($obj{'OperationalStatus'} != 2 || $obj{'NativeStatus'} != 1 || (($obj{'PathCount'} ne '') && ($path_count <= $path_count_half))) {
                    my $_paths = '';
                    if ($obj{'PathCount'} ne '') {
                        $_paths = ",Paths:$path_count/$path_count_max";
                    }
                    $$out{'retStr'} .= " $obj{'ElementName'}($$rcmap{'BackendVolume'}{'NativeStatus'}{$obj{'NativeStatus'}},$$rcmap{'BackendVolume'}{'OperationalStatus'}{$obj{'OperationalStatus'}}${_paths})";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } elsif ( $obj{'Access'} != 3 ) {
                   $$out{'retStr'} .= " $obj{'ElementName'}($$rcmap{'BackendVolume'}{'Access'}{$obj{'Access'}})";
                   if ( $$out{'retRC'} != $$cfg{'RC'}{'CRITICAL'} ) {
                       $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                   }
                    $inst_count_nok++;
                } elsif ($path_count < $path_count_max) {
                    $$out{'retStr'} .= " $obj{'ElementName'}(Path: $path_count/$path_count_max)";
                    if ( $$out{'retRC'} != $$cfg{'RC'}{'CRITICAL'} ) {
                        $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                    }
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
            }

            # A group of between one and four Redundancy Groups therefore up to eight Nodes
            # form a Cluster.
            #
            # Check for:
            #   OperationalStatus
            #
            elsif ($$cfg{'check'} eq 'Cluster') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                if ($obj{'OperationalStatus'} != 2) {
                    $$out{'retStr'} .= " $obj{'ElementName'}($$rcmap{'Cluster'}{'OperationalStatus'}{$obj{'OperationalStatus'}})";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
            }
            # A pool of Storage that is managed within the scope of a particular System.
            # StoragePools may consist of component StoragePools or StorageExtents. Storage-
            # Extents that belong to the StoragePool have a Component relationship to the
            # StoragePool. StorageExtents/StoragePools that are elements of a pool have
            # their available space aggregated into the pool. StoragePools and Storage-
            # Volumes may be created from StoragePools. This is indicated by the Allocated-
            # FromStoragePool association. StoragePool is scoped to a system by the Hosted-
            # StoragePool association.
            # For SVC concrete storage pools, this corresponds to a Managed Disk Group from
            # which Virtual Disks can be allocated. SVC concrete StoragePools are not pre-
            # configured and must be created by the storage administrator.
            #
            # In other words, these are the SVC MDiskGroups
            #
            # Check for:
            #   NativeStatus, OperationalStatus
            #
            # If available use 'PhysicalCapacity' instead of 'UsedCapacity/TotalManagedSpace'
            elsif ($$cfg{'check'} eq 'ConcreteStoragePool') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                my ($total, $used);
                if ($obj{'PhysicalCapacity'} ne '' && $obj{'PhysicalFreeCapacity' ne '' }) {
                    $used = $obj{'PhysicalCapacity'} - $obj{'PhysicalFreeCapacity'};
                    $total = $obj{'PhysicalCapacity'}
                } else {
                    $used = $obj{'UsedCapacity'};
                    $total = $obj{'TotalManagedSpace'};
                }
                my $usedpct = sprintf("%.0f",(${used}/${total})*100);
                if ($obj{'OperationalStatus'} != 2 || $obj{'NativeStatus'} != 1 ) {
                    $$out{'retStr'} .= " $obj{'ElementName'}($$rcmap{'ConcreteStoragePool'}{'NativeStatus'}{$obj{'NativeStatus'}},$$rcmap{'ConcreteStoragePool'}{'OperationalStatus'}{$obj{'OperationalStatus'}},Used:${usedpct}%)";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
                if ($usedpct >= $$cfg{'warning'} && $usedpct <= $$cfg{'critical'}) {
                    $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                } elsif ($usedpct >= $$cfg{'critical'}) {
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                }
                if ($$cfg{'debug'} eq 1) {
                    print("DEBUG: $obj{'ElementName'} usedpct=${usedpct} used=${used} UsedCapacity=$obj{'UsedCapacity'}\n");
                }
                $$out{'perfStr'} .= " $obj{'ElementName'}=${usedpct}%;;;;";
                $$out{'perfStr'} .= " used=" . convSize(${used}) . ";;;; total=" . convSize($obj{'PhysicalCapacity'}) . ";;;;";
                $$out{'perfStr'} .= " mdisks=$obj{'NumberOfBackendVolumes'};;;; vols=$obj{'NumberOfStorageVolumes'};;;;";
            }
            # Capabilities and managment of a DiskDrive, a subtype of MediaAccessDevice.
            #
            # Check for:
            #   OperationalStatus
            #
            elsif ($$cfg{'check'} eq 'DiskDrive') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'Name'} =~ $$cfg{'skip'})) {
                    next;
                }
                if (($obj{'OperationalStatus'} != 32768) && ($obj{'OperationalStatus'} != 2)) {
                    $$out{'retStr'} .= " $obj{'Name'},Enc:$obj{'EnclosureID'},Slot:$obj{'SlotID'}($$rcmap{'DiskDrive'}{'OperationalStatus'}{$obj{'OperationalStatus'}})";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                    if ($$cfg{'debug'} eq 1) {
                        print ("DEBUG: OperationalStatus line=$obj{'OperationalStatus'}\n");
                    }
                } else {
                    $inst_count_ok++;
                }
            }
            # Describe the physical 'box' that disk drives canisters, power and cooling units resides in
            #
            # Check for:
            #   EnclosureStatus, OnlineCanisters, OnlinePSUs
            #
            elsif ($$cfg{'check'} eq 'Enclosure') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                if ($obj{'EnclosureStatus'} != 0 || $obj{'OnlineCanisters'} < $obj{'TotalCanisters'} || $obj{'OnlinePSUs'} < $obj{'TotalPSUs'}) {
                    $$out{'retStr'} .= " Enc_$obj{'ElementName'},SN:$obj{'SerialNumber'}($$rcmap{'Enclosure'}{'EnclosureStatus'}{$obj{'EnclosureStatus'}}," .
                        "Canister:$obj{'OnlineCanisters'}/$obj{'TotalCanisters'},PSU:$obj{'OnlinePSUs'}/$obj{'TotalPSUs'})";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
            }
            # Ethernet port of a SVC node.
            #
            # Check for:
            #   OperationalStatus
            #
            elsif ($$cfg{'check'} eq 'EthernetPort') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                if ($obj{'OperationalStatus'} != 2 && $obj{'OperationalStatus'} != 11) {
                    $$out{'retStr'} .= " MAC:$obj{'PermanentAddress'}($$rcmap{'EthernetPort'}{'OperationalStatus'}{$obj{'OperationalStatus'}})";
                    if ($$out{'retRC'} != $$cfg{'RC'}{'CRITICAL'}) {
                        $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                    }
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
                $inst_count_half = $inst_count/2;
                if ($inst_count_ok < $inst_count_half && $inst_count_half >= 1) {
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                }
            }
            # Fibre-Channel port of a SVC node. Generally all FC ports of a SVC RedundancyGroup
            # expose the same devices. Furthermore all FC ports of a SVC cluster share the same
            # BackendVolumes.
            #
            # Any FC port with an SFP installed is shown as 'configured' by design.
            #
            # Check for:
            #   OperationalStatus
            #
            elsif ($$cfg{'check'} eq 'FCPort') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                if ($obj{'OperationalStatus'} != 2) {
                    #$$out{'retStr'} .= "($$rcmap{'FCPort'}{'OperationalStatus'}{$obj{'OperationalStatus'}})";
                    my ($port, $status);
                    if ( $obj{'ElementName'} ne '') {
                        $port = "$obj{'ElementName'}";
                    } elsif ($obj{'NodeName'} ne '' && $obj{'FCIOPortID'} ne '') {
                        $port = " $obj{'NodeName'}-p$obj{'FCIOPortID'}";
                    } elsif ($obj{'PortID'} ne '') {
                        $port = " p$obj{'PortID'}";
                    }
                    # Get description explaining OperationalStatus, if available
                    if ($obj{'StatusDescriptions'} ne '' && $obj{'StatusDescriptions'} ne 'OK') {
                        $status = "$port($obj{'StatusDescriptions'})";
                    } else {
                        $status = "$port($$rcmap{'FCPort'}{'OperationalStatus'}{$obj{'OperationalStatus'}})";
                    }
                    if ($obj{'OperationalStatus'} == 10 ) {
                        #print("DEBUG: stopped $$out{'retRC'}\n");
                        $$out{'retStr'} .= $status;
                        $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                        $stopped_count++;
                    } elsif ($obj{'OperationalStatus'} == 12) {
                        #print("DEBUG: unused $$out{'retRC'}\n");
                        $$out{'retStr'} .= $status;
                        $unused_count++;
                    } else {
                        #print("DEBUG: nok $$out{'retRC'}\n");
                        $$out{'retStr'} .= " $port({'OperationalStatus'}{$obj{'OperationalStatus'}})";
                        if ($$out{'retRC'} != $$cfg{'RC'}{'CRITICAL'}) {
                            $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                        }
                        $inst_count_nok++;
                    }
                } else {
                    $inst_count_ok++;
                }
                $inst_count_half = $inst_count/2;
                if ($inst_count_ok < $inst_count_half && $inst_count_half >= 1) {
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                }
                if ($$cfg{'debug'} eq 1) {
                    print("DEBUG: RC(last) $$out{'retRC'}\n");
                    print("DEBUG: $obj{'NodeName'}-p$obj{'FCIOPortID'} OperationalStatus=$$rcmap{'FCPort'}{'OperationalStatus'}{$obj{'OperationalStatus'}}($obj{'OperationalStatus'}) " .
                        "skip=$$cfg{'skip'} ElementName=$obj{'ElementName'} DeviceID=$obj{'DeviceID'} StatusDescriptions=$obj{'StatusDescriptions'} (ok=$inst_count_ok < half=$inst_count_half)\n");
                }
            }
            # u09422fra
            # FCPortStatistics is the statistics for the FCPort.
            #
            # Check for:
            #   -
            #
            elsif ($$cfg{'check'} eq 'FCPortStatistics') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                my ($node, $port) = $obj{'ElementName'} =~ /^FCPort statistics for port (\d+) on node (\d+)/;
                my %stats = (
                    BytesTransmitted => 'trans',
                    BytesReceived => 'recv',
                    LinkFailures => 'lf',
                    LossOfSignalCounter => 'losig',
                    LossOfSyncCounter => 'losync',
                    PrimitiveSeqProtocolErrCount => 'pspec',
                    CRCErrors => 'crc',
                    InvalidTransmissionWords => 'inval',
                    BBCreditZeroTime => 'bbzero'
                );

                $$out{'retStr'} = "OK";
                foreach my $stat ( sort keys %stats) {
                    $$out{'perfStr'} .= " ".$stats{$stat}."_n".$node."p".$port."=".$obj{$stat}."c;;;;";
                }
            }
            # A group containing two Nodes. An IOGroup defines an interface for a set of
            # Volumes. All Nodes and Volumes are associated with exactly one IOGroup. The
            # read and write cache provided by a node is duplicated for redundancy. When
            # IO is performed to a Volume, the node that processes the IO will duplicate
            # the data on the Partner node in the IOGroup. This class represents the system
            # aspect of an IO group wheras IOGroupSet represents the set aspect.
            #
            # Check for:
            #   OperationalStatus
            #
            elsif ($$cfg{'check'} eq 'IOGroup') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                my @mem_elements;
                $inst_count--;
                for my $mem ( 'FlashCopy', 'Mirror', 'RAID', 'RemoteCopy' ) {
                    my $mem_free = $mem."FreeMemory";
                    my $mem_total = $mem."TotalMemory";
                    $inst_count++;
                    if ($obj{$mem_total} == 0) {
                        # For inactive memory metrics the value of "*TotalMemory" is zero, skip those.
                        $inst_count--;
                    } elsif ($obj{$mem_free} <= $$cfg{'critical'}) {
                        push (@mem_elements, "$mem:CRITICAL");
                        $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                        $inst_count_nok++;
                    } elsif ($obj{$mem_free} <= $$cfg{'warning'} && $obj{$mem_free} > $$cfg{'critical'}) {
                        push (@mem_elements, "$mem:WARNING");
                        if ($$out{'retRC'} != $$cfg{'RC'}{'CRITICAL'}) {
                            $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                        }
                        $inst_count_nok++;
                    } else {
                        push (@mem_elements, "$mem:OK");
                        $inst_count_ok++;
                    }
                }
                if ($$cfg{'debug'} eq 1) {
                    print ("DEBUG: retRC= $$out{'retRC'}\n");
                }
                if ($$out{'retRC'} != 0) {
                    if (@mem_elements) {
                        $$out{'retStr'} .= " $obj{'ElementName'}(".join(',', @mem_elements).")";
                    }
                }

                $$out{'perfStr'} .= " num_hosts_$obj{'ElementName'}=$obj{'NumberOfHosts'};;;;";
                $$out{'perfStr'} .= " num_nodes_$obj{'ElementName'}=$obj{'NumberOfNodes'};;;;";
                $$out{'perfStr'} .= " num_vol_$obj{'ElementName'}=$obj{'NumberOfVolumes'};;;;";
                $$out{'perfStr'} .= " mem_fc_$obj{'ElementName'}=$obj{'FlashCopyFreeMemory'};;;0;$obj{'FlashCopyTotalMemory'}";
                $$out{'perfStr'} .= " mem_mirr_$obj{'ElementName'}=$obj{'MirrorFreeMemory'};;;0;$obj{'MirrorTotalMemory'}";
                $$out{'perfStr'} .= " mem_raid_$obj{'ElementName'}=$obj{'RAIDFreeMemory'};;;0;$obj{'RAIDTotalMemory'}";
                $$out{'perfStr'} .= " mem_rc_$obj{'ElementName'}=$obj{'RemoteCopyFreeMemory'};;;0;$obj{'RemoteCopyTotalMemory'}";
            }
            # This association indicates a DiskDriveExtent that can spare or replace any
            # of the DiskDriveExtents in the referenced RedundancySet.
            #
            # Check for:
            #   SpareStatus
            #
            elsif ($$cfg{'check'} eq 'IsSpare') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                if ($obj{'SpareStatus'} != 2) {
                    $$out{'retStr'} .= " $obj{'ElementName'}($$rcmap{'IsSpare'}{'SpareStatus'}{$obj{'SpareStatus'}})";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
            }
            # Management GUI
            # The SVC management web interface processes.
            #
            # Check for:
            #   OperationalStatus
            #
            elsif ($$cfg{'check'} eq 'MasterConsole') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                if ($obj{'OperationalStatus'} != 2) {
                    $$out{'retStr'} .= " $obj{'ElementName'}($$rcmap{'MasterConsole'}{'OperationalStatus'}{$obj{'OperationalStatus'}})";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
            }
            # Represents a single vdisk copy. Each vdisk must have at least one copy and will
            # have two copies if it is mirrored.
            #
            # Check for:
            #   Status, Sync
            #
            elsif ($$cfg{'check'} eq 'MirrorExtent') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                if ($obj{'Status'} != 1 || $obj{'Sync'} ne 'TRUE') {
                    $$out{'retStr'} .= " VDisk:$obj{'StorageVolumeID'},Copy:$obj{'CopyID'}($$rcmap{'MirrorExtent'}{'Status'}{$obj{'Status'}},$$rcmap{'MirrorExtent'}{'Sync'}{$obj{'Sync'}})";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
            }
            # A single SAN Volume Controller unit. Nodes work in pairs for redundancy. The
            # pairs are associated by their IO Group. One or more Node pairs form a Cluster.
            # When the Cluster is formed, one Node is designated the Config Node. This node
            # is chosen automatically and it is this Node that binds to the Cluster IP address.
            # This forms the Configuration Interface to the Cluster.
            #
            # Check for:
            #   NativeStatus, OperationalStatus
            #
            elsif ($$cfg{'check'} eq 'Node') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                if ($obj{'OperationalStatus'} != 2 || $obj{'NativeStatus'} != 1) {
                    $$out{'retStr'} .= " $obj{'ElementName'}($$rcmap{'Node'}{'NativeStatus'}{$obj{'NativeStatus'}},$$rcmap{'Node'}{'OperationalStatus'}{$obj{'OperationalStatus'}})";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
            }
            # Represents a single candidate quorum disk. There is only ONE quorum disk but
            # the cluster uses three disks as quorum candidate disks. The cluster will select
            # the actual quorum disk from the pool of quorum candidate disks. When MDisks
            # are added to the SVC cluster, it checks the MDisk to see if it can be used as
            # a quorum disk. If the MDisk fulfils the demands, the SVC will assign the three
            # first MDisks as quorum candidates, and one of them is selected as the active
            # quorum disk.
            #
            # Check for:
            #   Active, Status
            #
            elsif ($$cfg{'check'} eq 'QuorumDisk') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    next;
                }
                my $_name = $obj{'ElementName'};
                if ($_name eq '') {
                    $_name = 'Quorum_'.$obj{'QuorumIndex'};
                }
                if ($obj{'Status'} ne 'online') {
                    $$out{'retStr'} .= " ".$_name."(".$obj{'Status'}.")";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
                if ($obj{'Active'} ne 'FALSE') {
                    $quorum_active = $_name;
                }
            }
            # A device presented by the Cluster which can be mapped as a SCSI LUN to host
            # systems on the SAN. A Volume is formed by allocating a set of Extents from a
            # Pool. In SVC terms a VDisk
            #
            # Check for:
            #   CacheState
            #
            # Values:
            #   Cachestate 0='Empty', 1='Not Empty'
            #   NativeStatus 1='Online' and OperationalStatus 2='OK'
            #
            elsif ($$cfg{'check'} eq 'StorageVolume') {
                # Always skip vdisk[0-9] elements because they return false positives
                if ((($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) || ($obj{'ElementName'} =~ '^vdisk[0-9]')) {
                    $skipped_count++;
                    next;
                }
                my $usedpct = sprintf("%.0f",($obj{'UncompressedUsedCapacity'}/$obj{'ConsumableBlocks'})*100);
                if ($$cfg{'debug'} eq 1) {
                    print("DEBUG: $obj{'ElementName'} CacheState=$obj{'CacheState'} OperationalStatus=$obj{'OperationalStatus'} NativeStatus=$obj{'NativeStatus'}" .
                        " UncompressedUsedCapacity=" . convSize($obj{'UncompressedUsedCapacity'}) .
                        " ConsumableBlocks=" . convSize($obj{'ConsumableBlocks'}) . " usedpct=${usedpct}%" . "\n")
                }
                if ($obj{'OperationalStatus'} != 2 || $obj{'NativeStatus'} != 1) {
                    $$out{'retStr'} .= " $obj{'ElementName'}($$rcmap{'StorageVolume'}{'CacheState'}{$obj{'CacheState'}}," . 
                        "$$rcmap{'StorageVolume'}{'NativeStatus'}{$obj{'NativeStatus'}},$$rcmap{'StorageVolume'}{'OperationalStatus'}{$obj{'OperationalStatus'}},${usedpct}%)";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $inst_count_nok++;
                } elsif ($obj{'CacheState'} != 0 && $obj{'CacheState'} != 1) {
                    $$out{'retStr'} .= " $obj{'ElementName'}($$rcmap{'StorageVolume'}{'CacheState'}{$obj{'CacheState'}}," .
                        "$$rcmap{'StorageVolume'}{'NativeStatus'}{$obj{'NativeStatus'}},$$rcmap{'StorageVolume'}{'OperationalStatus'}{$obj{'OperationalStatus'}})";
                    if ($$out{'retRC'} != $$cfg{'RC'}{'CRITICAL'}) {
                        $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                    }
                    $inst_count_nok++;
                } else {
                    $inst_count_ok++;
                }
                if ($usedpct >= $$cfg{'warning'} && $usedpct <= $$cfg{'critical'}) {
                    $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                    $$out{'retStr'} .= " $obj{'ElementName'}(${usedpct}%)";
                    $used_count_warn++;
                    # Add critical elements separately, so we can show them first
                    $perfWarnStr .= " $obj{'ElementName'}=${usedpct}%" . ";;;;";
                    $perfWarnStr .= " used=" . convSize($obj{'UncompressedUsedCapacity'}). ";;;; total=" . convSize($obj{'ConsumableBlocks'}) . ";;;;";
                } elsif ($usedpct >= $$cfg{'critical'}) {
                    $$out{'retStr'} .= " $obj{'ElementName'}(${usedpct}%)";
                    $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
                    $used_count_crit++;
                    $perfCritStr .= " $obj{'ElementName'}=${usedpct}%" . ";;;;";
                    $perfCritStr .= " used=" . convSize($obj{'UncompressedUsedCapacity'}). ";;;; total=" . convSize($obj{'ConsumableBlocks'}) . ";;;;";
                }
                if ($usedpct <= $$cfg{'warning'} && $usedpct <= $$cfg{'critical'}) {
                    $$out{'perfStr'} .= " $obj{'ElementName'}=${usedpct}%" . ";;;;";
                    $$out{'perfStr'} .= " used=" . convSize($obj{'UncompressedUsedCapacity'}) . ";;;; total=" . convSize($obj{'ConsumableBlocks'}) . ";;;;";
                }
            }
            # CIM_NetworkPort is a subclass of CIM_LogicalPort
            # NetworkPort is the logical representation of network communications hardware such as a physical connector.
            # NetworkPorts are often numbered relative to either a logical module or a network element.
            #
            # Check for:
            #   OperationalStatus
            #
            elsif ($$cfg{'check'} eq 'NetworkPort') {
                if (($$cfg{'skip'} ne '' ) && ($obj{'ElementName'} =~ $$cfg{'skip'})) {
                    $skipped_count++;
                    next;
                }
                if ($obj{'OperationalStatus'} != 2 && $obj{'OperationalStatus'} != 10) {
                    $$out{'retStr'} .= " $obj{'NodeName'}-p$obj{'PortNumber'}";
                    if ($obj{'StatusDescriptions'}) {
                        $$out{'retStr'} .= "($obj{'StatusDescriptions'})"; 
                    } else {
                        $$out{'retStr'} .= "($$rcmap{'NetworkPort'}{'OperationalStatus'}{$obj{'OperationalStatus'}})";
                    }
                    if ($$out{'retRC'} != $$cfg{'RC'}{'CRITICAL'}) {
                        $$out{'retRC'} = $$cfg{'RC'}{'WARNING'};
                    }
                    $inst_count_nok++;
                } elsif ($obj{'OperationalStatus'} == 10) {
                    $stopped_count++;
                } else {
                    $inst_count_ok++;
                }
                if ($$cfg{'debug'} eq 1) {
                    print("DEBUG: OperationalStatus=$obj{'OperationalStatus'} NodeName=$obj{'NodeName'} PortNumber=$obj{'PortNumber'} StatusDescriptions=$obj{'StatusDescriptions'} " .
                        "SystemCreationClassName=$obj{'SystemCreationClassName'} Speed=" . convSpeed($obj{'Speed'}) . " FullDuplex=$obj{'FullDuplex'} MTU=$obj{'SupportedMaximumTransmissionUnit'} " .
                        "$$rcmap{'NetworkPort'}{'LinkTechnology'}{$obj{'LinkTechnology'}}" . "\n");
                }
            }
        } else {
            next;
        }
    }
    close( $fh );
    if (! -x $conf{'wbemcli'}) {
        print ("ERROR: wbemcli $?\n");
        exit 2;
    }

    # Special case: Show stopped elements which are neither 'ok' nor 'nok'
    my ($_stopped, $_perfstop) = ('', '');
    if (defined $stopped_count && $stopped_count > 0) {
        $_stopped = "Stopped:${stopped_count}/";
        $_perfstop = " stopped=${stopped_count};;;;";
    }
    # Special case: Show skipped elements
    my $_skipped = '';
    if (defined $skipped_count && $skipped_count > 0) {
        $_skipped = "Skip:${skipped_count}/";
    }
    # Special case: Show 'Capacity Low/Out count' for volumes
    my ($_cap, $_cap_low, $_cap_out) = ('', '', '');
    if (defined $used_count_warn && $used_count_warn > 0) {
        $_cap_low .= "Low:${used_count_warn}";
    }
    if (defined $used_count_crit && $used_count_crit > 0) {
        $_cap_out .= "Out:${used_count_crit}";
    }
    if ($_cap_low ne '' || $_cap_out ne '') {
        $_cap = " (Capacity " . join('/', grep $_, $_cap_low, $_cap_out) . ")";
    }

    $$out{'retStr'} =~ s/^ //;
    $$out{'retStr'} =~ s/,$//;
    if ($inst_count != 0) {
        if ($$out{'retStr'} ne '' && ${_cap} eq '') {
            $$out{'retStr'} = " - $$out{'retStr'}";
        } else {
            $$out{'retStr'} = " $$out{'retStr'}";
        }
        $$out{'retStr'} = "NOK:$inst_count_nok/OK:$inst_count_ok/${_stopped}${_skipped}Total:$inst_count${_cap}".$$out{'retStr'};
    }

    # Special case: Check if at least one QuorumDisk was in the "active='TRUE'" state and add to *end* of retStr
    if ($$cfg{'check'} eq 'QuorumDisk') {
        if ($quorum_active ne '') {
            $$out{'retStr'} .= " - Active quorum on \"$quorum_active\"";
        } else {
            $$out{'retRC'} = $$cfg{'RC'}{'CRITICAL'};
            $$out{'retStr'} .= " - No active quorum disk found";
        }
    }

    # Special case: No spare, add to *end* of retStr
    if ($$cfg{'check'} eq 'IsSpare' && !defined $obj{'SpareStatus'}) {
        $$out{'retStr'} .= "No spare found";
    }

    # Special case: output any critical and warning data first
    $$out{'perfStr'} = "${perfCritStr}${perfWarnStr}" . $$out{'perfStr'};

    $$out{'perfStr'} =~ s/^ //;
    $$out{'perfStr'} =~ s/,$//;
    if ($$out{'perfStr'} ne '') {
        $$out{'perfStr'} = "|".$$out{'perfStr'};
    } else {
        $$out{'perfStr'} = "|nok=$inst_count_nok;;;; ok=$inst_count_ok;;;;${_perfstop} total=$inst_count;;;;";
    }
}

#
# Print usage
# Takes: nothing
# Returns: nothing
sub usage {
    (my $Me = $0) =~ s!.*/!!;
    print STDOUT << "EOF";

IBM Storwize health status plugin for Nagios.
Needs wbemcli to query the Storwize Arrays CIMOM server.

Usage: $Me [-h] -H host [-P port] -u user -p password -C check [-c crit] [-w warn]

Flags:

    -C check    Check to run. Currently available checks:

                Array, ArrayBasedOnDiskDrive*, BackendVolume, Cluster, ConcreteStoragePool*,
                DiskDrive, Enclosure, EthernetPort, FCPort, IOGroup*, IsSpare, MasterConsole,
                MirrorExtent, Node, QuorumDisk, StorageVolume
                BackendController, BackendTargetSCSIProtocolEndpoint, FCPortStatistics
                ProtocolEndpoint, iSCSIProtocolEndpoint, ProtocolController, RemoteCluster,
                HostCluster

    -h          Print this help message.
    -H host     Hostname of IP of the SVC cluster.
    -P port     CIMOM port on the SVC cluster.
    -p          Password for CIMOM access on the SVC cluster.
    -u          User with CIMOM access on the SVC cluster.
    -c crit     Critical threshold (only for checks with '*')
    -w warn     Warning threshold (only for checks with '*')
    -s skip     Skip element(s) using regular expression
    -b bytes    Do not convert bytes to MiB GiB TiB

EOF
    exit;
}

#
# Main
#
# Check if wbemcli exists
if (! -x $conf{'wbemcli'}) {
    print ("ERROR: wbemcli not found\n");
    exit 2;
}
# Get command-line options
cli(\%conf);

# Query Storwize for check output
queryStorwize(\%conf, \%output, \%rcmap);

print uc($conf{'SNAME'}{$conf{'check'}})." $conf{'STATUS'}{$output{'retRC'}} - $output{'retStr'}$output{'perfStr'}\n";
exit $output{'retRC'};

#
## EOF
# vim:set noai tabstop=4 shiftwidth=4 softtabstop=4 noexpandtab:
