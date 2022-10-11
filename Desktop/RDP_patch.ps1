# PowerShell скрипт модифицирует файл termsrv.dll, разрешая множественные RDP подключения к рабочим станциям на базе Windows 10 (1809 и выше) и Windows 11
# Подробности https://winitpro.ru/index.php/2015/09/02/neskolko-rdp-sessij-v-windows-10/

# Чтобы выполнить скрипт, скачайте его на свой компьютер. Измените настройки политики запуска скриптов PowerShell:
# Set-ExecutionPolicy Bypass -Scope Process -Force

# Запустите скрипт:
# C:\users\root\desktop\rdp_patch.ps1


<# what to find 
Windows 11 RTM ( 21H2 22000.258)	39 81 3C 06 00 00 0F 84 4F 68 01 00	 
Windows 10 x64 21H2	39 81 3C 06 00 00 0F 84 DB 61 01 00
Windows 10 x64 21H1	39 81 3C 06 00 00 0F 84 2B 5F 01 00
Windows 10 x64 20H2	39 81 3C 06 00 00 0F 84 21 68 01 00
Windows 10 x64 2004	39 81 3C 06 00 00 0F 84 D9 51 01 00
Windows 10 x64 1909	39 81 3C 06 00 00 0F 84 5D 61 01 00
Windows 10 x64 1903	39 81 3C 06 00 00 0F 84 5D 61 01 00
Windows 10 x64 1809	39 81 3C 06 00 00 0F 84 3B 2B 01 00
Windows 10 x64 1803	8B 99 3C 06 00 00 8B B9 38 06 00 00
Windows 10 x64 1709	39 81 3C 06 00 00 0F 84 B1 7D 02 00
#> 

<# replace to 
B8 00 01 00 00 89 81 38 06 00 00 90 
#>



# Остановить службу, сделать копию файл и изменить разрешения
Stop-Service UmRdpService -Force
Stop-Service TermService -Force
$termsrv_dll_acl = Get-Acl c:\windows\system32\termsrv.dll
Copy-Item c:\windows\system32\termsrv.dll c:\windows\system32\termsrv.dll.copy
takeown /f c:\windows\system32\termsrv.dll
$new_termsrv_dll_owner = (Get-Acl c:\windows\system32\termsrv.dll).owner
cmd /c "icacls c:\windows\system32\termsrv.dll /Grant $($new_termsrv_dll_owner):F /C"
# поиск шаблона в файле termsrv.dll
$dll_as_bytes = Get-Content c:\windows\system32\termsrv.dll -Raw -Encoding byte
$dll_as_text = $dll_as_bytes.forEach('ToString', 'X2') -join ' '
$patternregex = ([regex]'39 81 3C 06 00 00(\s\S\S){6}')
$patch = 'B8 00 01 00 00 89 81 38 06 00 00 90'
$checkPattern=Select-String -Pattern $patternregex -InputObject $dll_as_text
If ($checkPattern -ne $null) {
$dll_as_text_replaced = $dll_as_text -replace $patternregex, $patch
}
Elseif (Select-String -Pattern $patch -InputObject $dll_as_text) {
Write-Output 'The termsrv.dll file is already patch, exitting'
Exit
}
else { 
Write-Output "Pattern not found "
}
# модификация файла termsrv.dll
[byte[]] $dll_as_bytes_replaced = -split $dll_as_text_replaced -replace '^', '0x'
Set-Content c:\windows\system32\termsrv.dll.patched -Encoding Byte -Value $dll_as_bytes_replaced
# Сравним два файла 
fc.exe /b c:\windows\system32\termsrv.dll.patched c:\windows\system32\termsrv.dll
# замена оригинального файла
Copy-Item c:\windows\system32\termsrv.dll.patched c:\windows\system32\termsrv.dll -Force
Set-Acl c:\windows\system32\termsrv.dll $termsrv_dll_acl
Start-Service UmRdpService
Start-Service TermService
