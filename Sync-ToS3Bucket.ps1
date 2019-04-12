

Function Sync-ToS3Bucket {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,Position=1)]
        [string]$BucketName,
        [Parameter(Mandatory=$True,Position=2)]
        [string]$LocalFolderPath,
        [string]$S3DestinationFolder,
        [string]$ProfileName,
        [switch]$ShowProgress

    )

    Function WriteInfo ($msg) {
        Write-Host "[$(get-date)]:: $msg"
    }

    Function WriteAction ($msg) {
        Write-Host "[$(get-date)]:: $msg" -ForegroundColor Cyan
    }

    Function WriteWarning ($msg) {
        Write-Host "[$(get-date)]:: $msg" -ForegroundColor Yellow
    }

    Function WriteError ($msg) {
        Write-Host "[$(get-date)]:: $msg" -ForegroundColor Red
    }

    Function WriteLabel ($msg) {
        "`n`n`n"
        Write-Host ("*" * ("[$(get-date)]:: $msg").Length)
        $msg
        Write-Host( "*" * ("[$(get-date)]:: $msg").Length)
    }

    function Calculate-TransferSpeed ($size, $eTime) {
        writeInfo "Total Data: $size bytes, Total Time: $eTime seconds"
        if ($size -ge "1000000") {

            WriteInfo ("Upload speed         : " + [math]::round($($size / 1MB)/$eTime, 2) + " MB/Sec")
        }
        Elseif ($size -ge "1000" -and $size -lt "1000000" ) {

            WriteInfo ("Upload speed         : " + [math]::round($($size / 1kb)/$eTime,2)+ " KB/Sec")
        }
        Else {
            if ($size -ne $null -and $size) {
                WriteInfo ("Upload speed         : " + [math]::round($ssize/$eTime,2) + " Bytes/Sec")
            }
            else {
                WriteInfo ("Upload speed         : 0 Bytes/Sec")

            }
        }
    }

    function Get-ItemSize ($size, $msg) {
        if ($size -ge "1000000000") {
            WriteInfo "Upload $msg Size   : $([math]::round($($size /1gb),2)) GB"

        }
        Elseif ($size -ge "1000000" -and $size -lt "1000000000" ) {
            WriteInfo "Upload $msg Size   : $([math]::round($($size / 1MB),2)) MB"

        }
        Elseif ($size -ge "1000" -and $size -lt "1000000" )  {
            WriteInfo "Upload $msg Size   : $([math]::round($($size / 1kb),2)) KB"

        }
        Else {
            if ($size -ne $null -and $size) {
                WriteInfo "Upload $msg Size   : $([string]$size) Bytes"
            }

            else {
                WriteInfo "Upload $msg Size   : 0 Bytes"

            }
        }
    }


    "`n`n`n`n`n`n`n`n`n`n"
    $OstartTime = get-date

    if ($LocalFolderPath -eq $null -or !$LocalFolderPath) {
        $LocalFolderPath =  "."
    }
    Elseif ($LocalFolderPath.Substring($LocalFolderPath.Length -1) -eq '\') {
        #$LocalFolderPath =  $LocalFolderPath + '\'
        $LocalFolderPath =  $Localfolderpath.Substring(0,$Localfolderpath.Length -1)
    }

    if ($S3DestinationFolder -eq $null -or !$S3DestinationFolder) {
       
    }
    elseif ($S3DestinationFolder.Substring($S3DestinationFolder.Length -1) -eq '\') {
        #$LocalFolderPath =  $LocalFolderPath + '\'
        $S3DestinationFolder =  $S3DestinationFolder.Substring(0,$S3DestinationFolder.Length -1)
    }

    $OrignatingFolder = $PWD.Path

    set-location $LocalFolderPath
    $LocalFolderPath = $PWD.Path

    Start-Transcript "AWS-S3Upload.log" -Append
    "`n`n`n`n`n`n`n`n`n`n"
    WriteLabel "Script start time: $OstartTime"

    WriteAction "Getting sub directories to create in S3"
    $Folders = Get-ChildItem -Path $LocalFolderPath -Directory -Recurse -Force | select FullName

    WriteAction "Getting list of all files to upload to S3"
    $allFiles = Get-ChildItem -Path $LocalFolderPath -File -Recurse -Force | select FullName

    WriteAction "Getting folder count"
    $FoldersCount = $Folders.count
    
    WriteAction "Getting file count"
    $allFilesCount = $allFiles.count


    $i = 0
    
    try {
    
        foreach ($Folder in $Folders.fullname) {


            $UploadFolder = $Folder.Substring($LocalFolderPath.length + 1)
            $Source  = $Folder
       
            $Destination = $S3DestinationFolder + $UploadFolder
         

        
            if ($ShowProgress) {
                $i++
                $Percent = [math]::Round($($($i/$FoldersCount*100)))
                Write-Progress -Activity "Processing folder: $i out of $FoldersCount" -Status "Overall Upload Progress: $Percent`%     ||     Current Upload Folder Name: $UploadFolder" -PercentComplete $Percent
            }

            "`n`n"
        
            "_" * $("[$(get-date)]:: Local Folder Name    : $UploadFolder".Length)
        
            WriteInfo "Local Folder Name    : $UploadFolder"
            WriteInfo "S3 Folder path       : $Destination"

            WriteAction "Getting the folder size"
        
            $Files = Get-ChildItem -Force -File -Path $Source | Measure-Object -sum Length

            Get-ItemSize $Files.sum "Folder"

      

                if ((Get-S3Object -BucketName $BucketName -KeyPrefix $Destination -MaxKey 1 -ProfileName $ProfileName).count -eq 0) {

                    WriteAction "Folder does not exist"
                    WriteAction "Uploading all files"


                    WriteInfo ("Upload File Count    : " + $files.count)

                    $startTime = get-datey
                    WriteInfo "Upload Start Time    : $startTime"
                    Write-S3Object -BucketName $BucketName -KeyPrefix $Destination -Folder $Source -ProfileName $ProfileName -Verbose -ConcurrentServiceRequest 100

                    $stopTime = get-date
                    WriteInfo "Upload Finished Time : $stopTime"

                    $elapsedTime = $stopTime - $StartTime
                    WriteInfo ("Time Elapsed         : " + $elapsedTime.days + " Days, " + $elapsedTime.hours + " Hours, "  + $elapsedTime.minutes + " Minutes, " + $elapsedTime.seconds+ " Seconds")

                    Calculate-TransferSpeed $files.Sum $elapsedTime.TotalSeconds

                    #sleep 10
                }
                else {
                    WriteAction "Getting list of local files in local folder to transfer"
                    $fFiles = Get-ChildItem -Force -File -Path $Source

                    WriteAction "Counting files"
                    $fFilescount = $ffiles.count
                    WriteInfo "Upload File Count    : $fFilescount"
                    $j = 0
                    foreach ($fFile in $fFiles) {

                        if ($ShowProgress) {
                            $j++
                            $fPercent = [math]::Round($($($j/$fFilescount*100)))
                            Write-Progress -Activity "Processing File: $j out of $fFilescount" -Id 1 -Status "Current Progress: $fPercent`%           ||     Processing File: $ffile" -PercentComplete $fPercent
                        }
                        #WriteAction "Getting S3 bucket objects"

                        $S3file = Get-S3Object -BucketName $BucketName -Key "$Destination\$ffile" -ProfileName $ProfileName
                        $s3obj = $S3file.key -replace "/","\"

                        if ("$S3DestinationFolder$UploadFolder\$ffile" -eq $s3obj -and $S3file.size -ge $ffile.Length) {
                            WriteWarning "File exists          : $s3obj"

                        }
                        else {

                            WriteAction  "Uploading file       : $ffile"

                            Get-ItemSize $fFile.Length "File"
                            $startTime = get-date
                            WriteInfo   "Upload Start Time    : $startTime"

                            Write-S3Object -BucketName $BucketName -File $fFile.fullname -Key "$Destination\$fFile" -ConcurrentServiceRequest 100  -ProfileName $ProfileName -Verbose

                            $stopTime = get-date
                            WriteInfo "Upload Finished Time : $stopTime"

                            $elapsedTime = $stopTime - $StartTime

                            WriteInfo ("Time Elapsed         : " + $elapsedTime.days + " Days, " + $elapsedTime.hours + " Hours, "  + $elapsedTime.minutes + " Minutes, " + $elapsedTime.seconds+ " Seconds")
                            Calculate-TransferSpeed $fFile.Length $elapsedTime.TotalSeconds
                            break

                        }

                    }

                }


        
         



        }
    
    }
        
    catch {

        "-" * $("[$(get-date)]:: Following Error Occured".Length)

        WriteError "Following Error Occured"

        "-" * $("[$(get-date)]:: Following Error Occured".Length)
        
        "!" * $("[$(get-date)]:: Following Error Occured".Length)

        Write-Error $Error[0]
       
        "!" * $("[$(get-date)]:: Following Error Occured".Length)

    }

    Finally {
        $OstopTime = get-date
        "`n`n"
        "-" * "Script Finished Time : $OstopTime".Length
        "Script Finished Time : $OstopTime"

        $elapsedTime = $OstopTime - $OStartTime

        "Time Elapsed         : " + $elapsedTime.days + " Days, " + $elapsedTime.hours + " Hours, "  + $elapsedTime.minutes + " Minutes, " + $elapsedTime.seconds+ " Seconds"

        stop-transcript
        set-location $OrignatingFolder
        "-" * "Script Finished Time : $OstopTime".Length
    }
}

