# ES_Housekeep v1
# This script will remove old documents from ElasticSearch indices

# Define log path
$log_path = "$PSScriptRoot\Log\log.txt"

# Define credential to use in web request
$username = '<username>'
$password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("<password>"))
$password_secret = ConvertTo-SecureString -AsPlainText -Force -String $password
$credential = New-Object -TypeName System.Management.Automation.PSCredential($username, $password_secret)

#- ElasticSearch Hosts
$EShost = @("<server1>",
"<server2>",
"<server3>") | Get-Random

#- Define indices and types to housekeep
#- This is a hashtable of values containing the index name, the document type, and the age threshold of the document (in days) to remove
$indexCol = @()
$indexCol += @{'index'='<index1>';'type'='<doc_typ1>';'age'=30}
$indexCol += @{'index'='<index2>';'type'='<doc_typ2>';'age'=30}
$indexCol += @{'index'='<index3>';'type'='<doc_typ3>';'age'=30}

# ElasticSearch API port
$ESport = 9200

# Timestamp attribute to check in the index
# default ElasticSearch time attribute _timestamp would probably suffice
$ES_timestamp = '<timestamp>' 

#- HELPER function
function Log-Message {
    param([string] $message)

    $current_date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "$current_date $message" >> $log_path
}

$indexCol | foreach {
    $targetUri = "http://$EShost`:$ESport"
    $targetIndex = $_.index
    $targetType = $_.type
    $age = $_.age
    $SEARCHUri = $targetUri + '/' + $targetIndex +'/' + $targetType + '/' + '_search?search_type=scan&scroll=1m' # scroll interval of 1 minute, this shouldn't matter since we only need the scroll page active for a very short time
    $SCROLLUri = $targetUri + '/_search/scroll?scroll=1m'
    $DELETEUri = $targetUri + '/' + $targetIndex +'/' + $targetType + '/' + '_bulk'

    $returnsize = 50 # Larger may be faster, but more memory demand
    $target_date = (Get-Date).AddDays(-$age).ToString('o')

    $query = ('{
      "query": {
        "range" : {
          "<timestamp>" : {
              "lt" : "<target_date>"
          }
        }
      },
      "size": <return_size>
    }').Replace('<timestamp>',$ES_timestamp).Replace('<target_date>',$target_date).Replace('<return_size>',$returnsize)

    try {
        $result = Invoke-WebRequest -Uri $SEARCHUri -Method Post -Body $query -Credential $credential  -UseBasicParsing
        $resultObj = $result.Content | ConvertFrom-Json
        $id = $resultObj._scroll_id
    }
    catch {
        Log-Message "Unable to query documents to delete for $targetIndex"
        Log-Message $_
        break
    }

    $deleteCount = 0
    if ($resultObj.hits.total -gt 0) {
        Log-Message ($resultObj.hits.total.ToString() + " documents marked for deletion in index $targetIndex")
        while (![string]::IsNullOrWhiteSpace($id))
        { 
            $result2 = Invoke-WebRequest -Uri $SCROLLUri -Method Post -Body $id -Credential $credential  -UseBasicParsing
            $resultObj2 = $result2.Content | ConvertFrom-Json
            
            $id = $resultObj2._scroll_id
            $collection = $resultObj2.hits.hits._id

            if ($collection.Count -le 0) {
                $id = [string]::Empty
            }
            else {
                $bulk_message = [string]::Empty
                $collection | foreach {
                    $bulk_message += "{ `"delete`" : { `"_id`" : `"$_`" }  }`n"
                    $deleteCount++
                }
                try {
                    $delete_result = Invoke-WebRequest -Uri $DELETEUri -Method Post -Body $bulk_message -Credential $credential -UseBasicParsing -ErrorAction Stop
                    if ($delete_result.StatusCode -ne 200 -and $delete_result.StatusDescription -ne "OK") {
                        Log-Message "BULK delete failed for $targetIndex"
                        Log-Message $delete_result.Content
                    }
                    else {
                        $deleteCount += $collection.Count
                    }
                }
                catch {
                    Log-Message "Unable to execute bulk document delete for $targetIndex"
                    Log-Message $_
                }
            }
        }
        if ($deleteCount -ne 0) {
            Log-Message "Removed $deleteCount documents from index $targetIndex"
        }
    }
    else {
        Log-Message "No logs to remove for index $targetIndex"
    }

}

