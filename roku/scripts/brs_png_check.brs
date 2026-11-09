sub Main()
    failed = 0
    rgb = ExpandPngBytes(FixtureRgbPng())
    if rgb.ok <> true or rgb.converted <> false or rgb.color <> 2 or rgb.bit <> 8
        print "FAIL an RGB PNG was rewritten"
        failed = failed + 1
    end if

    source = FixtureGrayPng()
    gray = ExpandPngBytes(source)
    if gray.ok <> true or gray.converted <> true or gray.color <> 0 or gray.width <> 4 or gray.height <> 3
        print "FAIL grayscale PNG convert header"
        print gray.reason
        failed = failed + 1
    else
        header = ReadPng(gray.bytes)
        original = ReadPng(AsBuf(source))
        if header.ok <> true or header.color <> 3 or header.bit <> 8 or header.interlace <> 0
            print "FAIL converted PNG is not 8-bit indexed"
            failed = failed + 1
        else if header.plte = invalid or header.plte.n <> 768 or BufAt(header.plte, 30) <> 10
            print "FAIL gray palette"
            failed = failed + 1
        else if header.idat.n <> original.idat.n or BufAt(header.idat, 0) <> BufAt(original.idat, 0)
            print "FAIL IDAT was recompressed"
            failed = failed + 1
        end if
    end if

    masked = SafeUri("https://sunrivertownhome.com/tv/examplekey/wifi.png?t=1")
    if masked <> "https://sunrivertownhome.com/tv/***/wifi.png"
        print "FAIL a path key stayed in a logged URL"
        failed = failed + 1
    end if
    if SafeUri("https://sunrivertownhome.com/data/qr/cafe.png") <> "https://sunrivertownhome.com/data/qr/cafe.png"
        print "FAIL a public QR URL was rewritten"
        failed = failed + 1
    end if
    if SafeUri("") <> "none"
        print "FAIL an empty URI was logged"
        failed = failed + 1
    end if
    if StaleQrCacheName("qr-badge.png") <> true or StaleQrCacheName("qr-book.url") <> true
        print "FAIL a cached QR name was kept"
        failed = failed + 1
    end if
    if StaleQrCacheName("wifi.png") <> false or StaleQrCacheName("guide.json") <> false or StaleQrCacheName("photo.png") <> false
        print "FAIL a non-QR cache file was selected"
        failed = failed + 1
    end if
    if StaleQrCacheName("wifi-next.png") <> false or StaleQrCacheName("qr-badge-abcdef12.png") <> false
        print "FAIL content-named QR cleanup picked the wrong file"
        failed = failed + 1
    end if
    if StaleQrCacheName("qr-book-5d41402a.png") <> false or StaleQrCacheName("qr-detail-8423281c.png") <> false
        print "FAIL a hashed QR file was selected for cleanup"
        failed = failed + 1
    end if
    if ProtectedCacheFile("cachefs:/eaglewood/qr-badge-8423281c.png") <> true
        print "FAIL a hashed badge QR can be deleted"
        failed = failed + 1
    end if
    if ProtectedCacheFile("tmp:/eaglewood/wifi.png") <> true
        print "FAIL wifi.png can be deleted"
        failed = failed + 1
    end if
    if ProtectedCacheFile("cachefs:/eaglewood/qr-badge.png") <> false or ProtectedCacheFile("cachefs:/eaglewood/qr-fetch-badge.png") <> false
        print "FAIL an old QR name was treated as hashed content"
        failed = failed + 1
    end if
    if ProtectedCacheFile("cachefs:/eaglewood/activities.json") <> false or ProtectedCacheFile("cachefs:/eaglewood/wifi-next.png") <> false
        print "FAIL the activities wipe was blocked"
        failed = failed + 1
    end if
    if QrCacheHit("cachefs:/eaglewood/qr-badge-8423281c.png", 6270) <> true or QrCacheHit("cachefs:/eaglewood/qr-badge-8423281c.png", 0) <> false or QrCacheHit("cachefs:/eaglewood/qr-badge-8423281c.png", -1) <> false or QrCacheHit("", 6270) <> false
        print "FAIL the QR cache shortcut accepted an empty file"
        failed = failed + 1
    end if
    if QrContentFileName("badge", "abcdef123456") <> "qr-badge-abcdef12.png"
        print "FAIL a QR file was not named from its digest"
        failed = failed + 1
    end if
    hello = DigestTagFromHex("5d41402abc4b2a76eea3a8c7e1c5c1c6")
    if hello <> "5d41402a"
        print "FAIL the md5 suffix was not the first 8 hex chars"
        failed = failed + 1
    end if
    if QrContentFileName("book", hello) <> "qr-book-5d41402a.png"
        print "FAIL the book QR was not named from the md5"
        failed = failed + 1
    end if
    if QrTempFileName("book", hello) <> "qr-book-5d41402a.tmp"
        print "FAIL the temp QR was not named from the md5"
        failed = failed + 1
    end if
    if QrContentFileName("book", "") <> "" or QrTempFileName("book", "") <> ""
        print "FAIL an empty digest still built a QR path"
        failed = failed + 1
    end if
    helloBytes = [104, 101, 108, 108, 111]
    if LCase(Md5Hex(helloBytes)) <> "5d41402abc4b2a76b9719d911017c592" or Md5Tag(helloBytes) <> "5d41402a"
        print "FAIL md5 of hello"
        failed = failed + 1
    end if
    if Md5Tag(invalid) <> ""
        print "FAIL a missing buffer still hashed"
        failed = failed + 1
    end if
    if StaleQrCacheName("qr-fetch-book.png") <> false or StaleQrCacheName("qr-fetch-book.png.tmp") <> false
        print "FAIL an in-flight QR download was treated as stale"
        failed = failed + 1
    end if
    if StaleQrCacheName("qr-badge-2-incoming.tmp.tmp") <> true
        print "FAIL a double tmp QR name was kept"
        failed = failed + 1
    end if
    if PngDigestTag(invalid) <> ""
        print "FAIL a missing digest became a file suffix"
        failed = failed + 1
    end if
    if PathIsBusy("cachefs:/eaglewood/qr-badge-abcdef12.png", "cachefs:/eaglewood/wifi.png|cachefs:/eaglewood/qr-badge-abcdef12.png") <> true
        print "FAIL an in-use QR file was treated as free"
        failed = failed + 1
    end if
    if PathIsBusy("cachefs:/eaglewood/qr-book-abcdef12.png", "cachefs:/eaglewood/qr-badge-abcdef12.png") <> false
        print "FAIL a free QR file was treated as in use"
        failed = failed + 1
    end if

    failed = failed + RunBadgeColdStarts()
    if failed = 0 then print "brs png checks passed"
end sub

function FixtureGrayPng() as object
    return [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 4, 0, 0, 0, 3, 8, 0, 0, 0, 0, 145, 159, 241, 26, 0, 0, 0, 23, 73, 68, 65, 84, 120, 218, 99, 224, 18, 145, 211, 96, 228, 146, 227, 226, 98, 249, 118, 227, 127, 35, 0, 15, 136, 3, 244, 69, 243, 121, 204, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]
end function

function FixtureRgbPng() as object
    return [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 4, 0, 0, 0, 3, 8, 2, 0, 0, 0, 59, 150, 57, 145, 0, 0, 0, 40, 73, 68, 65, 84, 120, 156, 99, 224, 226, 226, 18, 17, 17, 145, 147, 147, 211, 208, 208, 96, 0, 114, 128, 148, 145, 145, 145, 141, 141, 13, 3, 4, 252, 255, 255, 191, 161, 161, 1, 0, 88, 44, 7, 138, 25, 211, 130, 39, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]
end function
