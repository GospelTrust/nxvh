$ErrorActionPreference = 'Stop'

function Is-ComplexYamlNode {
    param([object]$Value)

    return ($Value -is [pscustomobject]) -or
           ($Value -is [System.Collections.IDictionary]) -or
           (($Value -is [System.Collections.IEnumerable]) -and -not ($Value -is [string]))
}

function Convert-ScalarToYaml {
    param([object]$Value)

    if ($null -eq $Value) {
        return 'null'
    }

    if ($Value -is [bool]) {
        if ($Value) { return 'true' } else { return 'false' }
    }

    if ($Value -is [byte] -or $Value -is [int16] -or $Value -is [int] -or $Value -is [int64] -or
        $Value -is [single] -or $Value -is [double] -or $Value -is [decimal]) {
        return [string]$Value
    }

    $text = [string]$Value
    $text = $text -replace "'", "''"
    return "'$text'"
}

function Write-YamlValue {
    param(
        [object]$Value,
        [string]$Indent
    )

    $lines = New-Object System.Collections.Generic.List[string]

    if ($Value -is [pscustomobject]) {
        $dict = [ordered]@{}
        foreach ($p in $Value.PSObject.Properties) {
            $dict[$p.Name] = $p.Value
        }
        return Write-YamlValue -Value $dict -Indent $Indent
    }

    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($k in $Value.Keys) {
            $key = [string]$k
            $child = $Value[$k]

            if (Is-ComplexYamlNode -Value $child) {
                $lines.Add("$Indent${key}:")
                $childLines = Write-YamlValue -Value $child -Indent ($Indent + '  ')
                foreach ($line in $childLines) { $lines.Add($line) }
            }
            else {
                $lines.Add("$Indent${key}: $(Convert-ScalarToYaml -Value $child)")
            }
        }

        return $lines
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        foreach ($item in $Value) {
            if (Is-ComplexYamlNode -Value $item) {
                $lines.Add("$Indent-")
                $childLines = Write-YamlValue -Value $item -Indent ($Indent + '  ')
                foreach ($line in $childLines) { $lines.Add($line) }
            }
            else {
                $lines.Add("$Indent- $(Convert-ScalarToYaml -Value $item)")
            }
        }

        return $lines
    }

    $lines.Add("$Indent$(Convert-ScalarToYaml -Value $Value)")
    return $lines
}

function Convert-JsonFileToYamlFile {
    param([string]$Path)

    $raw = Get-Content -Path $Path -Raw -Encoding UTF8
    $obj = ConvertFrom-Json -InputObject $raw

    $yamlLines = Write-YamlValue -Value $obj -Indent ''
    $yamlText = ($yamlLines -join "`n") + "`n"

    Set-Content -Path $Path -Value $yamlText -Encoding UTF8
}

Convert-JsonFileToYamlFile -Path 'd:\code\nxvh\_data\john_vie1925.yml'
Convert-JsonFileToYamlFile -Path 'd:\code\nxvh\_data\john_vie2010.yml'
Write-Output 'Converted john_vie1925.yml and john_vie2010.yml to YAML syntax'
