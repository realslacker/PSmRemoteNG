[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(

    [string]
    $ExportPath = "$env:APPDATA\mRemoteNG\PSmRemoteNG.xml",

    [securestring]
    $EncryptionKey = ( ConvertTo-SecureString -String 'mR3m' -AsPlainText -Force ),

    [hashtable]
    $CredentialMap = @{}

)

$ErrorActionPreference = 'Stop'

if ( $CredentialMap.Keys.Count -and ( [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($EncryptionKey)) -eq 'mR3m' ) ) {

    throw 'You must supply an encryption key when storing credentials.'

}

#requires -modules PSmRemoteNG

Write-Host 'Generating config file...' -ForegroundColor White

# create the root node with the specified EncryptionKey
# note that you must ALWAYS supply an EncryptionKey, even
# if using the default value 'mR3m' or the config won't open
# in mRemoteNG. Supplying the default value with bypass the
# prompt.
$RootNode = New-MRNGRootNode -EncryptionKey $EncryptionKey

Write-Host 'Searching for AD Forests that your domain trusts...' -ForegroundColor White

# all forests container variable
$Forests = @()

# add your forest
$Forests += @(, (Get-ADForest).Name )

# get all AD Forests that your domain trusts
$Forests += Get-ADTrust -Filter * |
    Where-Object { $_.ForestTransitive -eq $true } |
    Select-Object -ExpandProperty Target |
    Sort-Object

foreach ( $Forest in $Forests ) {

    # will hold inheritance for containers if defined
    $InheritanceSplat = @{}

    # find all domains in the forest
    try {

        $Domains = Get-ADForest -Server $Forest |
            Select-Object -ExpandProperty Domains

    } catch {

        if ( ( Read-Host ( 'Could not contact forest ''{0}'', continue? [y/N]' -f $Forest ) ) -match '^y' ) {

            continue

        } else {

            throw 'Cancelled'

        }

    }

    # if the forest has more than one domain we make a forest container
    if ( $Domains.Count -gt 1 ) {

        Write-Host ( 'Create forest container: {0}' -f $Forest ) -ForegroundColor Cyan

        $ForestContainer = New-MRNGContainer -Name $Forest -Parent $RootNode

        # if the $CredentialMap has a key matching the forest
        # we set the credential on the container and turn on
        # inheritance
        if ( $CredentialMap.Keys -contains $Forest ) {
            
            $ForestContainer.Username = $CredentialMap[$Forest].GetNetworkCredential().Username
            $ForestContainer.Domain   = $CredentialMap[$Forest].GetNetworkCredential().Domain
            $ForestContainer.Password = $CredentialMap[$Forest].GetNetworkCredential().Password

            $InheritanceSplat.Inheritance = New-MRNGInheritanceConfiguration -EverythingInherited

        }

    # otherwise we just use the root node
    } else {
        
        $ForestContainer = $RootNode

    }

    # now we process the domains
    foreach ( $Domain in $Domains ) {

        Write-Host ( 'Searching for servers in {0}...' -f $Domain ) -ForegroundColor White

        # find the domain controller
        $DomainController = Get-ADDomainController -DomainName $Domain -Discover -Service ADWS |
            Select-Object -ExpandProperty HostName

        # look for servers in the domain
        $Servers = Get-ADComputer -Filter 'OperatingSystem -like "*Windows Server*"' -Server $DomainController -Properties OperatingSystem, Description, IPv4Address, DNSHostName, Enabled |
            Select-Object @{N='Name';E={ $_.Name + (' (disabled)','')[$_.Enabled] }},
                          @{N='HostName';E={ $_.DNSHostName }},
                          @{N='Description';E={ ( $_.Description, $_.OperatingSystem )[ [string]::IsNullOrEmpty($_.Description) ] }}

        if ( $Servers.Count -eq 0 ) {

            Write-Host 'No servers found, skipping...' -ForegroundColor Gray

            continue

        }

        Write-Host ( 'Create domain container: {0}' -f $Domain ) -ForegroundColor DarkCyan

        $DomainContainer = New-MRNGContainer -Name $Domain -Parent $ForestContainer @InheritanceSplat
        
        if ( $CredentialMap.Keys -contains $Domain ) {

            $DomainContainer.Username = $CredentialMap[$Domain].GetNetworkCredential().Username
            $DomainContainer.Domain   = $CredentialMap[$Domain].GetNetworkCredential().Domain
            $DomainContainer.Password = $CredentialMap[$Domain].GetNetworkCredential().Password

            $InheritanceSplat.Inheritance = New-MRNGInheritanceConfiguration -EverythingInherited

        }

        Write-Host ( 'Creating {0} servers connections...' -f $Servers.Count ) -ForegroundColor DarkGray

        foreach ( $Server in $Servers ) {

            $ServerInheritanceSplat = @{}

            Write-Host ( 'Create server connection: {0}' -f $Server.Name ) -ForegroundColor Gray

            if ( -not [string]::IsNullOrEmpty( $Server.Description ) -and $InheritanceSplat.Inheritance ) {
                    
                $ServerInheritanceSplat = $InheritanceSplat.Clone()
                $ServerInheritanceSplat.Inheritance.Description = $false

            }

            $ServerConnection = New-MRNGConnection -Name $Server.Name -Hostname $Server.HostName -Description $Server.Description -Parent $DomainContainer @ServerInheritanceSplat
        
        }

    }

}

Write-Host ''

if ( -not( Test-Path -Path $ExportPath -PathType Leaf ) -or $PSCmdlet.ShouldProcess( $ExportPath, 'Replace Configuration' ) ) {

    Export-MRNGConnectionFile -RootNode $RootNode -Path $ExportPath -SortConnections

    Write-Host 'New configuration file path:' -ForegroundColor White
    Write-Host $ExportPath -ForegroundColor White

} else {

    Write-Host 'Cancelled' -ForegroundColor Red

}
