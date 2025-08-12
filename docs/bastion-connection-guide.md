# Bastion Host Connection Guide

## Important: Use VNC, not RDP
The bastion host is running Amazon Linux 2023 with VNC server (not RDP/xrdp).

## VNC Connection Details
- **Server:** 54.188.216.1
- **Port:** 5901  
- **Username:** vastadmin
- **Password:** VastP0c2024!

## Connection Methods

### Option 1: macOS Built-in Screen Sharing (Recommended for Mac)
1. Open Finder
2. Press `Cmd+K` (Go > Connect to Server)
3. Enter: `vnc://54.188.216.1:5901`
4. Click Connect
5. Enter password: `VastP0c2024!`

### Option 2: Microsoft Remote Desktop App
Unfortunately, Microsoft Remote Desktop does NOT support VNC protocol.
You'll need a VNC client instead.

### Option 3: RealVNC Viewer (Free - Works on Mac/Windows)
1. Download from: https://www.realvnc.com/en/connect/download/viewer/
2. Install and open RealVNC Viewer
3. Enter: `54.188.216.1:5901`
4. Password: `VastP0c2024!`

### Option 4: TigerVNC (Free Open Source)
1. Download from: https://github.com/TigerVNC/tigervnc/releases
2. Install and use the viewer
3. Connect to: `54.188.216.1:5901`
4. Password: `VastP0c2024!`

## SSH Access (Alternative)
If you just need command line access:
```bash
ssh -i ./vast-datalayer-poc-key.pem ec2-user@54.188.216.1
```

## Troubleshooting
- If connection fails, the instance may still be booting (wait 2-3 minutes after reboot)
- Security group allows VNC on port 5901 from anywhere (0.0.0.0/0)
- The desktop environment is GNOME on Amazon Linux 2023