# find mRemoteNG install location
$mRNGDirectory = 'HKLM:\SOFTWARE\mRemoteNG', 'HKLM:\SOFTWARE\WOW6432Node\mRemoteNG' |
    ForEach-Object { Get-ItemProperty -Path $_ -Name InstallDir -ErrorAction SilentlyContinue } |
    Select-Object -First 1 -ExpandProperty InstallDir

# load assemblies
try {
    
    [void][System.Reflection.Assembly]::LoadFile( "$mRNGDirectory\mRemoteNG.exe" )
    [void][System.Reflection.Assembly]::LoadFile( "$mRNGDirectory\BouncyCastle.Crypto.dll" )

} catch {

    throw $Messages.AssemblyLoadError

}

<#
.SYNOPSIS
 Import an mRemoteNG root connections node from a confCons.xml file.

.PARAMETER EncryptionKey
 The encryption key for the confCons.xml file.

.EXAMPLE
 $RootNode = Import-MRNGRootNode -Path .\confCons.xml -EncryptionKey ( Read-Host 'Encryiption Key' -AsSecureString )

#>
function Import-MRNGRootNode {

    [OutputType([mRemoteNG.Tree.Root.RootNodeInfo])]
    param(

        [Parameter(Mandatory)]
        [System.IO.FileInfo]
        $Path,

        [securestring]
        $EncryptionKey = ( ConvertTo-SecureString -String 'mR3m' -AsPlainText -Force )
        
    )

    # resolve the path
    $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath( $Path )

    # load the XML
    $DataProvider = [mRemoteNG.Config.DataProviders.FileDataProvider]::new( $Path )
    $XmlString = $DataProvider.Load()

    # create a function to return the password
    # this is what mRemoteNG expects
    [Func[mRemoteNG.Tools.Optional[securestring]]]$Auth = { $EncryptionKey }

    # create a deserializer
    $Deserializer = [mRemoteNG.Config.Serializers.Xml.XmlConnectionsDeserializer]::new($Auth)
    
    # return the connections
    ( $Deserializer.Deserialize( $XmlString ) ).RootNodes.Item(0)

}

<#
.SYNOPSIS
 Create an empty mRemoteNG root connections node.

.PARAMETER EncryptionKey
 The encryption key to use for this connections file.

.EXAMPLE
 $RootNode = New-MRNGRootNode

#>
function New-MRNGRootNode {

    [OutputType([mRemoteNG.Tree.Root.RootNodeInfo])]
    param(

        [securestring]
        $EncryptionKey = ( ConvertTo-SecureString -String 'mR3m' -AsPlainText -Force )
        
    )

    # convert the encryption key to plaintext
    $EncryptionKeyBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $EncryptionKey )
    $EncryptionKeyText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto( $EncryptionKeyBSTR )

    $RootNode = [mRemoteNG.Tree.Root.RootNodeInfo]::new('Connection')

    # set a password?
    if ( $EncryptionKeyText -ne $RootNode.DefaultPassword ) {

        $RootNode.Password = $true
        $RootNode.PasswordString = $EncryptionKeyText

    }

    $RootNode

}

<#
.SYNOPSIS
 Create an mRemoteNG container node.

.EXAMPLE
 New-MRNGContainer -Name 'Test Container' -Parent $RootNode -Protocol SSH2

.EXAMPLE
 $Container = New-MRNGContainer -Name 'Test Container'
 $RootContainer.AddChild( $Container )

 $Container2 = New-MRNGContainer -Name 'Child Container'
 $Container.AddChild( $Container2 )

