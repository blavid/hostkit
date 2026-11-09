' Diagnostic wrappers. The mount steps themselves stay in MountQrPosterBody.
sub MountQrPoster(poster as object, path as string, slot as string)
    try
        MountQrPosterBody(poster, path, slot)
    catch err
        print "Eaglewood: qr "; slot; " error="; LayoutErrorText(err)
    end try
end sub

sub GuardMountQrPoster(poster as object, path as string, slot as string)
    try
        MountQrPoster(poster, path, slot)
    catch err
        print "Eaglewood: qr "; slot; " error="; LayoutErrorText(err)
    end try
end sub
