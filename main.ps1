$WebClient = New-Object System.Net.WebClient
[System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("cp866")
$GB = "4"

 if(!(Test-Path "launcher_profiles.json" -PathType Leaf)){
        '{"Nick":"Tempo","profiles":{}}' | Out-File "launcher_profiles.json"
}

function test{
    $APATH = "assets\indexes\1.12.json"
    Write-Host $APATH
    
    $assets = (jsonFromFile -PATH $APATH)
    $sass = $assets.objects | Get-Member -MemberType NoteProperty
    Write-Host ($sass.Length)
}

function run {
    $launcher_profiles = jsonFromFile -PATH "launcher_profiles.json"
    $nick = $launcher_profiles.nick
    Clear-Host
    Write-Host "-----------------------------------------------------------------------"
    Write-Host "                   select number                                       "
    Write-Host "1) Set nick     2) Start version    3)Download version       4)Set GB  "
    $selected = Read-Host "Selected key"
    switch ($selected) {
        1 { 
            $nick = Read-Host "Nick"
            $launcher_profiles.nick = $nick
            $launcher_profiles | ConvertTo-Json -depth 100 | Out-File "launcher_profiles.json"
            run
         }
        2 {
            Write-Host "------------------------Version-------------------------"
            $i = 0
            $outItems = New-Object System.Collections.Generic.List[System.Object]
            $launcher_profiles.profiles | Get-Member -MemberType NoteProperty | ForEach-Object {
                $key = $_.Name
                $version = $launcher_profiles.profiles.$key
                $outItems.Add($version.name)
                Write-Host ([string]$i+"|"+$version.name)
                $i++
            }
            Write-Host "--------------------------------------------------------"
            $selected = Read-Host "Selected version"
            startMine -version ($selected) -nick $nick
        } 
        3 {
            $i=0
            $jsonic = jsonFromUrl -url https://launchermeta.mojang.com/mc/game/version_manifest.json
            Write-Host "------------------------Version-------------------------"
            foreach($ver in $jsonic.versions){
                Write-Host ([string]$i + "|" + $ver.id)
                $i++
                if($i%20 -eq 0){
                    $sel = Read-Host("Continue?y,n")
                    if($sel -eq  "n"){
                        break
                    }
                }
                
            }
            Write-Host "--------------------------------------------------------"
            $sel = Read-Host("Version?")
            startMine -version ($sel) -nick $nick
        }
        4 {
            $GB = Read-Host("Memory&1 2 3 (in GB)")

        }
        Default {}
    }
    ## startMine -version "1.12.2" -nick $nick

   

}

function startMine {
    param (
        $version,
        $nick
    )
    Write-Debug $nick
    $json = ReadJsonMine -version $version
    $out = (init -json $json -nick $nick)
    $JAVAPATHBIN = ""
    try {
        Write-Host(java.exe -version)
    }
    catch {
        $JAVAPATHBIN = DownloadJava -version $json.javaVersion.majorVersion
    }
    Clear-Host
    $vsq = [string]$JAVAPATHBIN+$out
    # Write-Host $vsq
    # cmd /c $vsq
    $vsq | Out-File -FilePath "./start.cmd" -Encoding oem
}

function DownloadJava {
    param (
        $version
    )
    $url
    $path
    switch ($version) {
        8 { 
            $url="https://download.bell-sw.com/java/8u332+9/bellsoft-jre8u332+9-windows-amd64.zip" 
            $path = "jre8u332"
        }
        17 {
            $url="https://download.java.net/java/GA/jdk17.0.2/dfd4a8d0985749f896bed50d7138ee7f/8/GPL/openjdk-17.0.2_windows-x64_bin.zip"
            $path = "jdk-17.0.2"
        }
        Default {
            $url="https://download.bell-sw.com/java/8u332+9/bellsoft-jre8u332+9-windows-amd64.zip" 
            $path = "jre8u332"
        }
    }
    $DPATH = "java\"+$path+"\"
    if(!(Test-Path $DPATH)){
        New-Item -Path "java\a.zip" -ItemType File -Force
        Write-Host "Download java"
        $WebClient.DownloadFile($url,"java\a.zip")
        Write-Host "Done"
        [System.IO.Compression.ZipFile]::ExtractToDirectory("java\a.zip","java\")
    }
    return "java\"+$path+"\bin\"
}
function ReadJsonMine {
    param (
        $version
    )
    $launcher_profiles = jsonFromFile -PATH "launcher_profiles.json"

    $jsonym
    if(!($launcher_profiles.profiles.$version)){
        $DBPATH = "versions\"+$version+"\"+$version+".json"
        if((Test-Path $DBPATH -PathType Leaf)){
            $jsonym = jsonFromFile -PATH $DBPATH
            $bcg = [PSCustomObject]@{
                lastVersionId = $jsonym.id
                name = $jsonym.id
            }
            $launcher_profiles.profiles | Add-Member -MemberType NoteProperty -Name $version -Value $bcg
            $launcher_profiles | ConvertTo-Json -depth 100 | Out-File "launcher_profiles1.json"
        }else{
            $url = getUrl -version $version
            if($url -eq "nil"){return "Version not found!"}
            $jsonym = jsonFromUrl -url $url
            $bcg = [PSCustomObject]@{
                lastVersionId = $jsonym.id
                name = $jsonym.id
            }
            $launcher_profiles.profiles | Add-Member -MemberType NoteProperty -Name $version -Value $bcg
            $launcher_profiles | ConvertTo-Json -depth 100 | Out-File "launcher_profiles.json"
        }
    }else{
        $vid = $launcher_profiles.profiles.$version.lastVersionId
        $jsonym = jsonFromFile -PATH ("versions\" + $vid + "\" + $vid + ".json")
    }
    if($null -ne $jsonym.inheritsFrom){
        $mjson = (ReadJsonMine -version $jsonym.inheritsFrom)[1]
        if($mjson -eq "Version not found!"){return "Version not found!"}
        $tmsq = init -json $mjson -nick "nil"
        $mjson.id = $jsonym.id
        $mjson.mainClass = $jsonym.mainClass
        $mjson.minecraftArguments = $jsonym.minecraftArguments
        $mjson.libraries = $mjson.libraries + $jsonym.libraries
        $jsonym = $mjson
    }

    return $jsonym
}
function init {
    param (
        $json,$nick
    )
    if($json -eq "Version not found!"){
        return "echo Not found!"
    }
    $ch = 0;
    $libarg = ""
    foreach($lib in $json.libraries){
        $PATH = ""
        $URL = ""
        $MPath = (Get-Location).path
        $IsNative = $false
        if($lib.downloads){
            if($lib.downloads.artifact){
                $PATH = "libraries\"+$lib.downloads.artifact.path
                $URL = $lib.downloads.artifact.url
            }
            if($lib.downloads.classifiers -and $lib.downloads.classifiers.'natives-windows'){
                $PATH = "libraries\"+$lib.downloads.classifiers.'natives-windows'.path
                $URL = $lib.downloads.classifiers.'natives-windows'.url
                $IsNative = $true
            }
        }else{
            if($lib.url){
                $splited = $lib.name -split ":"
                $PATH = "libraries\" + ($splited[0] -replace ".","\") + "\" + $splited[1] + "\" + $splited[2] + "\" + $splited[1] + "-" + $splited[2] + ".jar"
                $URL = $lib.url + ($splited[0] -replace ".","/") + "/" + $splited[1] + "/" + $splited[2] + "/" + $splited[1] + "-" + $splited[2] + ".jar"
            }
        }
        if(!(Test-Path $PATH -PathType Leaf)){
            New-Item -Path $PATH -ItemType File -Force
            $WebClient.DownloadFile($URL,$PATH)
        }
        Clear-Host
        Write-Host "--------------------------------------------"
        Write-Host $URL
        Write-Host $PATH
        Write-Host "--------------------------------------------"
        $load = "["
        for($i=1;$i -lt 44;$i++){
            $sat = ($ch/$json.libraries.Length)*44
            if($sat -lt $i){
                $load = $load + " "
            }else {
                $load = $load + "="
            }
        }
        Write-Host ($load+"]")

        if($IsNative -and !(Test-Path ("versions\"+$json.id+"\natives\") -PathType Leaf)){
            [System.IO.Compression.ZipFile]::ExtractToDirectory($PATH,"versions\"+$json.id+"\natives\")
        }
        $libarg = $libarg + $MPath+"\"+$PATH + ";"
        $ch++
    }

    $APATH = "assets\indexes\"+$json.assetIndex.id+".json"
    Write-Host $APATH
    if(!(Test-Path $APATH -PathType Leaf)){
        New-Item -Path $APATH -ItemType File -Force
        $WebClient.DownloadFile($json.assetIndex.url,$APATH)
    }
    $assets = (jsonFromFile -PATH $APATH)
    $arrassets = $assets.objects | Get-Member -MemberType NoteProperty
    $ch = 0
    $arrassets | ForEach-Object {
        $key = $_.Name
        $hash = $assets.objects.$key.hash
        $PATHASH = $hash.ToCharArray()[0]+$hash.ToCharArray()[1]+"/"+$hash
        $URL = "https://resources.download.minecraft.net/" + $PATHASH
        $PATH = "assets\objects\"+$PATHASH
        if(!(Test-Path $PATH -PathType Leaf)){
            Clear-Host
            Write-Host "--------------------------------------------"
            Write-Host $URL
            Write-Host $PATH
            Write-Host "--------------------------------------------"
            $load = "["
            for ($i = 1; $i -lt 44; $i++) {
                $sat = ($ch / $arrassets.Length) * 44
                if ($sat -lt $i) {
                    $load = $load + " "
                }
                else {
                    $load = $load + "="
                }
            }
            Write-Host ($load + "]")
            New-Item -Path $PATH -ItemType File -Force
            $WebClient.DownloadFile($URL,$PATH)
        }
        $ch++
    }

    $clientpath = "versions\"+ $json.id + "\" + $json.id +".jar"
    Write-Host $clientpath
    if(!(Test-Path $clientpath -PathType Leaf)){
        New-Item -Path $clientpath -ItemType File -Force
        Clear-Host
        Write-Host "Download client"
        $WebClient.DownloadFile($json.downloads.client.url,$clientpath)
    }
    
    $json | ConvertTo-Json -depth 100 | Out-File ("versions\" + $json.id + "\" + $json.id + ".json")

    $libarg = $libarg + $MPath+'\'+$clientpath
    $args = $json.minecraftArguments
    if(!$args){
        $args = "";
        foreach($ar in $json.arguments.game){
            if($ar.GetType().Name -eq "String"){
                $args = $args + $ar + " "
            }
        }
    }
    $args = $args.Replace('${auth_player_name}',$nick)
    $args = $args.Replace('${version_name}',$json.id)
    $args = $args.Replace('${game_directory}',"./")
    $args = $args.Replace('${assets_root}',$MPath+"\assets")
    $args = $args.Replace('${assets_index_name}',$json.assetIndex.id)
    $args = $args.Replace('${auth_uuid}',"123456789123456789123456789")
    $args = $args.Replace('${auth_access_token}',"123456789123456789123456789")
    $args = $args.Replace('${user_type}',"mojang")
    $args = $args.Replace('--versionType ${version_type}','');
    
    
    $out = 'java -Xmx' + $GB +'G -Djava.library.path="'+$MPath+"\versions\" + $json.id + '\natives" -cp "' + $libarg.Replace("/","\") + '" ' + $json.mainClass + ' ' + $args
    return $out
}
function getUrl {
    param (
        $version
    )
    $json = jsonFromUrl -url https://launchermeta.mojang.com/mc/game/version_manifest.json
    foreach($ver in $json.versions){
        if($ver.id -eq $version){
            return $ver.url
        }
    }
    return "nil"

}
function jsonFromFile {
    param (
        $PATH
    )
    return (Get-Content -Raw -Path $PATH | ConvertFrom-Json)
    
}
function jsonFromUrl {
    param (
        $url
    )
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing
    return (ConvertFrom-Json -InputObject $response.Content)
}
run
#test