#>
function New-MRNGContainer {

    [OutputType([mRemoteNG.Container.ContainerInfo])]
    [CmdletBinding()]
    param()

    dynamicparam {

        $DPDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        $SkipParameters = 'Inheritance', 'ConstantID', 'IsContainer'

        [mRemoteNG.Container.ContainerInfo].GetProperties() |
            Where-Object { $SkipParameters -notcontains $_.Name } |
            ForEach-Object {

                $Attribute = New-Object System.Management.Automation.ParameterAttribute
                $Attribute.ParameterSetName  = '__AllParameterSets'
                $Collection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $Collection.Add($Attribute)
                $Parameter = New-Object System.Management.Automation.RuntimeDefinedParameter( $_.Name, $_.PropertyType, $Collection )
                $DPDictionary.Add( $_.Name, $Parameter )
                
            }

        $Attribute = New-Object System.Management.Automation.ParameterAttribute
        $Attribute.ParameterSetName  = '__AllParameterSets'
        $Collection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $Collection.Add($Attribute)
        $Parameter = New-Object System.Management.Automation.RuntimeDefinedParameter( 'Inheritance', [hashtable], $Collection )
        $DPDictionary.Add( 'Inheritance', $Parameter )
            
        return $DPDictionary    
    }

    process {

        $ContainerInfo = [mRemoteNG.Container.ContainerInfo]::new()

        # set default port
        if ( $PSBoundParameters.Keys -contains 'Protocol' -and $PSBoundParameters.Keys -notcontains 'Port' ) {

            $PSBoundParameters.Port = switch ( $PSBoundParameters.Protocol ) {
            
                'RDP'     { 3389 }
                'VNC'     { 5900 }
                'SSH1'    {   22 }
                'SSH2'    {   22 }
                'Telnet'  {   23 }
                'Rlogin'  {  513 }
                'RAW'     {   23 }
                'HTTP'    {   80 }
                'HTTPS'   {  443 }
                'IntApp'  {    0 }
            
            }
        
        }
        
        # set connection properties
        $PSBoundParameters.Keys |
            Where-Object { $_ -notmatch 'Parent|Children|Inheritance' } |
            Where-Object { [mRemoteNG.Container.ContainerInfo].GetProperties().Name -contains $_ } |
            ForEach-Object { $ContainerInfo.$_ = $PSBoundParameters.$_ }

        # configure inheritance
        if ( $PSBoundParameters.Keys -contains 'Inheritance' ) {
        
            # process EverythingInherited first
            if ( $PSBoundParameters.Inheritance.Keys -contains 'EverythingInherited' ) {

                $ContainerInfo.Inheritance.EverythingInherited = $true

            }

            # process all other inheritence
            $PSBoundParameters.Inheritance.Keys |
                Where-Object { $_ -ne 'EverythingInherited' } |
                ForEach-Object {

                    $ContainerInfo.Inheritance.$_ = $PSBoundParameters.Inheritance.$_

                }
        
        }

        # if children is specified we append
        if ( $PSBoundParameters.Keys -contains 'Children' ) {

            $PSBoundParameters.Children |
                ForEach-Object {
                
                    $ContainerInfo.AddChild($_)

                    Write-Verbose ( 'Child ''{0}'' added to ''{1}''.' -f $_.Name, $ContainerInfo.Name )
                    
                }

        }

        # if parent is specified we append, otherwise we output
        if ( $PSBoundParameters.Keys -contains 'Parent' ) {

            $PSBoundParameters.Parent.AddChild( $ContainerInfo )

            Write-Verbose ( 'Container ''{0}'' added to ''{1}''.' -f $ContainerInfo.Name, $PSBoundParameters.Parent.Name )

        }
        
        $ContainerInfo

    }

}

<#
.SYNOPSIS
 Create an mRemoteNG connection node.

.EXAMPLE
 New-MRNGConnection -Name 'Test Connection' -HostName '127.0.0.1' -Parent $RootNode -Protocol SSH2 -Inheritance (New-MRNGInheritanceConfiguration -EverythingInherited -Protocol:$false)

.EXAMPLE
 $Connection = New-MRNGConnection -Name 'Test Connection' -HostName '127.0.0.1'
 $RootContainer.AddChild( $Connection )

