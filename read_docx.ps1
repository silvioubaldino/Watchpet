Add-Type -AssemblyName System.IO.Compression.FileSystem
$docxPath = "c:\github\silvioubaldino\Watchpet\.agents\rules\WatchPet_AyD_v2.docx"
$txtPath = "c:\github\silvioubaldino\Watchpet\.agents\rules\WatchPet_AyD_v2.txt"

$stream = [System.IO.Compression.ZipFile]::OpenRead($docxPath)
$entry = $stream.GetEntry("word/document.xml")
$reader = New-Object System.IO.StreamReader($entry.Open())
$xmlStr = $reader.ReadToEnd()
$reader.Close()
$stream.Dispose()

# Simple regex to remove xml tags
$text = $xmlStr -replace '<[^>]+>', ' '
# Clean up multiple spaces
$text = $text -replace '\s+', ' '

Out-File -FilePath $txtPath -InputObject $text -Encoding UTF8
Write-Output "Extracted text to $txtPath"
