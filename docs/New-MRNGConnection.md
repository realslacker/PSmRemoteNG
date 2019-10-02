# New-MRNGConnection
## SYNOPSIS
Create an mRemoteNG connection node.

## SYNTAX
```powershell
New-MRNGConnection [<CommonParameters>]
```

## DESCRIPTION


## PARAMETERS
## INPUTS


## OUTPUTS
mRemoteNG.Connection.ConnectionInfo

## NOTES


## EXAMPLES
### EXAMPLE 1
```powershell
PS C:\>New-MRNGConnection -Name 'Test Connection' -HostName '127.0.0.1' -Parent $RootNode -Protocol SSH2 -Inheritance (New-MRNGInheritanceConfiguration -EverythingInherited -Protocol:$false)
```

 
### EXAMPLE 2
```powershell
PS C:\>$Connection = New-MRNGConnection -Name 'Test Connection' -HostName '127.0.0.1'

$RootContainer.AddChild( $Connection )
```