#>
function New-MRNGConnection {

    [OutputType([mRemoteNG.Connection.ConnectionInfo])]
    [CmdletBinding()]
    param()

    dynamicparam {

        $DPDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        $SkipParameters = 'Inheritance', 'ConstantID', 'IsContainer'

        [mRemoteNG.Connection.ConnectionInfo].GetProperties() |
            Where-Object { $SkipParameters -notcontains $_.Name } |
            ForEach-Object {

                $Attribute = New-Object System.Management.Automation.ParameterAttribute
                $Attribute.ParameterSetName  = '__AllParameterSets'
                $Collection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $Collection.Add($Attribute)
                $Parameter = New-Object System.Management.Automation.RuntimeDefinedParameter( $_.Name, $_.PropertyType, $Collection )
                $DPDictionary.Add( $_.Name, $Parameter )
                
            }

        $Attribute = New-Object System.Management.Automation.ParameterAttribute
        $Attribute.ParameterSetName  = '__AllParameterSets'
        $Collection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $Collection.Add($Attribute)
        $Parameter = New-Object System.Management.Automation.RuntimeDefinedParameter( 'Inheritance', [hashtable], $Collection )
        $DPDictionary.Add( 'Inheritance', $Parameter )
            
        return $DPDictionary    
    }

    process {

        $ConnectionInfo = [mRemoteNG.Connection.ConnectionInfo]::new()

        # set default port
        if ( $PSBoundParameters.Keys -contains 'Protocol' -and $PSBoundParameters.Keys -notcontains 'Port' ) {

            $PSBoundParameters.Port = switch ( $PSBoundParameters.Protocol ) {
            
                'RDP'     { 3389 }
                'VNC'     { 5900 }
                'SSH1'    {   22 }
                'SSH2'    {   22 }
                'Telnet'  {   23 }
                'Rlogin'  {  513 }
                'RAW'     {   23 }
                'HTTP'    {   80 }
                'HTTPS'   {  443 }
                'IntApp'  {    0 }
            
            }
        
        }
        
        # set connection properties
        $PSBoundParameters.Keys |
            Where-Object { $_ -notmatch 'Parent|Inheritance' } |
            Where-Object { [mRemoteNG.Connection.ConnectionInfo].GetProperties().Name -contains $_ } |
            ForEach-Object { $ConnectionInfo.$_ = $PSBoundParameters.$_ }

        # configure inheritance
        if ( $PSBoundParameters.Keys -contains 'Inheritance' ) {
        
            # process EverythingInherited first
            if ( $PSBoundParameters.Inheritance.Keys -contains 'EverythingInherited' ) {

                $ConnectionInfo.Inheritance.EverythingInherited = $true

            }

            # process all other inheritence
            $PSBoundParameters.Inheritance.Keys |
                Where-Object { $_ -ne 'EverythingInherited' } |
                ForEach-Object {

                    $ConnectionInfo.Inheritance.$_ = $PSBoundParameters.Inheritance.$_

                }
        
        }

        # if parent is specified we append, otherwise we output
        if ( $PSBoundParameters.Keys -contains 'Parent' ) {

            $PSBoundParameters.Parent.AddChild( $ConnectionInfo )

            Write-Verbose ( 'Connection ''{0}'' added to ''{1}''.' -f $ConnectionInfo.Name, $PSBoundParameters.Parent.Name )

        }
        
        $ConnectionInfo

    }

}

<#
.SYNOPSIS
 Helper function to build an inheritance configuration.

.EXAMPLE
 New-MRNGInheritanceConfiguration -EverythingInherited -Icon:$false
 # inherits everything except the icon

#>
function New-MRNGInheritanceConfiguration {

    [OutputType([hashtable])]
    [CmdletBinding()]
    param()

    dynamicparam {

        $DPDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        [mRemoteNG.Connection.ConnectionInfoInheritance].GetProperties() |
        Where-Object { $_.Name -ne 'Parent' } |
            ForEach-Object {

                $Attribute = New-Object System.Management.Automation.ParameterAttribute
                $Attribute.ParameterSetName  = '__AllParameterSets'
                $Collection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                $Collection.Add($Attribute)
                $Parameter = New-Object System.Management.Automation.RuntimeDefinedParameter( $_.Name, [switch], $Collection )
                $DPDictionary.Add( $_.Name, $Parameter )
                
            }
            
        return $DPDictionary
    }

    process {

        $ReturnHashtable = @{}
        
        $PSBoundParameters.Keys |
            Where-Object { [mRemoteNG.Connection.ConnectionInfoInheritance].GetProperties().Name -contains $_ } |
            ForEach-Object { $ReturnHashtable.$_ = $PSBoundParameters.$_ }

        $ReturnHashtable

    }

}

