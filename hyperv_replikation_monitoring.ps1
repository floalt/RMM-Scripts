# HyperV Replikation Monitoring für GFI/Solarwinds Remote Management
# author: flo.alt@fa-netz.de
# Ver 0.8

# Hier die Alarmschelle (in Stunden) definieren:
# Überprüfung hinzufügen / Scriptparameter Befehlszeile: "-AlarmTime 5" eintragen, für z.B. 5 Stunden
# Die Prüfung schlägt dann fehl, wenn die letzte Replikation einer VM mehr als 5 Stunden zurück liegt

param(
    $AlarmTime
    )

# Replikations-Status abfragen, aktuelle Zeit festhalten

$VMList = Get-VMReplication  -ErrorAction SilentlyContinue
$TimeNow = Get-Date
Write-Host "Alarmschwelle: $AlarmTime Stunden"

# Jede VM Prüfen

foreach ($VM in $VMList) {
    $VMcurrent = $VM.Name
                # Ausrechenen, wie lange die letzte Replikation zurückliegt
    $TimeLastRpl = $VM.LastReplicationTime
    $DiffTime = ($TimeNow)-($TimeLastRpl)
                # Entscheiden, ob ein Alarm ausgelöst wird
    if ($DiffTime.TotalHours -lt $AlarmTime) {
        $DiffTimeMin = [System.Math]::Round($DiffTime.TotalMinutes)
        Write-Host "OK: $VMcurrent : Letzte Replikation vor $DiffTimeMin Minuten"
        }
    elseif ($DiffTime.TotalHours -gt $AlarmTime) {
        $AlarmCount = $AlarmCount + 1
        $DiffTimeHrs = [System.Math]::Round($DiffTime.TotalHours)
        Write-Host "Fehler: $VMcurrent : Letzte Replikation vor $DiffTimeHrs Stunden"
        }
    else {
        $AlarmCount = $AlarmCount + 1
        Write-Host "Fehler: $VMcurrent : Fehler beim Prüfen der Replikation"
        }
    }

# Replikation fortsetzen

ForEach ($VM in $VMList) {
    $VMcurrent = $VM.Name
                # Replikation fortsetzen, wenn der Status nicht normal ist und auch nicht bereits synchronisiert wird
    if ($VM.health -ne "Normal" -and $VM.state -ne "Resynchronizing") {
        Resume-VMReplication -VMName $VM.Name -Resynchronize -Verbose
        Write-Host "Aktion: $VMcurrent : Neusynchronisierung gestartet"
        }
                # Replikation starten, wenn auf Start wartet
    elseif ($VM.state -match "WaitingForStartResynchronize") {
        Resume-VMReplication -VMName $VM.Name -Resynchronize -Verbose
        Write-Host "Aktion: $VMcurrent : Neusynchronisierung gestartet"
        }
                # Statistiken zurücksetzen, wenn gerade synchronisiert wird
    elseif ($VM.state -match "Resynchronizing") {
        Reset-VMReplicationStatistics -VMName $VM.Name
        Write-Host "Aktion: $VMcurrent : Neusynchronisierung bereits in Arbeit"
        }
    }


# Alarm fürs Monitoring auslösen

if ($AlarmCount -eq "0") {
    Write-Host "Alles im Lot aufm Replikations-Boot"
    Exit 0
    }
elseif ($AlarmCount -eq "1") {
    Write-Host "1 VM mit fehlerhafter Replikation"
    Exit 1001
    }
elseif ($AlarmCount -gt "1") {
    Write-Host "$AlarmCount VMs mit fehlerhafter Replikation"
    Exit 1001
    }
