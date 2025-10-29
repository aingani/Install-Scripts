
$appsToRemove = @(
    "Dell SupportAssist",
    "Dell SupportAssist OS Recovery Plugin for Dell Update",
    "Dell SupportAssist Remediation"
)

foreach ($app in $appsToRemove) {
    Write-Host "Trying to uninstall $app using winget..."
    winget uninstall --name "$app" --silent
}
