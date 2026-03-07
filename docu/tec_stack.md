# Project Tech Stack

This document outlines the security architecture and tools selected for the university project setup. The stack is designed to provide a comprehensive "Defense in Depth" approach, covering network protection, active scanning, and centralized security monitoring.

## 1. Perimeter & Application Security

- **Firewall:** **Sophos Firewall (Home Edition)**
    
    - **Role:** Acts as the primary gateway for the environment. It handles network segmentation, traffic filtering (L3/L4), and intrusion prevention.
        
    - **Configuration Note:** Utilizing the Home Edition license, which provides the full enterprise feature set but is hardware-limited to 4 cores and 6 GB of RAM.
        
- **WAF (Web Application Firewall):** **Sophos Integrated WAF**
    
    - **Role:** Integrated module within the Sophos Firewall. It acts as a reverse proxy for the vulnerable web application to protect against SQLi, XSS, and other Layer 7 attacks.
        

## 2. Vulnerability Management (Scanning Tier)

We utilize a multi-layered scanning approach to identify vulnerabilities from discovery to exploitation:

- **Nmap:** Used for initial reconnaissance, port scanning, and service identification.
    
- **Nuclei:** A template-based scanner used for fast, targeted detection of specific CVEs and web misconfigurations.
    
- **OpenVAS (Greenbone):** Used for deep, comprehensive vulnerability assessments and reporting across the network and OS levels.
    

## 3. SIEM & Monitoring

- **SIEM/XDR:** **Wazuh**
    
    - **Role:** Centralized security hub. Wazuh agents are installed on the target and scanning hosts to collect logs, monitor file integrity (FIM), and detect anomalies or active threats.
        
    - **Integration:** All alerts from the scanning tier and system logs are aggregated into the Wazuh dashboard for analysis.
        

## 4. Target Environment

- **Vulnerable Application:** **OWASP Juice Shop**
    
    - **Role:** A deliberately insecure modern web application. It serves as the primary target for the vulnerability scanners and the WAF testing scenarios.
        

---

### Deployment Notes

- **Hardware Efficiency:** The Sophos Home Edition hardware limits (4 cores/6GB RAM) are respected and considered sufficient for this lab environment.
    
- **Scanning Workflow:** Scans are initiated via Nmap/Nuclei/OpenVAS, and the resulting traffic/attacks are monitored in real-time via the Sophos WAF and Wazuh SIEM.