<#
.SYNOPSIS
 Exports the mRemoteNG connection file with the encryption parameters specified.

.PARAMETER RootNode
 The mRemoteNG root connections node generated by New-MRNGRootNode.

.PARAMETER Path
 The path to export the connection file to.

.PARAMETER EncryptionKey
 The encryption key to use to secure the connections file. If no password is supplied the default mRemoteNG encryption key is "mR3m".

.PARAMETER EncryptionEngine
 The encryption engine to use when encrypting the connection passwords. Choices are 'AES', 'Serpent', and 'Twofish'. The default is 'AES'.

.PARAMETER BlockCipherMode
 The block cipher mode to use when encrypting the connection passwords. Choices are 'GCM', 'CCM', and 'EAX'. The default is 'GCM'.

.PARAMETER KeyDerivationIterations
 The number of key derivation iterations to perform when encrypting the connection passwords. Valid values are in the range 1,000 to 50,000.

.PARAMETER SortConnections
 Should the exported connections be sorted?

.EXAMPLE
 Export-MRNGConnectionFile -RootNode $RootNode -Path .\Connections.xml (Get-Credential).Password -SortConnections

#>
function Export-MRNGConnectionFile {

    [OutputType([void])]
    param(

        [Parameter(Mandatory)]
        [mRemoteNG.Tree.Root.RootNodeInfo]
        $RootNode,

        [Parameter(Mandatory)]
        [System.IO.FileInfo]
        $Path,

        [ValidateSet('AES', 'Serpent', 'Twofish')]
        [string]
        $EncryptionEngine = 'AES',

        [ValidateSet('GCM', 'CCM', 'EAX')]
        [string]
        $BlockCipherMode = 'GCM',

        [ValidateRange(1000, 50000)]
        [int]
        $KeyDerivationIterations = 1000,

        [switch]
        $SortConnections

    )

    # resolve the path
    $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath( $Path )

    # get the encryption key as [securestring]
    if ( $RootNode.Password ) {

        $EncryptionKey = $RootNode.PasswordString |
            ConvertTo-SecureString -AsPlainText -Force

    } else {

        $EncryptionKey = $RootNode.DefaultPassword |
            ConvertTo-SecureString -AsPlainText -Force

    }

    # choose the encryption engine
    $Engine = switch ( $EncryptionEngine ) {

        'AES'     { [Org.BouncyCastle.Crypto.Engines.AesEngine]::new() }
        'Serpent' { [Org.BouncyCastle.Crypto.Engines.SerpentEngine]::new() }
        'Twofish' { [Org.BouncyCastle.Crypto.Engines.TwofishEngine]::new() }

    }

    # choose the cipher mode
    $Cipher = switch ( $BlockCipherMode ) {

        'GCM' { [Org.BouncyCastle.Crypto.Modes.GcmBlockCipher]::new( $Engine ) }
        'CCM' { [Org.BouncyCastle.Crypto.Modes.CcmBlockCipher]::new( $Engine ) }
        'EAX' { [Org.BouncyCastle.Crypto.Modes.EaxBlockCipher]::new( $Engine ) }

    }

    # XML serializer
    $CryptoProvider = [mRemoteNG.Security.SymmetricEncryption.AeadCryptographyProvider]::new( $Cipher )
    $SaveFilter = [mRemoteNG.Security.SaveFilter]::new()
    $ConnectionNodeSerializer = [mRemoteNG.Config.Serializers.Xml.XmlConnectionNodeSerializer26]::new($CryptoProvider, $EncryptionKey, $SaveFilter)
    $XmlSerializer = [mRemoteNG.Config.Serializers.Xml.XmlConnectionsSerializer]::new($CryptoProvider, $ConnectionNodeSerializer)

    # should we sort?
    if ( $SortConnections ) {

        $RootNode.SortRecursive()

    }

    # save the connection file
    $FilePathProvider = [mRemoteNG.Config.DataProviders.FileDataProvider]::new( $Path )
    $FilePathProvider.Save( $XmlSerializer.Serialize( $RootNode ) )

}

