# Windows smoke test

Исходный профиль `EndeavourOS QEMU 1920x1080.bat` перенесён в параметризованный и проверяемый PowerShell launcher [Invoke-EndeavourOSSmoke.ps1](../tools/Invoke-EndeavourOSSmoke.ps1).

Проверка QEMU и QCOW2 без запуска гостя:

```powershell
.\tools\Invoke-EndeavourOSSmoke.ps1 -InspectOnly
```

Запуск в окне:

```powershell
.\tools\Invoke-EndeavourOSSmoke.ps1
```

Полноэкранный запуск:

```powershell
.\tools\Invoke-EndeavourOSSmoke.ps1 -FullScreen
```

Launcher перед стартом выполняет `qemu-img check`, печатает format, virtual/actual size и dirty flag, затем передаёт каждый аргумент QEMU отдельно через `ProcessStartInfo.ArgumentList`.

После установки Isora тот же диск подключается без копирования:

```powershell
IsoraCLI.exe vm import "EndeavourOS QEMU 1920x1080" "C:\Users\ll-host\Documents\Virtual Machines\EndeavourOS-10G.qcow2" --memory 4096 --cpus 4
```

В GUI эквивалентная команда находится на странице «Виртуальные машины» → «Подключить QCOW2». Исходный диск остаётся на месте; удаление записи Isora его не удаляет.

## Ручной чек-лист

1. EndeavourOS доходит до рабочего стола без зависания QEMU.
2. Разрешение 1920×1080, курсор не захватывается со смещением, клавиатура работает.
3. Reboot внутри гостя возвращает его в загрузку, а не закрывает QEMU.
4. Shutdown внутри гостя закрывает окно QEMU и освобождает процесс.
5. Повторный запуск проходит с `dirty-flag: false`.
6. После reboot Windows Isora сохраняет настройки, но не запускает VM автоматически.
