# NexDockBridge

A free, independent macOS menu-bar utility that makes a supported NexDock touchpad usable as a mouse by translating USB HID touch reports into macOS pointer events.

NexDock officially lists the touchpad as incompatible with Apple devices: [NexDock 6 support](https://nexdock.com/support-nexdock-6/). This project is an unofficial workaround, not affiliated with or endorsed by Nex Computer or Apple.

## Compatibility

- Tested on one Apple Silicon Mac mini (macOS 27.0) with a USB-connected NexDock using the SINO WEALTH HID interface `258a:0f08` and input report `0x1e`.
- This interface is associated with the NexDock 6 / 2025 generation. Other models, OS versions, Intel Macs and Bluetooth have not been tested.
- This utility controls the pointer; it does not implement native Apple multitouch or a full system trackpad driver.

## Features

- Relative pointer movement with adjustable speed.
- Physical left and right click.
- One-finger tap, two-finger tap, two-finger scrolling.
- Double-click events and held-button dragging, including resizing windows with one finger holding the physical button and another moving.
- Menu-bar pause/resume, counters and quit.

Pointer movement, clicks, scrolling and two-finger physical-button window resizing have been confirmed on the original test setup. Other devices, reconnect behavior, multiple displays and long-term reliability need more testing. The pointer currently stays within its current display.

## Install

1. Download the Apple Silicon ZIP from [Releases](https://github.com/md-kks/NexDockBridge/releases).
2. Unzip it, move NexDockBridge.app into Applications (or your user Applications folder), and open it.
3. The initial release is locally ad-hoc signed, not Apple-notarized. macOS may block it. Review the source and verify the SHA-256 before deciding whether to trust it. If comfortable, use the app-specific Open Anyway option in System Settings → Privacy & Security after attempting to open the app. Alternatively, build it yourself below. Do not disable Gatekeeper or SIP.
4. Grant **Accessibility** permission so the app may post mouse events. Grant **Input Monitoring** if macOS requests it so the app can receive the USB touch reports. Quit and reopen the utility after granting permissions.
5. Connect the NexDock by USB. Click the NexDock menu-bar item to see its device and event counters.

If an update stops receiving input or moving the cursor even though the permission toggle is enabled, quit the app, remove its stale entries in Privacy & Security → Input Monitoring and Accessibility, add the new app and grant the permissions again where requested. Quit and reopen the app after changing permissions. Ad-hoc signatures change with updates; a consistently Developer ID-signed release can reduce these recurring permission prompts.

To stop the utility, choose Quit NexDockBridge in its menu. To launch at login, add the app manually under System Settings → General → Login Items. To uninstall, quit it, remove the app and revoke any permissions you granted.

## Build from source

Requires Xcode Command Line Tools and the macOS SDK. No external libraries.

```sh
git clone https://github.com/md-kks/NexDockBridge.git
cd NexDockBridge
./build.sh
open build/NexDockBridge.app
```

The script builds for the host architecture and SDK. Compatibility with older macOS versions is not guaranteed. Run `./test.sh` to execute the drag regression test without posting real mouse events.

## Privacy and security

The app matches only the NexDock USB mouse interface (vendor/product and primary HID usage). It processes touch reports locally, does not register the keyboard interface, and does not send data over the network. The source contains no telemetry or storage of raw touch coordinates. The menu and local macOS logs contain aggregate event counters for troubleshooting.

No kernel extension, administrator privileges, firmware modifications or system-security disabling are required. macOS permission prompts are required where applicable.

## Status and contributions

Version 0.2.1 is an early community preview. It fixes physical-button dragging with two contacts (e.g. resizing a window while holding the left button) by prioritizing drag motion over scrolling and tracking moving contacts by ID. If you report an issue, please include the NexDock model, macOS version, connection type and the HID device ID; do not include personal information. Pull requests and compatibility reports are welcome.

Licensed under the MIT License. Free to use and modify.
