# ConvertFrom-MRNGSecureString
## SYNOPSIS
Convert a mRemoteNG secure string to plain text.

## SYNTAX
```powershell
ConvertFrom-MRNGSecureString [-EncryptedMessage] <String> [[-EncryptionKey] <SecureString>] [[-EncryptionEngine] <String>] [[-BlockCipherMode] <String>] [[-KeyDerivationIterations] <Int32>] [<CommonParameters>]
```

## DESCRIPTION


## PARAMETERS
### -EncryptedMessage &lt;String&gt;
The mRemoteNG secure string to be converted.
```
Required?                    true
Position?                    1
Default value
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -EncryptionKey &lt;SecureString&gt;
The encryption key that was used when encrypting the ConfCons.xml file. If no password is supplied the default mRemoteNG encryption key is "mR3m".
```
Required?                    false
Position?                    2
Default value                ( ConvertTo-SecureString -String 'mR3m' -AsPlainText -Force )
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -EncryptionEngine &lt;String&gt;
The encryption engine to use when decrypting the string. Choices are 'AES', 'Serpent', and 'Twofish'. The default is 'AES'.
```
Required?                    false
Position?                    3
Default value                AES
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -BlockCipherMode &lt;String&gt;
The block cipher mode to use when decrypting the string. Choices are 'GCM', 'CCM', and 'EAX'. The default is 'GCM'.
```
Required?                    false
Position?                    4
Default value                GCM
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -KeyDerivationIterations &lt;Int32&gt;
The number of key derivation iterations to perform when decrypting the string. Valid values are in the range 1,000 to 50,000.
```
Required?                    false
Position?                    5
Default value                1000
Accept pipeline input?       false
Accept wildcard characters?  false
```

## INPUTS


## OUTPUTS
System.String

## NOTES


## EXAMPLES
### EXAMPLE 1
```powershell
PS C:\>ConvertFrom-MRNGSecureString -EncryptedMessage 'pLs5zen+UvaqFnn2KDn2eTrhO60gjzagqFnI/8n3dF74zCj9lZDGvR1nJ8bxf5OCuHJW8gcWFWOicNIvV4h1'
```

 
### EXAMPLE 2
```powershell
PS C:\>ConvertFrom-MRNGSecureString -EncryptedMessage 'LkJUc6Q60hsZmX6QImOS+1nvFYQLNNCfP7iEupby8Ey84Dz+3u7lRo93YaL6fJf2GCXOtpXtzgZACxhVKcJh' -EncryptionEngine Serpent -BlockCipherMode EAX
```

 
### EXAMPLE 3
```powershell
PS C:\>ConvertFrom-MRNGSecureString -EncryptedMessage 'MqE3IQxYiLioTaD86rzRusDmiD2nX2b9uabDASZdRB9+gk7ygLWSqYFVEg5zqa65qe6j3ZPtgeLxKNZiIoGv' -EncryptionKey ( 'password' | ConvertTo-SecureString -AsPlainText -Force )
```


