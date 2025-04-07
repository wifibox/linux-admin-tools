#!/usr/bin/env python3
import os
import argparse
import smtplib
import socket
import subprocess
from email.message import EmailMessage

# Configuration thresholds
DISK_THRESHOLD_PERCENT = 5         # minimal percentage of free disk space
DISK_THRESHOLD_ABS = 2 * 1024**3     # minimal free disk space (2GB) in bytes
INODE_THRESHOLD_PERCENT = 5        # minimal percentage of free inodes

# Special thresholds for specific partitions (in bytes)
SPECIAL_THRESHOLDS = {
    '/boot': 200 * 1024**2,   # 200MB
    '/tmp': 500 * 1024**2,    # 500MB
}

# SMTP configuration (internal variables)
SMTP_SERVER = ""
SMTP_PORT = 587
SMTP_USER = ""
SMTP_PASSWORD = ""
MAIL_FROM = ""  # FROM field for email messages

def get_default_ipv4_info():
    """
    Returns a dictionary with keys similar to ansible_default_ipv4.
    Uses "ip route get 8.8.8.8" to determine the default IPv4 address and interface.
    """
    ipv4_info = {}
    try:
        output = subprocess.check_output(["ip", "route", "get", "8.8.8.8"], encoding='utf-8')
        tokens = output.split()
        for i, token in enumerate(tokens):
            if token == "src" and i+1 < len(tokens):
                ipv4_info["address"] = tokens[i+1]
            if token == "dev" and i+1 < len(tokens):
                ipv4_info["interface"] = tokens[i+1]
        if "address" not in ipv4_info:
            ipv4_info["address"] = "Unknown"
        if "interface" not in ipv4_info:
            ipv4_info["interface"] = "Unknown"
    except Exception:
        ipv4_info = {"address": "Unknown", "interface": "Unknown"}
    return ipv4_info

def get_fstab_mounts():
    """Reads mount points from /etc/fstab, ignoring comments and empty lines."""
    mounts = []
    try:
        with open('/etc/fstab', 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                parts = line.split()
                if len(parts) >= 2:
                    mounts.append(parts[1])
    except Exception as e:
        print(f"Error reading /etc/fstab: {e}")
    return mounts

def check_partition_alert(mount_point):
    """
    Checks available disk space and inodes for a given partition.
    Returns an alert string if thresholds are exceeded, or an empty string otherwise.
    """
    alerts = []
    try:
        stat = os.statvfs(mount_point)
    except Exception as e:
        return f"Cannot check partition {mount_point}: {e}"

    total_space = stat.f_blocks * stat.f_frsize
    free_space = stat.f_bavail * stat.f_frsize  # space available for unprivileged users
    free_percent = (free_space / total_space * 100) if total_space > 0 else 0

    total_inodes = stat.f_files
    free_inodes = stat.f_ffree
    inode_free_percent = (free_inodes / total_inodes * 100) if total_inodes > 0 else 0

    # Check disk space thresholds
    if free_percent < DISK_THRESHOLD_PERCENT or free_space < DISK_THRESHOLD_ABS:
        alerts.append(f"Partition {mount_point}: only {free_space/(1024**2):.2f} MB free ({free_percent:.2f}% available)")

    # Check special thresholds for partycji /boot i /tmp
    if mount_point in SPECIAL_THRESHOLDS:
        if free_space < SPECIAL_THRESHOLDS[mount_point]:
            required_mb = SPECIAL_THRESHOLDS[mount_point] / (1024**2)
            alerts.append(f"{mount_point}: less than the required {required_mb:.0f} MB free")
    
    # Check inode availability
    if inode_free_percent < INODE_THRESHOLD_PERCENT:
        alerts.append(f"Partition {mount_point}: free inodes {free_inodes} ({inode_free_percent:.2f}% available)")
    
    return "\n".join(alerts)

def get_partition_status(mount_point):
    """
    Returns full status information for a given partition.
    """
    try:
        stat = os.statvfs(mount_point)
    except Exception as e:
        return f"Cannot check partition {mount_point}: {e}"

    total_space = stat.f_blocks * stat.f_frsize
    free_space = stat.f_bavail * stat.f_frsize
    used_space = total_space - free_space
    used_percent = (used_space / total_space * 100) if total_space > 0 else 0
    return (f"Partition {mount_point}: Total {total_space/(1024**3):.2f} GB, "
            f"Used {used_space/(1024**3):.2f} GB ({used_percent:.2f}% used)")

def send_email(subject, message, recipients):
    """Sends an email using SMTP with authentication."""
    msg = EmailMessage()
    msg['Subject'] = subject
    msg['From'] = MAIL_FROM
    msg['To'] = ", ".join(recipients)
    msg.set_content(message)
    
    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.send_message(msg)
    except Exception as e:
        print(f"Error sending email: {e}")

def main():
    parser = argparse.ArgumentParser(
        description="Check disk and inode usage for partitions from /etc/fstab."
    )
    parser.add_argument("--status", action="store_true", 
                        help="Display full status for all partitions")
    parser.add_argument("--email", nargs='+', 
                        help="Email addresses to send alerts/status to")
    args = parser.parse_args()

    mounts = get_fstab_mounts()
    
    alerts_list = []
    full_status_list = []
    for mount in mounts:
        # Jeśli natrafimy na partycję /boot/efi, pomijamy ją
        if mount == "/boot/efi":
            continue
        if not os.path.ismount(mount):
            continue
        alert = check_partition_alert(mount)
        if alert:
            alerts_list.append(alert)
        full_status_list.append(get_partition_status(mount))
    
    # Prepare server info similar to ansible_default_ipv4
    hostname = socket.gethostname()
    ipv4_info = get_default_ipv4_info()
    server_info = (f"Server: {hostname}\n"
                   f"Default IPv4: {ipv4_info.get('address', 'Unknown')}\n"
                   f"Interface: {ipv4_info.get('interface', 'Unknown')}")
    
    if args.status:
        output = "\n".join(full_status_list)
    else:
        if alerts_list:
            output = "\n\n".join(alerts_list)
        else:
            output = "All partitions meet the required thresholds."
    
    full_message = server_info + "\n\n" + output

    # Send email only if alerts are present
    if args.email:
        if alerts_list:
            send_email("Alert: Low disk space/inodes on partitions", full_message, args.email)
            print("Email sent.")
    else:
        print(full_message)

if __name__ == "__main__":
    main()

