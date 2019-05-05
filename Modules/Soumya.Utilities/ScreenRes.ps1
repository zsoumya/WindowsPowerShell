function Get-ScreenResolution
{
    [void] [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void] [Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    $screens = [system.windows.forms.screen]::Allscreens

    foreach ($screen in $screens)
    {
        $OutputObj = New-Object -TypeName PSobject
        $OutputObj | Add-Member -MemberType NoteProperty -Name DeviceName -Value $screen.DeviceName
        $OutputObj | Add-Member -MemberType NoteProperty -Name Width -Value $screen.Bounds.Width
        $OutputObj | Add-Member -MemberType NoteProperty -Name Height -Value $screen.Bounds.Height
        $OutputObj | Add-Member -MemberType NoteProperty -Name IsPrimary -Value $screen.Primary
        $OutputObj
    }
}