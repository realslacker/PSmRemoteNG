# New-MRNGContainer
## SYNOPSIS
Create an mRemoteNG container node.

## SYNTAX
```powershell
New-MRNGContainer [<CommonParameters>]
```

## DESCRIPTION


## PARAMETERS
## INPUTS


## OUTPUTS
mRemoteNG.Container.ContainerInfo

## NOTES


## EXAMPLES
### EXAMPLE 1
```powershell
PS C:\>New-MRNGContainer -Name 'Test Container' -Parent $RootNode -Protocol SSH2
```

 
### EXAMPLE 2
```powershell
PS C:\>$Container = New-MRNGContainer -Name 'Test Container'

$RootContainer.AddChild( $Container )

$Container2 = New-MRNGContainer -Name 'Child Container'
$Container.AddChild( $Container2 )
```


