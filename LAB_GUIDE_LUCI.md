# Lab Manual: The Covert Travel Router (SD-WAN & LuCI)
**Objective:** Configure the OpenWrt container to manage the physical radios, bypass captive portals, and establish an SD-WAN tunnel to your home exit node.

---

## PRE-FLIGHT: FLASHING THE RASPBERRY PI OS
Before running any scripts, you must prepare the Raspberry Pi's microSD card. We will use the **Raspberry Pi Imager** tool to customize the operating system so it is ready for headless deployment.

1. Open the **Raspberry Pi Imager** on your computer.
2. **Choose Device:** Select your Raspberry Pi model (Pi 4 or Pi 5).
3. **Choose OS:** Select **Raspberry Pi OS (64-bit)** (The standard version with the desktop environment).
4. **Choose Storage:** Select your microSD card.
5. Click **Next**, and when prompted to "Use OS customization?", click **EDIT SETTINGS**.
6. **General Tab:**
   - **Hostname:** Set this to something unique (e.g., `covert-router`).
   - **Set username and password:** Create a secure username (e.g., `pi`) and password. *Do not forget this!*
   - **Configure wireless LAN:** Enter your **home Wi-Fi** SSID and password. (This ensures the Pi has internet access during Phase 1 of the build).
   - **Set locale settings:** Ensure your time zone and keyboard layout are correct.
7. **Services Tab:**
   - Check **Enable SSH**.
   - Select **Use password authentication**.
8. Click **Save**, then click **Yes** to apply the settings and flash the card. 

Once flashed, insert the card into the Pi, plug in the ALFA adapter, and power it on. You can now SSH into the Pi (e.g., `ssh pi@covert-router.local`) to clone the repository and begin Phase 1!

---

## THE DUAL-TAILSCALE ARCHITECTURE
Before you begin, you must understand your secure architecture. You now have **TWO** instances of Tailscale running on this Raspberry Pi, serving two completely different purposes:

1. **The Host Lifeline (RustDesk Backdoor):** 
   - Runs on the underlying Raspberry Pi OS. 
   - *Purpose:* Allows you to securely remote into the Pi's desktop via RustDesk if the router breaks. It does **not** route traffic for the router's clients.
2. **The SD-WAN Gateway (OpenWrt):**
   - Runs inside the OpenWrt Router container.
   - *Purpose:* Encrypts all traffic from your phones and laptops connected to the travel router and tunnels it to your home exit node.

---

## 1. THE COMMAND CENTER (LOGIN)
1. Open RustDesk on your personal laptop.
2. Enter the **Host Lifeline Tailscale IP** (e.g., `100.x.x.x`) to access the Pi's desktop.
3. Once on the Pi's desktop, open the Chromium web browser.
4. Navigate to `http://localhost` or `http://192.168.10.1`.
5. **Username:** `root` | **Password:** (Leave blank and click Login).

---

## 2. THE RECONNAISSANCE (IDENTIFY RADIOS)
Go to **Network -> Wireless**. You will see the physical radios that were injected into the router during the "Dark Boot":
- **Radio 0 (Generic MAC80211):** The internal Broadcom chip (Target: **WAN** - connecting to the hotel/cafe).
- **Radio 1 (Realtek/MediaTek):** The ALFA high-gain adapter (Target: **LAN** - broadcasting to your devices).

---

## 3. ESTABLISHING THE UPLINK (HOTEL/CAFE WI-FI)
1. Find **Radio 0** and click the **Scan** button.
2. Find the target Wi-Fi network and click **Join Network**.
3. **WPA Passphrase:** Enter the password (if it has one).
4. **Name of the new interface:** Leave as `wwan`.
5. **Create / Assign firewall-zone:** Ensure it is set to **wan**.
6. Click **Submit**, then **Save & Apply**.

---

## 4. BYPASSING CAPTIVE PORTALS (MAC CLONING)
If the network you joined in Step 3 requires a webpage login (like a hotel room number), you must bypass it using MAC Cloning. **Tailscale cannot punch through a captive portal.**

To do this seamlessly, we will use your phone to authenticate, and then tell the router to disguise its WAN port as your phone.

**Step A: Defeat MAC Randomization (Crucial)**
Modern phones use different fake MAC addresses for every network. For this trick to work, your phone must use its *real* MAC address on both the Hotel network and the Router network.
1. On your phone, connect to the **Hotel Wi-Fi**. 
2. Go to your phone's Wi-Fi settings for the Hotel network and turn **OFF** "Private Wi-Fi Address" or "MAC Randomization". (It must be set to "Device MAC").
3. Complete the hotel's captive portal login (accept terms, enter room number). Your phone now has internet.
4. Disconnect from the Hotel, and connect your phone to your **Covert_Router** Wi-Fi.
5. Turn **OFF** "Private Wi-Fi Address" for the Covert_Router network as well.

**Step B: The Seamless Clone**
Now that your phone is connected to the router using the same MAC address the hotel authorized, the router can automatically pull it.
1. In the LuCI web interface, go to **Network -> Interfaces**.
2. Find the **wwan** interface you created in Step 3 and click **Edit**.
3. Go to the **Advanced Settings** tab.
4. Click the dropdown arrow on the **Override MAC address** field.
5. LuCI will automatically list the MAC addresses of all currently connected devices. Select your phone's MAC address from the list (it will usually show your phone's IP address next to it).
6. Click **Save & Apply**. The router is now disguised as your phone and the Tailscale tunnel will instantly connect!

---

## 5. BROADCASTING YOUR PRIVATE SECURE LAN (ALFA RADIO)
1. Go to **Network -> Wireless**. Find **Radio 1** (ALFA) and click **Edit**.
2. **Interface Configuration -> General Setup:**
   - **Mode:** Access Point.
   - **SSID:** `Covert_Router_[Your_Name]`
   - **Network:** Ensure **lan** is checked.
3. **Wireless Security:**
   - **Encryption:** `WPA2-PSK (CCMP)` or `WPA3`.
   - **Key:** Enter a secure password for your devices.
4. Click **Save & Apply**.

---

## 6. INITIATING THE SD-WAN TUNNEL (TAILSCALE IN OPENWRT)
Now that the router has internet, we must secure it.

1. Go to your Tailscale Admin Console (on the web) and generate a **reusable Auth Key**.
2. Go to your Pi's RustDesk desktop. Open the terminal application.
3. Drop into the OpenWrt container by typing:
   `sudo docker exec -it openwrt_router sh`
4. Authenticate the router's Tailscale instance:
   `tailscale up --authkey tskey-auth-YOUR_KEY_HERE --exit-node=NAME_OF_YOUR_HOME_PC`
   *(Replace NAME_OF_YOUR_HOME_PC with the name of the desktop you left running at home).*
5. Type `exit` to leave the container.

**Validation:** Connect your smartphone to `Covert_Router_[Your_Name]`. Go to an "IP Checker" website. It should show the IP address and location of your home internet connection, completely hiding the fact that you are traveling!