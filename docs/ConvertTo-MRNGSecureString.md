# ConvertTo-MRNGSecureString
## SYNOPSIS
Convert a plain text string to a mRemoteNG secure string.

## SYNTAX
```powershell
ConvertTo-MRNGSecureString [-Message] <String> [[-EncryptionKey] <SecureString>] [[-EncryptionEngine] <String>] [[-BlockCipherMode] <String>] [[-KeyDerivationIterations] <Int32>] [<CommonParameters>]
```

## DESCRIPTION


## PARAMETERS
### -Message &lt;String&gt;
The string to be converted.
```
Required?                    true
Position?                    1
Default value
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -EncryptionKey &lt;SecureString&gt;
The encryption key to use when encrypting the string. It should match what you are using in your ConfCons.xml file. If no password is supplied the default mRemoteNG encryption key is "mR3m".
```
Required?                    false
Position?                    2
Default value                ( ConvertTo-SecureString -String 'mR3m' -AsPlainText -Force )
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -EncryptionEngine &lt;String&gt;
The encryption engine to use when encrypting the string. Choices are 'AES', 'Serpent', and 'Twofish'. The default is 'AES'.
```
Required?                    false
Position?                    3
Default value                AES
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -BlockCipherMode &lt;String&gt;
The block cipher mode to use when encrypting the string. Choices are 'GCM', 'CCM', and 'EAX'. The default is 'GCM'.
```
Required?                    false
Position?                    4
Default value                GCM
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -KeyDerivationIterations &lt;Int32&gt;
The number of key derivation iterations to perform when encrypting the string. Valid values are in the range 1,000 to 50,000.
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
PS C:\>ConvertTo-MRNGSecureString -Message 'SecureP@ssword!'
```

 
### EXAMPLE 2
```powershell
PS C:\>ConvertTo-MRNGSecureString -Message 'SecureP@ssword!' -EncryptionEngine Serpent -BlockCipherMode EAX
```

 
### EXAMPLE 3
```powershell
PS C:\>ConvertTo-MRNGSecureString -Message 'SecureP@ssword!' -EncryptionKey ( 'password' | ConvertTo-SecureString -AsPlainText -Force )
```


