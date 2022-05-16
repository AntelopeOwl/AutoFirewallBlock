#reading the variables from the text files
$programs = get-content -path progs.txt
$dlls = get-content -path dlls.txt
$name = get-content name.txt
#Creating the firewall rule with NETSH ForEach in/out
$a = 1
$b = 1
ForEach ($pgr in $programs) {
	$name_a = $name + $a
    netsh advfirewall firewall add rule name="AFB_exe_$name_a" dir=in action=block program=$pgr enable=yes | out-null
    netsh advfirewall firewall add rule name="AFB_exe_$name_a" dir=out action=block program=$pgr enable=yes | out-null
    $a++
    }
ForEach ($dll in $dlls) {
	$name_b = $name + $b
    netsh advfirewall firewall add rule name="AFB_dll_$name_b" dir=in action=block program=$dll enable=yes | out-null
    netsh advfirewall firewall add rule name="AFB_dll_$name_b" dir=out action=block program=$dll enable=yes | out-null
    $b++
    }
$a | Out-File  $PSScriptRoot\count_pgr.txt -Encoding ascii
$b | Out-File  $PSScriptRoot\count_dll.txt -Encoding ascii
