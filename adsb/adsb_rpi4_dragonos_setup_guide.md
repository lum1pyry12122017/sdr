# ADS-B Monitoring System Setup Guide

**Version:** 1.0\
**Date:** 2026-02-25\
**Platform:** Raspberry Pi 4 + DragonOS + RTL-SDR\
**Client:** Windows 10 (Browser + TCP Clients)

------------------------------------------------------------------------

## 1. System Architecture

    RTL-SDR → readsb (decoder) → 
       ├─ tar1090 (Web UI :80)
       ├─ Beast TCP :30005
       └─ SBS TCP :30003

------------------------------------------------------------------------

## 2. Hardware Requirements

-   Raspberry Pi 4
-   RTL-SDR (R820T/R820T2 compatible)
-   1090 MHz antenna (recommended dedicated ADS-B antenna)
-   Stable 5V power supply
-   Network connection (LAN)

------------------------------------------------------------------------

## 3. Verify RTL-SDR Detection

On Raspberry Pi:

``` bash
lsusb | grep -i realtek
```

Optional direct RF test:

``` bash
sudo systemctl stop readsb
timeout 30 rtl_adsb
sudo systemctl start readsb
```

If hex frames (`*....;`) appear → RF path works.

------------------------------------------------------------------------

## 4. Enable and Start readsb

``` bash
sudo systemctl enable --now readsb
systemctl status readsb
```

Confirm ports are listening:

``` bash
sudo ss -lntp | egrep '(:80|:30002|:30003|:30005)'
```

Expected: - 80 → lighttpd (tar1090) - 30002 → Raw output - 30003 → SBS
output - 30005 → Beast output

------------------------------------------------------------------------

## 5. Configure Receiver Gain

Edit:

``` bash
sudo nano /etc/default/readsb
```

Example:

    RECEIVER_OPTIONS="--device-type rtlsdr --device 0 --gain 49.6 --ppm 0"

Restart:

``` bash
sudo systemctl restart readsb
```

------------------------------------------------------------------------

## 6. Set tar1090 Home Location (Example: Tampere)

Edit:

``` bash
sudo nano /etc/tar1090/config.js
```

Uncomment and modify:

    DefaultCenterLat = 61.4981;
    DefaultCenterLon = 23.7610;

Restart web server:

``` bash
sudo systemctl restart lighttpd
```

Hard refresh browser (Ctrl+F5).

------------------------------------------------------------------------

## 7. Verify Windows Connectivity

### 7.1 Browser Access

    http://<pi-ip>/tar1090/

### 7.2 Port Connectivity (PowerShell)

``` powershell
Test-NetConnection <pi-ip> -Port 30005
Test-NetConnection <pi-ip> -Port 30003
```

Expected:

    TcpTestSucceeded : True

------------------------------------------------------------------------

## 8. Basic Health Check

On Pi:

``` bash
python3 - <<'PY'
import json
d=json.load(open("/run/readsb/stats.json"))
last=d.get("last1min",{}).get("local",{})
print("accepted:", last.get("accepted"))
print("modes:", last.get("modes"), "bad:", last.get("bad"))
PY
```

Healthy system indicators: - accepted \> 0 - aircraft visible in
tar1090 - Beast/SBS ports reachable from Windows

------------------------------------------------------------------------

## 9. Troubleshooting Summary

  Symptom                                Likely Cause
  -------------------------------------- ---------------------------------------
  No aircraft, ports open                RF / antenna issue
  rtl_adsb works, readsb zero accepted   Gain tuning required
  Ports closed                           readsb not running
  Service restart loop                   Invalid option in /etc/default/readsb

------------------------------------------------------------------------

## 10. Production-Ready State Checklist

-   [ ] readsb active and stable
-   [ ] tar1090 accessible via browser
-   [ ] Ports 30003 and 30005 reachable
-   [ ] Home location set
-   [ ] Valid frames observed

------------------------------------------------------------------------

**System Status:** Architecturally correct when all above checks pass.
