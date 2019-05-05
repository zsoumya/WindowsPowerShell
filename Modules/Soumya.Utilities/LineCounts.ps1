# Quick & dirty PowerShell script to report the record count of each file in the folder (Soumya)

function Get-LineCounts {
	[CmdletBinding()]
	param (
		[string]$filesPath = "*.txt"
	)
	PROCESS
	{
		$folderName = Split-Path $filesPath
		$fileFilter = Split-Path $filesPath -Leaf
		
		if ([string]::IsNullOrWhiteSpace($folderName)) {
			$filesPath = "."
		}
		
		if ([string]::IsNullOrWhiteSpace($fileFilter)) {
			$fileFilter = "*.txt"
		}
		
		Write-Verbose ("`r`nFolder: {0}`r`nFilter: {1}" -f $filesPath, $fileFilter)
		
		Get-ChildItem $filesPath | ForEach-Object { 
			$_ | Select-Object `
				Name, `
				@{ Name = "Count"; Expression = { (Get-Content $_.FullName | Measure-Object -Line | Select-Object -ExpandProperty Lines) - 1 }}
		} | Format-Table -AutoSize
	}
}