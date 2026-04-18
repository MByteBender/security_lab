import requests
import time
import sys
import urllib3

# Disable warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

FIREWALL_IP = "172.16.16.16"  # The Sophos default IP
API_URL = f"https://{FIREWALL_IP}:4444/webconsole/APIController"

# This XML updates the admin password and sets a new hostname
# You can add interface changes, firewall rules, etc. here.
config_xml = """
<Request>
    <Login>
        <Username>admin</Username>
        <Password>admin</Password>
    </Login>
    <Set operation="update">
        <Administrator>
            <Name>admin</Name>
            <Password>NewSecurePassword123!</Password>
        </Administrator>
        <DeviceConfiguration>
            <HostName>Proxmox-Firewall-01</HostName>
        </DeviceConfiguration>
    </Set>
</Request>
"""


def wait_for_api(timeout=600):
    print(f"[*] Waiting for Sophos API at {API_URL}...")
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            # We just want to see if the port is open and responding
            response = requests.get(API_URL, verify=False, timeout=5)
            if response.status_code == 200 or response.status_code == 404:
                print("[+] API is online!")
                return True
        except requests.exceptions.RequestException:
            pass

        print("...still waiting...")
        time.sleep(15)
    return False


def push_config():
    print("[*] Sending initialization XML...")
    data = {'reqxml': config_xml}

    try:
        response = requests.post(API_URL, data=data, verify=False)
        print("[+] Response from Firewall:")
        print(response.text)
    except Exception as e:
        print(f"[!] Failed to push config: {e}")


if __name__ == "__main__":
    if wait_for_api():
        push_config()
    else:
        print("[!] Timeout: Firewall did not boot in time.")
        sys.exit(1)