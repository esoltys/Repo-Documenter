# Create a small binary file (less than 8K)
$smallBinaryPath = "small_binary.bin"
[System.IO.File]::WriteAllBytes($smallBinaryPath, (1..1000 | ForEach-Object { Get-Random -Minimum 0 -Maximum 255 }))

# Create a large text file (over 1MB)
$largeTextPath = "large_text.txt"
1..100000 | ForEach-Object { Add-Content -Path $largeTextPath -Value ("Line " + $_) }

# Create a mixed content file
$mixedContentPath = "mixed_content.txt"
$mixedContent = "This is some text content" + [char]0 + "This is after a null byte"
[System.IO.File]::WriteAllText($mixedContentPath, $mixedContent)

# Create a non-ASCII text file
$nonAsciiPath = "non_ascii.txt"
[System.IO.File]::WriteAllText($nonAsciiPath, "こんにちは世界", [System.Text.Encoding]::UTF8)

# Create an empty file
$emptyFilePath = "empty_file.txt"
New-Item -Path $emptyFilePath -ItemType File -Force

Write-Host "Test files created successfully."