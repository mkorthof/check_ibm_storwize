#!/bin/sh

# Test all Checks

# Example:
#   check_ibm_storwize.pl -H ibm03.example.com -u none -p none -t -C Array

SCRIPT="../libexec/check_ibm_storwize.pl"
ARGS="-H ibm03.example.com -u none -p none"
CHECKS="
Array ArrayBasedOnDiskDrive BackendVolume Cluster ConcreteStoragePool
DiskDrive Enclosure EthernetPort FCPort IOGroup IsSpare MasterConsole
MirrorExtent Node QuorumDisk StorageVolume
BackendController BackendTargetSCSIProtocolEndpoint FCPortStatistics
IPProtocolEndpoint iSCSIProtocolEndpoint ProtocolController RemoteCluster
HostCluster
"

if [ ! -x "$SCRIPT" ]; then
  echo "ERROR: cannot run $SCRIPT"
  exit 1
fi

i=0
ecnt=0
printf "[TEST_START] %s pid=%s\n\n" "$(date +%F\ %T)" "$$"
for c in $CHECKS; do 
  printf "[TEST] Testing check: %s ... " "$c"
  $SCRIPT $ARGS -t -C "$c" >/dev/null || { \
    rc="$?"
    if [ "${rc:-'-1'}" -gt 2 ]; then
      C="$C $c"
      ecnt=$((ecnt+1))
      printf "FAIL: check=%s (rc=%s ecnt=%s)\n" "$c" "$rc" "$ecnt"
    fi
  }
  echo
  i=$((i+1))
done
echo

printf "[TEST_END] %s pid=%s Tested %s checks\n\n" "$(date +%F\ %T)" "$$" "$i"
if [ "${ecnt:-0}" -gt 0 ]; then
  printf "[TEST_RESULT] Errors: %s Total: %s\n" "$ecnt" "$i"
  printf "[TEST_RESULT] Failed checks:%s\n" "$C"
else
  printf "[TEST_RESULT] All OK. Total: %s\n" "$i"
fi
echo