<#
.SYNOPSIS
 Convert a mRemoteNG secure string to plain text.

.PARAMETER EncryptedMessage
 The mRemoteNG secure string to be converted.

.PARAMETER EncryptionKey
 The encryption key that was used when encrypting the ConfCons.xml file. If no password is supplied the default mRemoteNG encryption key is "mR3m".

.PARAMETER EncryptionEngine
 The encryption engine to use when decrypting the string. Choices are 'AES', 'Serpent', and 'Twofish'. The default is 'AES'.

.PARAMETER BlockCipherMode
 The block cipher mode to use when decrypting the string. Choices are 'GCM', 'CCM', and 'EAX'. The default is 'GCM'.

.PARAMETER KeyDerivationIterations
 The number of key derivation iterations to perform when decrypting the string. Valid values are in the range 1,000 to 50,000.

.EXAMPLE
 ConvertFrom-MRNGSecureString -EncryptedMessage 'pLs5zen+UvaqFnn2KDn2eTrhO60gjzagqFnI/8n3dF74zCj9lZDGvR1nJ8bxf5OCuHJW8gcWFWOicNIvV4h1'

.EXAMPLE
 ConvertFrom-MRNGSecureString -EncryptedMessage 'LkJUc6Q60hsZmX6QImOS+1nvFYQLNNCfP7iEupby8Ey84Dz+3u7lRo93YaL6fJf2GCXOtpXtzgZACxhVKcJh' -EncryptionEngine Serpent -BlockCipherMode EAX

.EXAMPLE
 ConvertFrom-MRNGSecureString -EncryptedMessage 'MqE3IQxYiLioTaD86rzRusDmiD2nX2b9uabDASZdRB9+gk7ygLWSqYFVEg5zqa65qe6j3ZPtgeLxKNZiIoGv' -EncryptionKey ( 'password' | ConvertTo-SecureString -AsPlainText -Force )

