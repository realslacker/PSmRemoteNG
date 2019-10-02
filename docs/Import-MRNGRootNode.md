# Import-MRNGRootNode
## SYNOPSIS
Import an mRemoteNG root connections node from a confCons.xml file.

## SYNTAX
```powershell
Import-MRNGRootNode [-Path] <FileInfo> [[-EncryptionKey] <SecureString>] [<CommonParameters>]
```

## DESCRIPTION


## PARAMETERS
### -Path &lt;FileInfo&gt;

```
Required?                    true
Position?                    1
Default value
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -EncryptionKey &lt;SecureString&gt;
The encryption key for the confCons.xml file.
```
Required?                    false
Position?                    2
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
PS C:\>$RootNode = Import-MRNGRootNode -Path .\confCons.xml -EncryptionKey ( Read-Host 'Encryiption Key' -AsSecureString )
```


