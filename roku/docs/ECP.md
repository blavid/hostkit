# Launching Eaglewood from Hubitat

The welcome screen does not start itself when the TV powers on. Roku does not let an app take the Home screen. Hubitat turns the TCL on and launches the sideloaded app with the External Control Protocol (ECP).

ECP is plain HTTP on port **8060**. It is not the developer installer (port 80). The examples use the house TV address `192.168.86.101`. Override that if the TV's address is different. None of these calls use the developer password.

## Settings that have to be on

**Control by mobile apps → Enabled.** As of Roku OS 14.1, `keypress` commands are ignored unless this is on. On the TV: Settings → System → Advanced system settings → Control by mobile apps → Enabled. That is the network-access switch that lets a device on the LAN (Hubitat) send ECP.

**Fast TV start.** A Roku TV that is fully off drops its network connection, so a power command never arrives. Fast TV start keeps the set reachable in standby. It uses more power than a full shutdown. On this TCL: Home → Settings → System → Power → Fast TV start → enable Fast TV start. TCL's note for the same menu: [How to enable Fast TV Start on my TCL Roku TV](https://support.tcl.com/en_US/rokutv-setup-configuration/us-how-to-enable-fast-tv-start-rokutv).

The app also has to be sideloaded in developer mode. See the README. Developer mode is separate from these two settings.

## Check-in sequence

1. Power the panel on. Empty POST, no body:

```bash
curl -d '' "http://192.168.86.101:8060/keypress/PowerOn"
```

Roku's published ECP key list names `PowerOff` for Roku TVs (along with the volume keys). `PowerOn` is the matching power-on keypress those TVs accept, and it is the command Hubitat should send. It only works while the TV is still on the network, which is what Fast TV start is for.

2. Wait until the set is actually awake. `query/device-info` reports `<power-mode>PowerOn</power-mode>` when it is. Give the UI a few seconds after that before launching; a launch sent during the wake animation can be missed.

```bash
curl -s "http://192.168.86.101:8060/query/device-info"
```

3. Launch the sideloaded app. The app id for the developer channel is `dev`. Empty POST:

```bash
curl -d '' "http://192.168.86.101:8060/launch/dev"
```

4. Confirm it is in front:

```bash
curl -s "http://192.168.86.101:8060/query/active-app"
```

A successful launch returns an `<app>` element whose id is `dev`. The title is `Eaglewood`. The Home screen returns `<app>Roku</app>` and nothing else.

## Relaunch

Sending `POST /launch/dev` again, whether or not the app is already open, should leave the guest on this same welcome screen.

- If the app is not running, Roku starts it and calls `Main()`.
- If it is already running, Roku delivers an `roInput` event instead of starting a second copy. The manifest sets `supports_input_launch=1` so that event arrives. The app reads `contentId`, `mediaType`, and `source` and does not navigate. It also puts the fallback greeting back on screen and fetches `guest.json` again. A date-only `checkout` in that file is the end of that day in Pacific time, computed in the channel rather than by `roDateTime`. The TV's timezone setting is not consulted. A checkout that cannot be parsed still shows the guest name; only a parsed checkout that is already past uses the fallback. Port 8085 logs that refetch with the path key masked.

Deep-link query parameters are accepted and ignored. This is still the welcome screen:

```bash
curl -d '' "http://192.168.86.101:8060/launch/dev?contentId=stay&mediaType=episode"
```

The Home button always leaves the app. The app cannot trap it. Send `POST /launch/dev` again to bring the welcome screen back. Back, on this only screen, also exits.

## Guest Mode

Use Roku Guest Mode for what it is good at: guests sign in to their own streaming apps, and Roku signs them out. Guests pick a checkout date; sign-out is 11:00 AM that day. The host can also sign them out from my.roku.com. Turning Guest Mode on, turning it off, and guest checkout all close the running app (the firmware exit reasons are `EXIT_GUEST_MODE_*` and `EXIT_GUEST_CHECKOUT`).

Launch Eaglewood after Guest Mode is already in the state you want for the stay. If Hubitat enables Guest Mode at check-in, do that first, then send `PowerOn` (if needed) and `POST /launch/dev`. This screen does not replace Guest Mode, and it does not try to hold the TV against Home or the system screensaver.
