# Development

There are 2 flags which are useful while working on the script: 

- `-d` and `-D` for debug, 1: debug output 2: increase verbosity
- `-t` and `-T` for test mode, 1: mock text files 2: local server

## Creating mock text files

Create mock for test mode 1 by saving wbem query results to "\<Check\>.txt" in "test" dir.
If there are multiple instances make sure to add a newline in between and always end the file with 2 newlines.

For example, to create a mock for "HostCluster":

`wbemcli -noverify -nl ei https://myuser:p4ss@ibm03.example.com:5989/root/ibm:IBMTSSVC_HostCluster > test/HostCluster.txt"`

## Testing with mock text files

To use "test/HostCluster.txt", run from libexec dir:

`check_ibm_storwize.pl -H ibm03.example.com -u none -p none -C HostCluster -t -d`

This runs `cat` on the file, instead of actually running wbemcli for input.

Test all checks: `tests/test_checks.sh`

## Testing with local CIM server

These seem to be the main available options:

- [OpenPegasus](https://openpegasus.org), <https://github.com/OpenPegasus/OpenPegasus>
- [SBLIM](https://sblim.sourceforge.net)
- pywbem, pywbemtools (pip) 

OpenPegasus was the easiest to setup. Compile with `setup.sh` and `make`, then start `cimserver`. Running `cimmof` on the IBM mof's in [docs](docs) dir will add them to the repository. 

Now point the script to localhost in test mode 2:

 `./check_ibm_storwize.pl -H localhost -u none -p none -C CIMOMStatisticalData -T`

## Manually running wbemcli 

Some other webcli commands that might be of use (e.g. to compare output):

`wbemcli -noverify -nl ei https://myuser:p4ss@ibm03.example.com:5989/root/ibm:IBMTSSVC_Array`
`wbemcli -noverify -nl ecn https://myuser:p4ss@ibm03.example.com:5989/root/ibm`

```
for i in $( wbemcli -noverify -nl ecn https://myuser:p4ss@ibm03.example.com:5989/root/ibm ); do
  wbemcli -noverify -nl ei $i
done > ibm-wbem-all.txt
```

- `ei`: Enumerate Instances
- `ecn`: Enumerate Class Names
- option `-nl`: New Line
- option `-dx`: Show XML
