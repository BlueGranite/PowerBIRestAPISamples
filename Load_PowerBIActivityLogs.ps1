<#
Purpose:       Extract and store Power BI Usage Auditing data from Power BI Activity log. Runs as an active session but can be modified to run autonomously.
               Companion script to Youtube video https://www.youtube.com/watch?v=qEbpjsa1h28&lc=UgxuY4QSkJ2bHLfaNQt4AaABAg
Tested with:   PowerShell Power BI Management Module installed
Prerequisites: The domain user specified needs to be a Power BI or Office 365 administrator to use the cmdlet/Admin REST API.

#>

#Verify that the PowerShell module is installed
if ( !(Get-InstalledModule MicrosoftPowerBIMgmt)) {
    Install-Module -Name MicrosoftPowerBIMgmt -Scope CurrentUser
  }

Import-Module -Name MicrosoftPowerBIMgmt
 # Step 1 - Authenticate
Connect-PowerBIServiceAccount #use get-help to find more information on how to pass credentials to automate this

#Container file path for data file output:
$localFilePath = "" #"ENTER a local file path to store these"
$localFileName = 'UsageDataExport_'


$nbrDaysToGoBack =30 #1 = yesterday; 0=today; 2=2 days ago; 30 = maximum available;

# Run cmdlet for desired time period in 1 day increments
for ($i = 1; $i -le $nbrDaysToGoBack; $i++)
{
    $startDateToExtract = (((Get-Date).AddDays(-$i)).ToUniversalTime()).ToString('yyyy-MM-ddT00:00:00.000')
    $endDateToExtract = (((Get-Date).AddDays(-$i)).ToUniversalTime()).ToString('yyyy-MM-ddT23:59:59.999')
    $consolidatedFile = $localFilePath + '\' + $localFileName + ([datetime]$startDateToExtract).ToString('yyyy-MM-dd.JSON')

    $urlToRetrieveData = "https://api.powerbi.com/v1.0/myorg/admin/activityevents?startDateTime='$startDateToExtract'&endDateTime='$endDateToExtract'"
    $result = (Invoke-PowerBIRestMethod -Url $urlToRetrieveData -Method GET)|ConvertFrom-Json

    $activity = $null

    if([string]::IsNullOrEmpty($result.ActivityEventEntities))
    {
        Write-Output "Requesting Data using continuation token"
    }
    else
    {
         $activity += $result.ActivityEventEntities
    }
    $attempt = 1
    Do
    {
        $contToken = $result.ContinuationToken
        $urlToRetrieveData = "https://api.powerbi.com/v1.0/myorg/admin/activityevents?continuationToken='$contToken'"
        $result = (Invoke-PowerBIRestMethod -Url $urlToRetrieveData -Method GET) |ConvertFrom-Json
        if([string]::IsNullOrEmpty($result.ActivityEventEntities))
        {
         Write-Output "Moving On"
        }
        else
        {
         $activity += $result.ActivityEventEntities
        }
        $attempt++
    }
    While ($null -ne $result.ContinuationToken)

    $activity| ConvertTo-JSON -Compress | Set-Content $consolidatedFile
    "Output $($activity.Count) records"
}

