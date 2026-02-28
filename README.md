# The Covert SD-WAN Travel Router (V5 "Dark Boot" Architecture)

This repository contains the Infrastructure-as-Code (IaC) deployment pipeline for a high-security, covert travel router built on top of a Raspberry Pi. 

By leveraging a unique "Dark Boot" hardware-takeover architecture, this project allows a containerized OpenWrt instance to assume total control of the physical Wi-Fi radios while maintaining a completely hidden, Out-of-Band (OOB) administrative lifeline to the underlying host OS.

## 🚀 Key Features

* **Complete Hardware Isolation:** Bypasses Docker's network bridge limitations by physically moving the `eth0`, `wlan0`, and `wlan1` interfaces into OpenWrt's isolated network namespace (`netns`).
* **The "Lifeline" Architecture:** Automatically provisions a virtual ethernet (`veth`) bridge, allowing the headless Host Pi OS to communicate securely through the OpenWrt router.
* **Dual-Tailscale SD-WAN:** 
  * **Router Instance:** OpenWrt runs an embedded Tailscale node, forcing all connected hotel/cafe client devices through your secure home exit node.
  * **Host Instance:** The Pi OS runs an invisible, OOB Tailscale instance used exclusively for direct-IP RustDesk remote desktop access.
* **Captive Portal Bypass:** Integrated MAC-cloning workflow via LuCI to defeat Layer 7 hotel web-authentication portals.
* **Hardware Agnostic:** Dynamic DKMS and kernel module injection for both Realtek (RTL8812AU) and MediaTek (MT7612U) ALFA Network adapters.

## 🛠️ Hardware Requirements
* **Raspberry Pi 4 or 5** (Running 64-bit Raspberry Pi OS)
* **High-Gain Wi-Fi Adapter:** ALFA Network AWUS036AC, AWUS036ACH, or AWUS036ACM.
* **MicroSD Card** (Flashed with specific pre-flight settings).

## 📚 Getting Started
The entire deployment is handled by an automated Bash pipeline. 

For complete, step-by-step instructions on flashing the Pi, running the deployment script, and configuring the OpenWrt web interface (LuCI), please refer to the student manual:

**👉 [Read the Full Lab Guide here](LAB_GUIDE_LUCI.md)**

---
*Note for Instructors: The architecture and forensics of the V5 network state are maintained separately from the student repository.*