sub Main(args as object)
    AcceptLaunchArgs(args)
    ' The task also loads this bundle. Doing it once on the main thread
    ' keeps the first guest request from failing certificate setup.
    PrepareGuestCertificates()
    ' Make the shared cache folder before any task writes into it, so the
    ' Wi-Fi, guide, and QR tasks never race to create it.
    PrepareCacheDir()

    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    scene = screen.CreateScene("MainScene")
    screen.show()
    emuKeys = EmuKeysFromArgs(args)
    if emuKeys <> "" then scene.emuKeys = emuKeys

    ' A second POST /launch/dev while this app is already open arrives here
    ' instead of starting Main() again. Deep-link parameters are ignored.
    input = CreateObject("roInput")
    if input <> invalid
        input.setMessagePort(m.port)
    end if

    ' Required for certification as of October 1, 2026. This screen has no
    ' cache to release; the handler still consumes the warning.
    monitor = CreateObject("roAppMemoryMonitor")
    if monitor <> invalid
        monitor.setMessagePort(m.port)
        monitor.EnableMemoryWarningEvent(true)
    end if

    while true
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        else if msgType = "roInputEvent"
            if msg.isInput()
                AcceptLaunchArgs(msg.getInfo())
                scene.relaunchCount = scene.relaunchCount + 1
            end if
        else if msgType = "roAppMemoryNotificationEvent"
            NoteMemoryWarning(msg)
        end if
    end while
end sub

sub PrepareCacheDir()
    fs = CreateObject("roFileSystem")
    if fs = invalid then return
    if not fs.Exists("cachefs:/eaglewood") then fs.CreateDirectory("cachefs:/eaglewood")
    if not fs.Exists("cachefs:/hostkit") then fs.CreateDirectory("cachefs:/hostkit")
end sub

sub PrepareGuestCertificates()
    transfer = CreateObject("roUrlTransfer")
    if transfer = invalid then return
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
end sub

sub AcceptLaunchArgs(args as object)
    if args = invalid then return
    if type(args) <> "roAssociativeArray" then return
    contentId = args.lookup("contentId")
    if contentId = invalid then contentId = args.lookup("contentID")
    mediaType = args.lookup("mediaType")
    if mediaType = invalid then mediaType = args.lookup("MediaType")
    source = args.lookup("source")
    ' One screen. contentId, mediaType, and source do not navigate anywhere.
    if contentId <> invalid or mediaType <> invalid or source <> invalid
        return
    end if
end sub

sub NoteMemoryWarning(msg as object)
    if msg = invalid then return
    info = msg.getInfo()
    if info = invalid then return
    percent = info.lookup("MemoryUsagePercent")
    if percent = invalid then return
    if percent < 0 then return
end sub

' Screenshot harness only. scripts/emu_screens.sh stages pkg:/emu/enabled in a
' temp copy; the sideload zip never has it, so normal and store builds ignore
' the emuKeys launch parameter.
function EmuKeysFromArgs(args as object) as string
    if args = invalid then return ""
    if type(args) <> "roAssociativeArray" then return ""
    value = args.lookup("emuKeys")
    if value = invalid then return ""
    fs = CreateObject("roFileSystem")
    if fs = invalid then return ""
    if not fs.Exists("pkg:/emu/enabled") then return ""
    return value.toStr()
end function