#>
function ConvertFrom-MRNGSecureString {

    [OutputType([string])]
    param(

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $EncryptedMessage,

        [ValidateNotNullOrEmpty()]
        [securestring]
        $EncryptionKey = ( ConvertTo-SecureString -String 'mR3m' -AsPlainText -Force ),

        [ValidateSet('AES', 'Serpent', 'Twofish')]
        [string]
        $EncryptionEngine = 'AES',

        [ValidateSet('GCM', 'CCM', 'EAX')]
        [string]
        $BlockCipherMode = 'GCM',

        [ValidateRange(1000, 50000)]
        [int]
        $KeyDerivationIterations = 1000

    )

    # choose the text encoding
    $Encoding = [System.Text.Encoding]::UTF8

    # convert the $EncryptionKey to plain text
    $EncryptionKeyBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $EncryptionKey )
    $EncryptionKeyText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto( $EncryptionKeyBSTR )
    $EncryptionKeyBytes = [Org.BouncyCastle.Crypto.PbeParametersGenerator]::Pkcs5PasswordToBytes( [char[]]$EncryptionKeyText )
    
    # convert the base64 encoded string to a byte array
    $EncryptedMessageBytes = [convert]::FromBase64String( $EncryptedMessage )

    # choose the encryption engine
    $Engine = switch ( $EncryptionEngine ) {

        'AES'     { [Org.BouncyCastle.Crypto.Engines.AesEngine]::new() }
        'Serpent' { [Org.BouncyCastle.Crypto.Engines.SerpentEngine]::new() }
        'Twofish' { [Org.BouncyCastle.Crypto.Engines.TwofishEngine]::new() }

    }

    # choose the cipher mode
    $Cipher = switch ( $BlockCipherMode ) {

        'GCM' { [Org.BouncyCastle.Crypto.Modes.GcmBlockCipher]::new( $Engine ) }
        'CCM' { [Org.BouncyCastle.Crypto.Modes.CcmBlockCipher]::new( $Engine ) }
        'EAX' { [Org.BouncyCastle.Crypto.Modes.EaxBlockCipher]::new( $Engine ) }

    }

    # generate a new random string
    $SecureRandom = [Org.BouncyCastle.Security.SecureRandom]::new()
    
    # defaults from mRemoteNG source
    $NonceBitSize = 128
    $MacBitSize   = 128
    $KeyBitSize   = 256
    $SaltBitSize  = 128
    $MinPasswordLength = 1

    # get the salt
    $Salt = New-Object byte[] ( $SaltBitSize/8 )
    [array]::Copy( $EncryptedMessageBytes, 0, $Salt,  0, $Salt.Length )

    # get the key
    $KeyGenerator = [Org.BouncyCastle.Crypto.Generators.Pkcs5S2ParametersGenerator]::new()
    $KeyGenerator.Init( $EncryptionKeyBytes, $Salt, $KeyDerivationIterations )
    $KeyParameter = $KeyGenerator.GenerateDerivedMacParameters($KeyBitSize)
    $KeyBytes = $KeyParameter.GetKey()

    # create the cipher reader
    $CipherStream = New-Object System.IO.MemoryStream (, $EncryptedMessageBytes )
    $CipherReader = New-Object System.IO.BinaryReader ( $CipherStream )

    # get the payload
    $Payload = $CipherReader.ReadBytes( $Salt.Length )

    # get the nonce
    $Nonce = $CipherReader.ReadBytes( $NonceBitSize / 8 )

    # build the decryption parameters
    $Parameters = [Org.BouncyCastle.Crypto.Parameters.AeadParameters]::new( $KeyParameter, $MacBitSize, $Nonce, $Payload )

    # initialize the Cipher
    $Cipher.Init( $false, $Parameters )

    # get the cipher text
    $CipherTextBytes = $CipherReader.ReadBytes( $EncryptedMessageBytes.Length - $Nonce.Length )

    # read the decoded text byte array
    $PlainTextByteArray = New-Object byte[] ( $Cipher.GetOutputSize( $CipherTextBytes.Length ) )

    # get the length of the decoded string
    $Len = $Cipher.ProcessBytes( $CipherTextBytes, 0, $CipherTextBytes.Length, $PlainTextByteArray, 0 )

    # do finial decryption
    $Cipher.DoFinal( $PlainTextByteArray, $Len ) > $null

    # output UTF8 encoded string
    $Encoding.GetString( $PlainTextByteArray )

}

<#
.SYNOPSIS
 Convert a plain text string to a mRemoteNG secure string.

.PARAMETER Message
 The string to be converted.

.PARAMETER EncryptionKey
 The encryption key to use when encrypting the string. It should match what you are using in your ConfCons.xml file. If no password is supplied the default mRemoteNG encryption key is "mR3m".

.PARAMETER EncryptionEngine
 The encryption engine to use when encrypting the string. Choices are 'AES', 'Serpent', and 'Twofish'. The default is 'AES'.

.PARAMETER BlockCipherMode
 The block cipher mode to use when encrypting the string. Choices are 'GCM', 'CCM', and 'EAX'. The default is 'GCM'.

.PARAMETER KeyDerivationIterations
 The number of key derivation iterations to perform when encrypting the string. Valid values are in the range 1,000 to 50,000.

.EXAMPLE
 ConvertTo-MRNGSecureString -Message 'SecureP@ssword!'

.EXAMPLE
 ConvertTo-MRNGSecureString -Message 'SecureP@ssword!' -EncryptionEngine Serpent -BlockCipherMode EAX

.EXAMPLE
 ConvertTo-MRNGSecureString -Message 'SecureP@ssword!' -EncryptionKey ( 'password' | ConvertTo-SecureString -AsPlainText -Force )

