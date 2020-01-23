param([switch]$Publish)

# module variables
$ScriptPath = Split-Path (Get-Variable MyInvocation -Scope Script).Value.Mycommand.Definition -Parent
$ModuleName = (Get-Item $ScriptPath).BaseName

# create build directory
$BuildNumber = Get-Date -Format 'yy.M.d.Hmm'
$BuildDirectory = New-Item -Path "$ScriptPath\build\$BuildNumber\$ModuleName" -ItemType Directory -ErrorAction Stop

# excluded files / directories
$ExcludedFiles = '.git', '.vscode', 'build', 'Build.ps1'

# copy needed files
Get-ChildItem -Path $ScriptPath |
    Where-Object { $_.Name -notin $ExcludedFiles } |
    Copy-Item -Destination $BuildDirectory -Recurse

# update the build version
$ModuleManifestSplat = @{
    Path              = "$BuildDirectory\$ModuleName.psd1"
    ModuleVersion     = $BuildNumber
}
Update-ModuleManifest @ModuleManifestSplat

# sign the scripts
Get-ChildItem -Path $BuildDirectory -Filter '*.psm1' |
    ForEach-Object {

        Add-SignatureToScript -Path $_.FullName

    }

# publish
if ( $Publish ) {

    Publish-Module -Path "$BuildDirectory" @PSGalleryPublishSplat

}