# New-MRNGRootNode
## SYNOPSIS
Create an empty mRemoteNG root connections node.

## SYNTAX
```powershell
New-MRNGRootNode [[-EncryptionKey] <SecureString>] [<CommonParameters>]
```

## DESCRIPTION


## PARAMETERS
### -EncryptionKey &lt;SecureString&gt;
The encryption key to use for this connections file.
```
Required?                    false
Position?                    1
Default value                ( ConvertTo-SecureString -String 'mR3m' -AsPlainText -Force )
Accept pipeline input?       false
Accept wildcard characters?  false
```

## INPUTS


## OUTPUTS
mRemoteNG.Tree.Root.RootNodeInfo

## NOTES


## EXAMPLES
### EXAMPLE 1
```powershell
PS C:\>$RootNode = New-MRNGRootNode
```