#>
function ConvertTo-MRNGSecureString {

    [OutputType([string])]
    param(

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Message,

        [ValidateNotNullOrEmpty()]
        [securestring]
        $EncryptionKey = ( ConvertTo-SecureString -String 'mR3m' -AsPlainText -Force ),

        [ValidateSet('AES', 'Serpent', 'Twofish')]
        [string]
        $EncryptionEngine = 'AES',

        [ValidateSet('GCM', 'CCM', 'EAX')]
        [string]
        $BlockCipherMode = 'GCM',

        [ValidateRange(1000, 50000)]
        [int]
        $KeyDerivationIterations = 1000

    )

    # choose the text encoding
    $Encoding = [System.Text.Encoding]::UTF8

    # convert the $EncryptionKey to plain text
    $EncryptionKeyBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR( $EncryptionKey )
    $EncryptionKeyText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto( $EncryptionKeyBSTR )
    $EncryptionKeyBytes = [Org.BouncyCastle.Crypto.PbeParametersGenerator]::Pkcs5PasswordToBytes( [char[]]$EncryptionKeyText )

    # convert message to byte array
    $MessageBytes = $Encoding.GetBytes($Message)

    # choose the encryption engine
    $Engine = switch ( $EncryptionEngine ) {

        'AES'     { [Org.BouncyCastle.Crypto.Engines.AesEngine]::new() }
        'Serpent' { [Org.BouncyCastle.Crypto.Engines.SerpentEngine]::new() }
        'Twofish' { [Org.BouncyCastle.Crypto.Engines.TwofishEngine]::new() }

    }

    # choose the cipher mode
    $Cipher = switch ( $BlockCipherMode ) {

        'GCM' { [Org.BouncyCastle.Crypto.Modes.GcmBlockCipher]::new( $Engine ) }
        'CCM' { [Org.BouncyCastle.Crypto.Modes.CcmBlockCipher]::new( $Engine ) }
        'EAX' { [Org.BouncyCastle.Crypto.Modes.EaxBlockCipher]::new( $Engine ) }

    }

    # generate a new random string
    $SecureRandom = [Org.BouncyCastle.Security.SecureRandom]::new()
    
    # defaults from mRemoteNG source
    $NonceBitSize = 128
    $MacBitSize   = 128
    $KeyBitSize   = 256
    $SaltBitSize  = 128
    $MinPasswordLength = 1

    # create the salt
    $Salt = New-Object byte[] ( $SaltBitSize/8 )
    $SecureRandom.NextBytes($Salt)

    # create the key
    $KeyGenerator = [Org.BouncyCastle.Crypto.Generators.Pkcs5S2ParametersGenerator]::new()
    $KeyGenerator.Init( $EncryptionKeyBytes, $Salt, $KeyDerivationIterations )
    $KeyParameter = $KeyGenerator.GenerateDerivedMacParameters($KeyBitSize)
    $KeyBytes = $KeyParameter.GetKey()

    # create the payload and add the salt
    $Payload = New-Object byte[] ( $Salt.Length )
    [array]::Copy( $Salt, 0, $Payload, 0, $Salt.Length )

    # create the nonce
    $Nonce = New-Object byte[] ( $NonceBitSize / 8 )
    $SecureRandom.NextBytes( $Nonce, 0, $Nonce.Length )

    # build the encryption parameters
    $Parameters = [Org.BouncyCastle.Crypto.Parameters.AeadParameters]::new( $KeyParameter, $MacBitSize, $Nonce, $Payload )

    # initialize the cipher
    $Cipher.Init( $true, $Parameters )

    # encrypt the message
    $CipherText = New-Object byte[] ($Cipher.GetOutputSize( $MessageBytes.Length ))
    $Len = $Cipher.ProcessBytes( $MessageBytes, 0, $MessageBytes.Length, $CipherText, 0 )
    $Cipher.DoFinal( $CipherText, $Len ) > $null

    # create a binary stream
    $CombinedStream = New-Object System.IO.MemoryStream
    $BinaryWriter = New-Object System.IO.BinaryWriter ( $CombinedStream )

    # write the payload, nonce, and cipher to the binary stream
    $BinaryWriter.Write( $Payload )
    $BinaryWriter.Write( $Nonce )
    $BinaryWriter.Write( $CipherText )

    # convert the binary stream to a base64 encoded string
    [convert]::ToBase64String( $CombinedStream.ToArray() )

}

