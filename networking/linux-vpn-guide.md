# VPN Guide for Linux
## WireGuard, Cloudflare WARP, wgcf, Proton VPN Free, and Other Free VPN Solutions

![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![WireGuard](https://img.shields.io/badge/WireGuard-88171A?style=flat&logo=wireguard&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Maintained](https://img.shields.io/badge/maintained-yes-brightgreen.svg)
![Last Updated](https://img.shields.io/badge/updated-2026--07-informational)

> A distro-agnostic, terminal-first reference for running VPN tunnels on Linux — from raw WireGuard to Cloudflare WARP, wgcf, Proton VPN Free, Mullvad, and other free options. Written for intermediate-to-advanced Linux users who want to understand *why* a configuration works, not just copy-paste it.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [VPN Protocol Comparison](#2-vpn-protocol-comparison)
3. [WireGuard Deep Dive](#3-wireguard-deep-dive)
4. [Installing WireGuard](#4-installing-wireguard)
5. [Cloudflare WARP](#5-cloudflare-warp)
6. [Official Cloudflare WARP Client](#6-official-cloudflare-warp-client)
7. [Using wgcf](#7-using-wgcf)
8. [Proton VPN Free](#8-proton-vpn-free)
9. [Mullvad VPN](#9-mullvad-vpn)
10. [Other Good Free VPNs](#10-other-good-free-vpns)
11. [NetworkManager](#11-networkmanager)
12. [Systemd](#12-systemd)
13. [DNS](#13-dns)
14. [Security Best Practices](#14-security-best-practices)
15. [Performance Tuning](#15-performance-tuning)
16. [Verification](#16-verification)
17. [Troubleshooting](#17-troubleshooting)
18. [FAQ](#18-faq)
19. [Appendix](#19-appendix)

---

## 1. Introduction

### 1.1 What is a VPN?

A Virtual Private Network creates an encrypted, authenticated tunnel between your device and a remote endpoint (a "VPN server"). Once the tunnel is up, your operating system routes some or all of your IP traffic through it instead of sending it directly out your local interface. Two things happen as a result:

- **Confidentiality in transit**: anyone observing traffic between you and your ISP (the ISP itself, a coffee-shop Wi-Fi operator, a network intruder) sees only encrypted tunnel traffic, not your actual destinations or payloads.
- **Address substitution**: the sites and services you talk to see the VPN server's IP address, not your own.

A VPN does **not** make you anonymous by itself. It shifts trust from your local network operator to the VPN provider, which can, in principle, see the same metadata your ISP could (unless it has a genuinely audited no-logs policy). It also does nothing about browser fingerprinting, cookies, or logged-in accounts.

### 1.2 VPN vs Proxy

| Property | VPN | Proxy (HTTP/SOCKS) |
|---|---|---|
| Scope | Whole-system, all traffic (typically) | Per-application, only traffic configured to use it |
| Encryption | Yes, built into the protocol | Only if layered with TLS (HTTPS proxy) |
| Authentication | Mutual, cryptographic (keys/certs) | Often none, or basic auth |
| DNS handling | Usually tunnels DNS too | Usually leaves DNS on the local resolver |
| Kernel involvement | Often kernel-level (netdev, routing tables) | Userspace only |

A proxy is a relay for a specific protocol; a VPN is a network-layer tunnel. If an application does not explicitly support a proxy, a proxy will not protect it. A VPN protects everything that uses the kernel's routing table, including things you didn't think to configure.

### 1.3 VPN vs SSH Tunnel

An SSH tunnel (`ssh -D`, `ssh -L`, `ssh -R`) can approximate a VPN using SOCKS forwarding or port forwarding, and `sshuttle` can even push whole-system traffic through an SSH session without root on the remote end. But SSH tunnels:

- Are TCP-over-TCP when used for whole-tunnel forwarding, which causes "TCP meltdown" — retransmission timers stack on top of each other and throughput collapses on lossy links.
- Have no native concept of a persistent, roaming, low-overhead tunnel interface the way WireGuard does.
- Are excellent for quick, one-off access to a single internal service, and poor as a daily-driver full-tunnel VPN replacement.

WireGuard and OpenVPN both typically run tunnel encapsulation over UDP specifically to avoid the TCP-over-TCP problem.

### 1.4 VPN vs Tor

| Property | VPN | Tor |
|---|---|---|
| Path | Single hop (you → VPN server → destination) | Three hops (guard → middle → exit relay) |
| Trust model | Trust the VPN provider | Trust that no single relay operator sees both ends |
| Latency | Low | High (multiple encryption/decryption hops) |
| Operated by | One company | Thousands of independent volunteer relays |
| Typical use | Everyday privacy, geo-routing, network security | Strong anonymity, censorship circumvention, hostile network environments |

A VPN centralizes trust in one operator; Tor decentralizes it across relay operators who don't know each other. They solve different threat models and are sometimes combined (Tor-over-VPN or VPN-over-Tor), each with its own trade-offs that are outside the scope of this guide.

### 1.5 What WireGuard Is

WireGuard is a layer-3 VPN protocol and reference implementation created by Jason A. Donenfeld, designed to replace IPsec and OpenVPN with a much smaller, auditable, and faster codebase. It is built around:

- A single, fixed cryptographic suite (no negotiation, no cipher-suite downgrade attacks).
- The Noise Protocol Framework for its handshake.
- A minimal, mostly stateless design: no persistent session state beyond keys and a handful of timers.
- Kernel-space implementation for Linux (`wireguard.ko`, mainlined into the kernel since 5.6) for near–line-rate throughput.

### 1.6 Why WireGuard Became the Industry Standard

- **Code size**: roughly 4,000 lines of kernel code, versus OpenVPN/IPsec implementations that run to hundreds of thousands of lines across userspace daemons and kernel modules. Smaller code is easier to audit and has a smaller attack surface.
- **Modern cryptography by default**: ChaCha20-Poly1305, Curve25519, BLAKE2s, SipHash24 — no legacy cipher fallback to misconfigure.
- **Performance**: because it lives in the kernel and avoids the userspace/kernel context-switch overhead that plagues TUN/TAP-based OpenVPN, WireGuard consistently benchmarks faster and with lower CPU usage.
- **Simplicity**: configuration is a public key, an endpoint, and an allowed-IP list — no PKI, no certificate management, no TLS library dependency chain.
- **Roaming**: WireGuard doesn't care if your IP address changes (switching from Wi-Fi to LTE, for example); as soon as a valid encrypted packet arrives from a new address, it updates the peer's endpoint.

Every provider covered later in this guide (Cloudflare WARP, Proton VPN, Mullvad) either defaults to WireGuard or offers it as the recommended protocol, which is why this guide treats WireGuard as the foundation and layers provider-specific tooling on top.

---

## 2. VPN Protocol Comparison

| Protocol | Security | Performance | Battery usage | Code size | CPU usage | Latency | Best use case |
|---|---|---|---|---|---|---|---|
| **WireGuard** | Modern fixed cipher suite, minimal attack surface, formally analyzed handshake | Excellent — near line-rate on modern hardware | Low — connectionless roaming avoids reconnection churn | ~4K lines (kernel module) | Low | Low | Default choice for almost everything: desktops, phones, routers |
| **OpenVPN** | Strong when configured correctly (AES-256-GCM, TLS 1.3), but flexible negotiation surface increases misconfiguration risk | Good over UDP, poor over TCP | Higher — userspace daemon plus TLS renegotiation | ~100K+ lines | Moderate–high (userspace crypto, more syscalls) | Moderate | Networks that block UDP, or environments requiring TLS-based obfuscation |
| **IPsec/IKEv2** | Strong (mature, standardized, hardware-accelerated on many platforms) | Very good, especially with AES-NI acceleration | Low — native mobile OS integration handles roaming (MOBIKE) well | Large (kernel + userspace daemon: strongSwan, Libreswan) | Low with hardware AES-NI | Low | Mobile devices switching networks frequently; enterprise/site-to-site tunnels |
| **MASQUE** | Modern, built on QUIC/HTTP-3, TLS 1.3 underneath | Good, benefits from QUIC's 0-RTT and multiplexing | Moderate | Depends on QUIC library used | Moderate | Low–moderate | Environments where only HTTPS/443 UDP-QUIC egress is permitted (Cloudflare WARP's newer default) |
| **SSTP** | TLS-wrapped PPP; security is only as good as the underlying TLS config | Moderate | Higher (PPP overhead, Windows-oriented stack) | Large (proprietary Microsoft protocol) | Moderate | Moderate | Legacy Windows-centric corporate VPNs; rarely relevant on Linux |
| **L2TP/IPsec** | L2TP itself has no encryption; relies entirely on the IPsec layer. Widely considered legacy | Weaker — double encapsulation overhead | Higher | Large (two separate stacks glued together) | Higher (double encapsulation) | Higher | Legacy compatibility only; avoid for new deployments |

**Practical takeaway:** for a Linux desktop in 2026, WireGuard should be your default. Use IKEv2 only if a provider or corporate policy requires it and your platform has good MOBIKE support. Treat SSTP and L2TP/IPsec as compatibility-only legacy protocols — do not deploy them for new setups.

---

## 3. WireGuard Deep Dive

A WireGuard interface is described by an `.conf` file (or, when used through NetworkManager, an equivalent connection profile) split into an `[Interface]` section describing the local end, and one or more `[Peer]` sections describing remote parties.

```ini
[Interface]
PrivateKey = <local private key>
Address = 10.2.0.2/32
DNS = 10.2.0.1
MTU = 1420

[Peer]
PublicKey = <remote public key>
PresharedKey = <optional symmetric key>
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

### 3.1 Public keys and private keys

WireGuard uses Curve25519 for its Diffie–Hellman key exchange. Every peer (client or server) generates a **private key** (32 random bytes, clamped per the Curve25519 spec) and derives a **public key** from it via scalar multiplication on the curve. The private key never leaves the device that generated it; only the public key is shared with peers.

```bash
wg genkey | tee privatekey | wg pubkey > publickey
```

Because the public key is deterministically derived from the private key, WireGuard has no certificate authority, no certificate expiry, and no revocation lists — key rotation simply means generating a new keypair and exchanging the new public key out of band.

### 3.2 Peer model

WireGuard has no formal client/server hierarchy at the protocol level — every participant is a "peer" with a public key and a set of `AllowedIPs`. In practice, most deployments still have an asymmetric topology: one peer (the "server") has a public `Endpoint` and many peers connect to it, while client peers usually don't need a fixed `Endpoint` of their own because the server learns their address from incoming packets.

### 3.3 AllowedIPs

`AllowedIPs` serves two purposes simultaneously, which is a common source of confusion:

1. **Cryptographic routing / firewall**: on the receiving side, WireGuard drops any decrypted packet whose *source* address does not fall within the `AllowedIPs` configured for that peer. This prevents peer A from spoofing peer B's address.
2. **Routing table entries**: on the sending side, `wg-quick` inserts routes so that traffic destined for those prefixes goes out the WireGuard interface.

`AllowedIPs = 0.0.0.0/0, ::/0` means "route everything through this tunnel" (full tunnel) and simultaneously "accept packets claiming to originate from anywhere" from that peer. `AllowedIPs = 10.2.0.0/24` on a server peer entry means "only accept/route this specific client subnet from this specific peer" (split tunnel / site-to-site).

### 3.4 Endpoint

The `Endpoint` directive specifies the `host:port` a peer should be contacted at initially. It's optional for peers whose address is expected to be learned dynamically (e.g., a roadwarrior client connecting to a server). WireGuard performs standard DNS resolution once at startup for hostnames in `Endpoint` — it does **not** re-resolve on every packet, which matters if your VPN server's IP changes via dynamic DNS (you would need to `wg set` or restart the interface to pick up a new address).

### 3.5 PersistentKeepalive

Because WireGuard is a UDP protocol, stateful firewalls and NAT routers between you and the server will time out the mapping if no traffic flows for a while — and once that mapping is gone, the server can no longer reach you even though your side thinks the tunnel is up. `PersistentKeepalive = 25` tells WireGuard to send an empty keepalive packet every 25 seconds whenever no other traffic has been sent, which is enough to keep most NAT/firewall UDP mappings alive (which commonly expire between 30–300 seconds). Leave it unset on servers with a stable public IP that clients initiate to; set it on the client side, or on either side if both are behind NAT.

### 3.6 MTU

WireGuard adds framing overhead per packet: a 60-byte header for IPv4 tunnels (20-byte IP + 8-byte UDP + 32-byte WireGuard header), or more for IPv6 transport. If your underlying link MTU is 1500 (the Ethernet default), the tunnel MTU should be set below that to avoid fragmentation. WireGuard's default when unset is a conservative auto-calculation, but `wg-quick` typically settles around 1420 for IPv4 transport. Many WARP/wgcf profiles ship an MTU of 1280 specifically to survive additional PPPoE, tunneled, or double-NAT paths without fragmenting. See [§15 Performance Tuning](#15-performance-tuning) for how to tune this properly rather than guessing.

### 3.7 DNS

The `DNS =` line in `[Interface]` isn't a WireGuard protocol feature — it's a convenience implemented entirely by the `wg-quick` script, which calls out to `resolvconf`/`resolvectl`/`systemd-resolved` to point system DNS resolution at the specified server(s) while the tunnel is active, and restores the previous configuration on `wg-quick down`. If you bring up a WireGuard interface with raw `ip link`/`wg setconf` instead of `wg-quick`, you must manage DNS yourself. See [§13 DNS](#13-dns) for the full breakdown, including the resolvconf dependency gotcha most distros hit on a fresh install.

### 3.8 Routing

`wg-quick` derives its routing behavior directly from `AllowedIPs`:

- If `AllowedIPs` includes a default route (`0.0.0.0/0`), `wg-quick` avoids simply overwriting your existing default route (which would create a routing loop back into the tunnel) by instead creating a secondary routing table, adding the tunnel's default route there, and adding `ip rule` policy-routing entries so only non-VPN traffic uses the main table. This is the same fwmark/`ip rule` technique visible in `wg-quick`'s verbose output.
- If `AllowedIPs` lists specific subnets, ordinary routes are added for just those prefixes — no policy routing trickery needed.

### 3.9 Split tunnel vs full tunnel

- **Full tunnel**: `AllowedIPs = 0.0.0.0/0, ::/0`. All IPv4 and IPv6 traffic routes through the VPN. This is what you want for privacy-from-your-network-operator use cases (coffee shop Wi-Fi, hostile ISPs, geo-restriction bypass).
- **Split tunnel**: `AllowedIPs` restricted to specific subnets (e.g., a company's internal `10.0.0.0/8`). Only traffic destined for those subnets uses the tunnel; everything else uses your normal internet path. This is typical for corporate remote-access VPNs where you don't want to backhaul all your traffic through head office.

A common gotcha: if you want a full tunnel but still need to reach the VPN server itself without a routing loop, `wg-quick` handles this automatically by adding a specific host route to the endpoint via your original default gateway before installing the tunnel-wide default route.

---

## 4. Installing WireGuard

WireGuard has been part of the mainline Linux kernel since 5.6, so on any reasonably current distribution you only need the userspace tools (`wg`, `wg-quick`).

### 4.1 Arch Linux

```bash
sudo pacman -S wireguard-tools
```

`wireguard-tools` provides `wg` and `wg-quick`. The kernel module is already present in the Arch kernel package; no separate `wireguard-dkms` is needed on a current kernel.

### 4.2 openSUSE (Tumbleweed and Leap)

```bash
sudo zypper install wireguard-tools
```

Tumbleweed ships current kernels with the in-tree module already enabled, so, as with Arch, no DKMS package is required.

### 4.3 Fedora

```bash
sudo dnf install wireguard-tools
```

### 4.4 Debian

```bash
sudo apt update
sudo apt install wireguard wireguard-tools
```

On Debian, the `wireguard` metapackage pulls in `wireguard-tools` plus (on older kernels) `wireguard-dkms`. On Debian 11+ with a current kernel this is largely redundant since the module is upstream, but the metapackage keeps working across kernel version boundaries.

### 4.5 Ubuntu

```bash
sudo apt update
sudo apt install wireguard
```

Ubuntu 20.04 and later ship the in-kernel module; `wireguard-tools` is pulled in as a dependency.

### 4.6 `wg` vs `wg-quick`

- **`wg`** is the low-level configuration tool: it can show current state (`wg show`), or set configuration directly against an already-created network interface (`wg setconf`, `wg set`). It does not create interfaces, manage routes, or touch DNS.
- **`wg-quick`** is a shell script wrapper that: creates the interface (`ip link add ... type wireguard`), loads the config via `wg setconf`, assigns addresses, sets the MTU, installs routes (including the split-default-route trick from §3.8), and manages DNS via `resolvconf`/`resolvectl`. This is what almost everyone should use for a single always-on or on-demand tunnel.

```bash
sudo wg-quick up wg0      # bring up /etc/wireguard/wg0.conf
sudo wg-quick down wg0
wg show                   # inspect handshake times, transfer counters, endpoints
```

### 4.7 systemd service

`wireguard-tools` installs a templated systemd unit, `wg-quick@.service`, so any config dropped at `/etc/wireguard/<name>.conf` can be managed as a service named after it:

```bash
sudo systemctl enable --now wg-quick@wg0
sudo systemctl status wg-quick@wg0
```

See [§12 Systemd](#12-systemd) for the full service-management workflow, including logs and boot-time ordering.

### 4.8 NetworkManager integration

If you prefer a GUI-managed connection (recommended for laptops that need DNS/route state to interact cleanly with other NetworkManager-managed connections, like Wi-Fi), NetworkManager has native WireGuard support (`nm-connection-editor`, `nmcli`, or KDE's `plasma-nm`) rather than relying on `wg-quick`. See [§11 NetworkManager](#11-networkmanager) for import and configuration details.

> **Tip:** Don't run both `wg-quick@wg0.service` and a NetworkManager-imported connection for the same interface name — pick one management method per tunnel to avoid the two fighting over routes and DNS.

---

## 5. Cloudflare WARP

### 5.1 What WARP is

WARP is Cloudflare's consumer client that routes your device's traffic through Cloudflare's edge network, originally built on top of the WireGuard protocol and now defaulting to Cloudflare's MASQUE (QUIC-based) transport on recent client versions. Its original design goal was to be a faster, more private replacement for your ISP's default DNS and routing path — riding on Cloudflare's global anycast network of data centers.

### 5.2 What WARP is NOT

- It is **not** a traditional privacy VPN with per-country exit-server selection. On the free consumer client, you cannot pick which country your traffic egresses from — Cloudflare selects the nearest edge location for performance.
- It is **not** intended for geo-unblocking or bypassing region-locked streaming content.
- It is **not** a no-logs anonymity service in the same sense as Mullvad; Cloudflare's own worldwide network sees your traffic in order to route and cache it (subject to their privacy policy and third-party audits), and the free tier of the plain consumer client does log connection metadata for abuse prevention and performance purposes.

### 5.3 WARP vs VPN

Cloudflare itself describes the WARP client as a tunnel to Cloudflare's network for performance and security filtering, most explicitly aimed at corporate device management through **Cloudflare One** (formerly Cloudflare for Teams) rather than at anonymizing home users. <cite index="7-1">The Cloudflare WARP client allows you to protect corporate devices by securely and privately sending traffic from those devices to Cloudflare's global network, where Cloudflare Gateway can apply advanced web filtering.</cite> The consumer 1.1.1.1 app repackages the same underlying client for individual users who mainly want faster, more private DNS plus a general-purpose tunnel — not full VPN-style anonymity.

### 5.4 WARP Free vs WARP+

- **WARP (free)**: unlimited data, routes you through the nearest Cloudflare edge, encrypts DNS and traffic to that edge — but does not materially accelerate your path beyond that point.
- **WARP+**: a paid add-on that additionally routes your traffic over Cloudflare's private backbone (Argo Smart Routing) for the "last mile" between the Cloudflare edge and the actual destination, generally improving latency and throughput on long-haul routes.

### 5.5 MASQUE and WireGuard mode

Cloudflare has been migrating the default WARP transport from WireGuard to **MASQUE**, a QUIC/HTTP-3–based tunneling protocol that traverses restrictive networks (which often permit UDP/443 QUIC but block arbitrary WireGuard UDP ports) more reliably, and benefits from QUIC's connection migration and 0-RTT resumption. You can switch the transport manually with the CLI:

```bash
warp-cli tunnel protocol set MASQUE     # default on recent clients
warp-cli tunnel protocol set WireGuard  # fall back if MASQUE has issues
```

### 5.6 Privacy implications

Using WARP means Cloudflare — already one of the largest observers of global internet traffic through its CDN and DNS resolver business — additionally sees your device-level traffic. If your threat model already includes distrust of large centralized internet infrastructure providers, WARP is not a meaningful privacy upgrade over your ISP; if your threat model is "protect me from a hostile local network / captive portal / opportunistic snooping," WARP is a reasonable, free, low-effort choice.

### 5.7 Performance

Because WARP peers you with the nearest anycast Cloudflare data center (of which there are hundreds worldwide), latency to Cloudflare-fronted sites is often excellent. Non-Cloudflare-fronted destinations see performance roughly equivalent to your normal ISP path, occasionally worse due to added encapsulation overhead, occasionally better if Cloudflare's backbone routing beats your ISP's peering.

### 5.8 Official client vs wgcf

| | Official `cloudflare-warp` client | `wgcf` (community tool) |
|---|---|---|
| Maintained by | Cloudflare | ViRb3 (community, unofficial) |
| Transport | MASQUE (default) or WireGuard | WireGuard only |
| Output | Managed daemon + `warp-cli` | Plain `.conf` WireGuard profile you manage yourself |
| Portability | Linux client is somewhat heavyweight (background daemon, GUI dependencies on some distros) | Just a WireGuard config — works anywhere `wg-quick`/NetworkManager does, including routers |
| Feature surface | DNS filtering modes (families/malware), Zero Trust enrollment, proxy mode | Registration, profile generation, Warp+ license linking — nothing else |
| Best for | Desktop users who want the full feature set and don't mind a background service | Headless servers, routers, minimal systems, or anyone who wants a plain WireGuard profile under their own tunnel management |

**Advantages of the official client:** built-in DNS filtering modes, GUI/tray integration on supported distros, officially supported upgrade path, Zero Trust/Teams enrollment.

**Disadvantages of the official client:** heavier dependency footprint (especially the tray/GUI on RHEL-family distros, which needs EPEL for its webview dependencies), a background `warp-svc` daemon, and the CLI's own quirks around registration state.

**Advantages of wgcf:** produces a portable, ordinary WireGuard config you can manage with the same tools (`wg-quick`, NetworkManager, systemd) you already use for every other tunnel in this guide, and it can be used with the WireGuard *kernel module* directly for maximum performance rather than going through a userspace MASQUE client.

**Disadvantages of wgcf:** unofficial and dependent on reverse-engineered API endpoints that Cloudflare could change without notice; WireGuard-only, so it can't use MASQUE; no DNS filtering modes or Zero Trust integration.

---

## 6. Official Cloudflare WARP Client

### 6.1 Installation — Debian/Ubuntu

```bash
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt-get update && sudo apt-get install cloudflare-warp
```

<cite index="3-1">The public key requires updating if it was installed before 2025-09-12</cite> — if you set this up a while ago and the repository suddenly 404s or GPG-check fails, re-run the key-import step above with `--yes` to force overwrite the old keyring file.

### 6.2 Installation — Fedora / RHEL family

```bash
sudo rpm -e 'gpg-pubkey(4fa1c3ba-61abda35)' 2>/dev/null # optional, only if reinstalling
sudo rpm --import https://pkg.cloudflareclient.com/pubkey.gpg
sudo tee /etc/yum.repos.d/cloudflare-warp.repo <<'EOF'
[cloudflare-warp]
name=Cloudflare WARP
baseurl=https://pkg.cloudflareclient.com/rpm
enabled=1
gpgcheck=1
gpgkey=https://pkg.cloudflareclient.com/pubkey.gpg
EOF
sudo dnf install cloudflare-warp
```

> **Note:** <cite index="5-1">On RHEL 9 and later, enable the Extra Packages for Enterprise Linux (EPEL) repository (`sudo dnf install epel-release`) before installing cloudflare-warp</cite> — EPEL supplies GUI/tray webview dependencies the package needs.

### 6.3 Installation — Arch Linux (AUR)

There is no official Arch repository; use the AUR:

```bash
yay -S cloudflare-warp-bin
sudo systemctl enable --now warp-svc
```

### 6.4 Installation — openSUSE

openSUSE isn't in Cloudflare's officially supported list. The two workable options are:
1. Extract the Debian `.deb` package manually with `alien` or `ar`/`tar`, or
2. Skip the official client entirely and use `wgcf` (§7), which is arguably the more natural fit on openSUSE anyway given the absence of official repo support.

### 6.5 First-time registration and connection

```bash
warp-cli registration new     # creates an anonymous device registration
warp-cli connect
curl -s https://www.cloudflare.com/cdn-cgi/trace/ | grep warp   # expect: warp=on
```

### 6.6 Core `warp-cli` commands

```bash
warp-cli status                       # current connection state
warp-cli disconnect
warp-cli connect
warp-cli mode --help                  # list available modes
warp-cli mode warp                    # standard full-tunnel mode
warp-cli mode doh                     # DNS-over-HTTPS only, no tunneling
warp-cli mode proxy                   # local SOCKS5 proxy mode instead of system-wide tunnel
warp-cli dns families malware         # block known malware domains
warp-cli dns families full            # malware + adult content filtering
warp-cli dns families off             # disable family filtering
warp-cli tunnel protocol set MASQUE   # switch transport
warp-cli tunnel protocol set WireGuard
warp-cli registration show            # inspect current account/device
warp-cli registration delete          # de-register this device
```

### 6.7 Switching modes: DNS-only vs full tunnel vs proxy

- **`warp` mode** — full system tunnel (default, closest to a typical VPN experience).
- **`doh` mode** — only encrypts DNS resolution via DNS-over-HTTPS to Cloudflare's `1.1.1.1`; does not tunnel general traffic. Useful if you specifically want private DNS without routing everything through Cloudflare's network.
- **`proxy` mode** — runs a local SOCKS5 proxy (default `127.0.0.1:40000`) that applications can be pointed at individually, rather than a system-wide tunnel.

### 6.8 Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `warp-cli` hangs or errors with no daemon response | `warp-svc` not running | `sudo systemctl enable --now warp-svc` |
| Repository 404 / GPG errors on apt update | Stale keyring predating the 2025-09-12 key rotation | Re-run the key import step in §6.1 |
| RHEL install fails on missing tray/webview deps | Missing EPEL | `sudo dnf install epel-release` then retry |
| `curl .../trace` shows `warp=off` after connect | Registration didn't complete, or MASQUE blocked on this network | `warp-cli registration show`; try `warp-cli tunnel protocol set WireGuard` |
| Registration hangs at "Checking your organization configuration" | Known IPC issue on some recent client builds | Reboot the system; retry registration |

---

## 7. Using wgcf

### 7.1 What wgcf is

`wgcf` (by ViRb3) is an unofficial, open-source CLI that talks to Cloudflare's WARP registration API and exports the result as a **plain WireGuard configuration file** — no Cloudflare daemon, no proprietary transport, just a `.conf` you hand to `wg-quick` or NetworkManager like any other WireGuard tunnel.

### 7.2 How it works

`wgcf` registers a new anonymous device against Cloudflare's WARP backend (the same API the official mobile/desktop apps use), receives a keypair and tunnel addresses, and writes:

- `wgcf-account.toml` — your account credentials/license (keep this private and back it up).
- `wgcf-profile.conf` — the resulting WireGuard client profile.

### 7.3 Register an account

```bash
wgcf register
```

> **Warning:** <cite index="17-1">If you have an existing account, you will need to delete it and create a new one</cite> rather than re-registering in place — this is a known behavior across recent `wgcf` releases, not a bug in your setup.

### 7.4 Generate a WireGuard profile

```bash
wgcf generate
```

<cite index="17-1">The WireGuard profile will be saved under wgcf-profile.conf</cite>, ready to use with the standard [WireGuard Quick Start](https://www.wireguard.com/quickstart/) workflow.

### 7.5 Importing with wg-quick

```bash
sudo cp wgcf-profile.conf /etc/wireguard/wgcf.conf
sudo wg-quick up wgcf
```

### 7.6 Importing with NetworkManager

```bash
sudo nmcli connection import type wireguard file wgcf-profile.conf
nmcli connection up wgcf-profile
```

### 7.7 Autostart

```bash
sudo systemctl enable --now wg-quick@wgcf
```

(Use the NetworkManager `autoconnect` option instead if you imported via `nmcli` — see §11.)

### 7.8 Updating your profile / checking status

```bash
wgcf status    # displays account/device info, format changed in recent releases
wgcf update    # refresh the account's device list / license
wgcf trace     # print Cloudflare trace output confirming warp=on or warp=plus
```

### 7.9 Migrating to WARP+

If you already own a WARP+ subscription (purchased through the official 1.1.1.1 mobile app), you can bind `wgcf`'s generated device to that subscription and inherit WARP+ status:

1. Run `wgcf register` at least once to create `wgcf-account.toml`.
2. Open `wgcf-account.toml` and replace the `license_key` value with the license key shown in the 1.1.1.1 mobile app under your account.
3. Run `wgcf update` to apply the change, then `wgcf generate` again to regenerate the profile.

<cite index="17-1">Please note that there is a limit of a maximum of 5 active linked devices</cite> per WARP+ subscription.

### 7.10 MTU tuning

<cite index="17-1">To ensure maximum compatibility, the generated profile will have a MTU of 1280, just like the official Android app. If you are experiencing performance issues, you may be able to improve your speed by increasing this value.</cite> If your local link supports standard 1500-byte Ethernet frames end-to-end without additional encapsulation (no PPPoE, no nested VPN, no unusual carrier NAT), you can typically raise this to 1420–1440 safely. See [§15 Performance Tuning](#15-performance-tuning) for the methodology to find your actual ceiling instead of guessing.

### 7.11 DNS options

`wgcf-profile.conf` ships with `DNS = 1.1.1.1, 2606:4700:4700::1111` by default (Cloudflare's own public resolver), which `wg-quick` applies via `resolvconf`/`resolvectl` while the tunnel is up.

### 7.12 The resolvconf / wg-quick DNS gotcha (openSUSE and others)

A very common first-run failure on a fresh openSUSE, Debian, or Arch installation:

```
[#] resolvconf -a wgcf -m 0 -x
/usr/bin/wg-quick: line 32: resolvconf: command not found
[#] ip link delete dev wgcf
```

This happens because `wg-quick`'s DNS-handling code path (`set_dns()`) hard-depends on a `resolvconf`-compatible binary being on `$PATH` whenever a config contains a `DNS =` line, and many minimal installs — including a base openSUSE Tumbleweed install — don't ship one by default. On distros using `systemd-resolved`, the fix is to install the `openresolv` package, which provides a `resolvconf` shim that talks to `resolvectl`/`systemd-resolved` correctly:

```bash
# openSUSE
sudo zypper install openresolv

# Debian/Ubuntu
sudo apt install openresolv

# Arch
sudo pacman -S openresolv
```

Community reports on Debian have found that installing the raw `resolvconf` package (as opposed to `openresolv`) can conflict with `systemd-resolved` and actively break DNS resolution system-wide, while `openresolv` integrates cleanly. If you'd rather not add the dependency at all, simply delete or comment out the `DNS =` line in the profile and set your resolver globally (via NetworkManager or `/etc/resolv.conf`) instead — `wg-quick` only invokes the resolvconf code path when that directive is present.

---

## 8. Proton VPN Free

### 8.1 What is available on the free plan

Proton VPN's free tier is unusually generous among free VPNs: <cite index="24-1">Proton VPN Free plan offers unlimited bandwidth and is free for you to use forever</cite>, with <cite index="27-1">no time, speed, or data limits</cite> and the same encryption and no-logs policy as paid tiers. <cite index="30-1">Proton VPN's free version allows users to access servers in ten countries: Canada, Japan, Mexico, the Netherlands, Norway, Poland, Romania, Singapore, Switzerland, and the United States.</cite>

### 8.2 Limitations

- <cite index="30-1">Users cannot choose which server to connect to; they can only use one device at a time</cite> on the free tier — the app auto-selects a free-tier server for you.
- <cite index="27-1">You can use BitTorrent on Proton VPN to share files safely and securely if you're on a paid plan</cite> — P2P is a paid-tier feature only.
- Free servers are shared among more users than paid servers, so real-world throughput during peak hours can be noticeably lower than on Plus servers, even though there's no artificial cap.
- Streaming-service unblocking is <cite index="27-1">only guaranteed on paid plans (Proton VPN Plus, Proton Unlimited, or Proton Visionary)</cite>; free servers aren't blocked outright but aren't guaranteed to work either.
- Advanced features — <cite index="24-1">Secure Core and NetShield ad/malware/tracker blocking</cite> — are paid-only.

### 8.3 Available countries

As of the most recent roadmap update, the free tier covers ten locations. <cite index="21-1">The server locations you can use have traditionally been the Netherlands, Japan, Romania, Poland, and the United States, but you can now connect on most platforms to five more countries worldwide, bringing the total number of free countries to 10.</cite>

### 8.4 Linux installation (GUI app)

<cite index="25-1">The Proton VPN app officially supports Debian, Ubuntu, and Fedora.</cite> Installation is via `.deb`/`.rpm` packages or a distro-provided repository (check `protonvpn.com/download-linux` for the current package URLs, since these are versioned and change often).

```bash
# Debian/Ubuntu example
sudo dpkg -i ./protonvpn-stable-release_*.deb
sudo apt update
sudo apt install proton-vpn-gnome-desktop     # GNOME-integrated GUI client
```

```bash
# Fedora example
sudo dnf install ./protonvpn-stable-release_*.rpm
sudo dnf install proton-vpn-gnome-desktop
```

Arch users generally rely on the community-maintained AUR packages, since Proton doesn't officially support Arch.

### 8.5 CLI

Recent Proton VPN roadmaps note that <cite index="21-1">a Linux CLI</cite> is part of the currently planned/rolling-out feature set alongside more free server locations. <cite index="25-1">Our official (v4) Linux doesn't yet support a command line tool</cite> historically was the case for the modern rewritten client, so check Proton's current Linux download page for whether the CLI has reached your distro before scripting around it — this is one of the fastest-moving parts of the Proton VPN Linux stack.

### 8.6 GUI

<cite index="25-1">Intuitive graphical user interface with a one-click Quick Connect button</cite>, plus manual server/country selection on paid tiers.

### 8.7 Kill switch

<cite index="25-1">Proton VPN for Linux has both a kill switch and a permanent kill switch. When you turn the kill switch on, Proton VPN disables the internet if your VPN connection is interrupted to hide your real IP address. When you turn the permanent kill switch on, your internet connection is blocked all the time unless you're connected to a VPN server.</cite>

### 8.8 Auto-connect

The GUI app supports launching and reconnecting automatically on system boot/network change; consult the in-app settings, since exact menu paths shift between releases.

### 8.9 WireGuard and OpenVPN support

Proton VPN uses <cite index="24-1">the WireGuard® and OpenVPN protocols at their strongest encryption settings</cite>. You can also bypass the official app entirely: <cite index="22-1">you can connect to the Proton VPN servers on any Linux system by manually configuring OpenVPN or WireGuard</cite> using config files generated from your Proton account dashboard — useful for routers, minimal servers, or troubleshooting.

### 8.10 Manual WireGuard configuration example

```ini
[Interface]
PrivateKey = <your generated private key>
Address = 10.2.0.2/32
DNS = 10.2.0.1

[Peer]
PublicKey = <server public key from your Proton dashboard>
Endpoint = <server-hostname>.protonvpn.net:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

Generate the keypair and download a matching config from Proton's dashboard under Downloads → WireGuard configuration, selecting your desired platform and (on paid tiers) server.

---

## 9. Mullvad VPN

Mullvad is a paid-only, privacy-first VPN frequently cited as a reference point for "how a privacy VPN should operate," even though it has no free tier. It's included here because it's the natural upgrade path once the free options in this guide stop meeting your needs, and because its account model and Linux support are genuinely different from the mainstream competition.

### 9.1 Why it's considered one of the best paid privacy VPNs

- <cite index="35-1">Mullvad VPN is one of the few VPNs that prioritizes extreme anonymity: it uses a random account number instead of an email address, accepts cash payments by mail, and has maintained a flat rate of €5 per month since 2009.</cite>
- <cite index="35-1">Audited four times by Cure53 (most recently in June 2024)</cite>, with additional third-party assurance reports.
- <cite index="38-1">As of the 15th January 2026, Mullvad ended OpenVPN support in favour of WireGuard</cite> exclusively — a strong signal about which protocol the industry now treats as the default.

### 9.2 Account model

<cite index="39-1">Users can generate a 16-digit account number as their only login credential — the Mullvad VPN app does not require an email or password for account creation.</cite> You then "top up" that account number with time. Payment options include <cite index="36-1">cash by mail, Bitcoin, Bitcoin Cash, and Monero</cite>, alongside conventional card/PayPal.

### 9.3 Pricing

<cite index="36-1">Mullvad charges a flat €5 per month (~$5.40 USD) with no annual or multi-year plans; every user pays the same price regardless of subscription length, with no introductory discounts and no renewal price hikes.</cite>

### 9.4 WireGuard and Linux support

<cite index="37-1">Mullvad's Linux support stands out — the Linux app is fully featured, not a stripped-down afterthought, including the GUI, kill switch, and DAITA support.</cite> For users who prefer to skip the official app, <cite index="38-1">you can manually set up a Mullvad VPN connection with WireGuard</cite> using their key-generation page and a shell script (`mullvad-wg.sh`) that automates fetching per-server config files once you supply your account number.

```bash
sudo apt-get install curl jq openresolv wireguard
curl -o mullvad-wg.sh https://raw.githubusercontent.com/mullvad/mullvad-wg.sh/main/mullvad-wg.sh
sh mullvad-wg.sh   # prompts for your account number, writes configs to /etc/wireguard
```

> **Note:** the auto-generated configs from this script intentionally omit a kill switch (a hard nftables/iptables block that only allows traffic once the tunnel is up) — add one yourself if you rely on the script instead of the official app, which includes a kill switch by default.

---

## 10. Other Good Free VPNs

| Provider | Advantages | Disadvantages | Privacy | Bandwidth limits | Linux support |
|---|---|---|---|---|---|
| **Proton VPN Free** | Unlimited bandwidth, audited no-logs, open-source apps, WireGuard/OpenVPN | Single device, no server choice, no P2P | Strong — Swiss jurisdiction, third-party audited | None | Official Debian/Ubuntu/Fedora packages |
| **Cloudflare WARP** | Effectively unlimited, extremely easy to set up, low latency to Cloudflare-fronted sites | Not a privacy VPN in the traditional sense, no country selection, corporate-focused design | Cloudflare sees your traffic (subject to their published privacy commitments) | None advertised | Official native Linux client + community `wgcf` route |
| **Riseup VPN** | Run by a long-standing digital-rights collective, simple OpenVPN-based client, strong activist/community trust | Small server footprint, modest speeds, limited country choice | Strong stated privacy ethos, non-commercial operator | Practically unlimited for personal use | OpenVPN config works with any Linux OpenVPN client |
| **Windscribe Free** | Generous feature set relative to most free tiers (ad/tracker blocking, split tunneling), decent number of free locations | Explicit monthly data cap on the free tier, restricted server list vs paid | Independent audits published; Canadian jurisdiction | Capped (a fixed monthly GB allowance, size varies by promotion) | Official Linux CLI client available |
| **TunnelBear Free** | Very beginner-friendly UI/UX, published security audits | Small hard data cap that most users will exhaust quickly, historically weaker Linux support than Windows/macOS | Independently audited, McAfee-owned corporate structure | Hard capped (small fixed monthly allowance) | Limited — historically no first-party native Linux app; manual OpenVPN/WireGuard config or third-party tools needed |

**Guidance:** if you want *unlimited*, low-effort, and reasonably private, start with **Proton VPN Free**. If you specifically want the fastest possible route to Cloudflare-fronted infrastructure and don't need anonymity from Cloudflare itself, **WARP** is essentially frictionless. If you're specifically supporting grassroots/activist infrastructure and don't need high throughput, **Riseup** is worth considering. **Windscribe** and **TunnelBear** are reasonable if you only need occasional, low-volume, capped use.

---

## 11. NetworkManager

NetworkManager has first-class WireGuard support (no plugin required on current versions), letting you manage tunnels the same way you manage Wi-Fi and Ethernet — with a unified GUI, `nmcli`, and consistent DNS/routing behavior alongside your other connections.

### 11.1 Importing a WireGuard profile

```bash
nmcli connection import type wireguard file /path/to/profile.conf
```

This works identically whether the `.conf` came from `wg genkey`/manual authoring, `wgcf generate`, or a provider dashboard export (Proton, Mullvad, etc.).

### 11.2 Managing graphically

- **GNOME**: Settings → Network → "+" → import a saved VPN or WireGuard configuration, or use `nm-connection-editor`.
- **KDE Plasma**: System Settings → Network → Connections, which uses `plasma-nm` as a frontend to the same NetworkManager WireGuard backend.

### 11.3 Autoconnect

```bash
nmcli connection modify <connection-name> connection.autoconnect yes
```

### 11.4 DNS

```bash
nmcli connection modify <connection-name> ipv4.dns "10.2.0.1"
nmcli connection modify <connection-name> ipv4.ignore-auto-dns yes
nmcli connection modify <connection-name> ipv4.dns-priority -1
```

Setting a negative DNS priority tells NetworkManager to treat this connection's DNS servers as authoritative over any other active connection's DNS settings — this is the standard way to guarantee DNS goes through the tunnel and not, say, your Wi-Fi router's DHCP-provided resolver, which is the classic cause of DNS leaks under split-DNS setups (see [§13.6](#136-split-dns)).

### 11.5 Split tunnel via NetworkManager

NetworkManager's WireGuard GTK/CLI settings expose per-peer `AllowedIPs` directly. To restrict a peer to a subnet instead of a full tunnel:

```bash
nmcli connection modify <connection-name> +wireguard-peer.allowed-ips "10.0.0.0/8"
```

(Exact property paths can shift slightly between NetworkManager versions — check `nmcli connection show <name>` for the currently exposed `wireguard-peer.*` properties on your installed version.)

---

## 12. Systemd

If you manage WireGuard purely through `wg-quick` rather than NetworkManager, `systemd` is your service manager of choice.

### 12.1 Enable

```bash
sudo systemctl enable wg-quick@wg0.service       # start on boot
sudo systemctl enable --now wg-quick@wg0.service # enable and start immediately
```

### 12.2 Disable

```bash
sudo systemctl disable --now wg-quick@wg0.service
```

### 12.3 Status

```bash
systemctl status wg-quick@wg0.service
```

### 12.4 Logs / journalctl

```bash
journalctl -u wg-quick@wg0.service --no-pager       # full unit history
journalctl -u wg-quick@wg0.service -b --no-pager     # since last boot only
journalctl -u wg-quick@wg0.service -f                # follow live
```

### 12.5 Common template-unit gotchas

- The unit is a **template** (`wg-quick@.service`), so the instance name after `@` must exactly match the config file's basename in `/etc/wireguard/` (without the `.conf` extension) — `wg-quick@wg0` looks for `/etc/wireguard/wg0.conf`.
- Config files must be `chmod 600` and owned by root; `wg-quick` and the unit will refuse to run (or silently expose your private key) otherwise.
- If both a NetworkManager connection and a `wg-quick@` unit reference the same interface name, disable one — they will race to create/destroy the same network interface.

---

## 13. DNS

### 13.1 DNS leaks

A DNS leak occurs when your system continues sending DNS queries outside the VPN tunnel — to your ISP's resolver, for instance — even though your general traffic is correctly tunneled. This defeats a large part of the privacy benefit of the VPN, since your ISP (or any on-path observer) still sees every domain you resolve. Leaks typically happen because:

- The tunnel's `DNS =` directive was silently ignored (missing `resolvconf`, see §7.12).
- A second active network connection's DHCP-provided DNS servers are still prioritized over the tunnel's.
- `systemd-resolved` is configured in a way that doesn't route per-interface DNS as expected.

### 13.2 Cloudflare DNS

`1.1.1.1` / `1.0.0.1` (and IPv6 `2606:4700:4700::1111` / `::1001`). Fast, widely peered, and the default resolver baked into most `wgcf` profiles.

### 13.3 Quad9

`9.9.9.9` / `149.112.112.112`. Blocks known-malicious domains at the resolver level by default and does not sell query data; a solid privacy-and-security-focused alternative to Cloudflare's resolver.

### 13.4 Mullvad DNS

Mullvad runs its own resolvers reachable only from inside the tunnel (commonly `10.64.0.1` for WireGuard connections), which avoids leaking DNS to any third party outside Mullvad itself.

### 13.5 Proton DNS

Proton VPN similarly routes DNS to an internal resolver (`10.2.0.1` in the manual config example in §8.10) reachable only over the tunnel, keeping resolution inside Proton's own infrastructure while connected.

### 13.6 Split DNS

Split DNS means different DNS servers answer for different domains — for example, an internal corporate VPN might resolve `*.corp.example.com` via an internal resolver while everything else uses the tunnel's general-purpose resolver (or even your normal ISP resolver, if the tunnel is itself a split tunnel). NetworkManager supports this through per-connection domain-routing configuration; `systemd-resolved` supports it natively via routing domains (`~example.com`).

### 13.7 DNS over HTTPS (DoH)

DoH wraps DNS queries in HTTPS, making them indistinguishable from ordinary web traffic to a network observer and encrypting the query contents. Cloudflare WARP's `doh` mode (§6.7) is a pure DoH implementation; you can also configure DoH independently of any VPN via `systemd-resolved`'s `DNSOverTLS`/upstream provider settings, or a local DoH-to-plain-DNS proxy like `cloudflared` or `dnscrypt-proxy`.

### 13.8 DNS over TLS (DoT)

DoT runs the standard DNS wire protocol over a dedicated TLS-encrypted connection (port 853) instead of tunneling it inside HTTPS. `systemd-resolved` supports DoT natively:

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/dot.conf <<'EOF'
[Resolve]
DNS=9.9.9.9#dns.quad9.net
DNSOverTLS=yes
EOF
sudo systemctl restart systemd-resolved
```

---

## 14. Security Best Practices

### 14.1 Kill switch

A kill switch is a firewall rule set that blocks all non-tunnel traffic the instant the VPN interface goes down, preventing any accidental unencrypted leak during a drop or reconnect. A minimal `nftables` kill switch for a full-tunnel WireGuard interface named `wg0`:

```nft
table inet killswitch {
    chain output {
        type filter hook output priority 0; policy drop;
        oifname "wg0" accept
        oifname "lo" accept
        meta skuid 0 accept        # allow root (needed to bring wg-quick itself up)
        udp dport 51820 accept     # allow the WireGuard handshake packet itself
        ct state established,related accept
    }
}
```

Load it with `sudo nft -f killswitch.nft`, and only remove/flush it once you intend to run without the tunnel entirely.

### 14.2 Firewall

Independent of a kill switch, keep a default-deny inbound firewall (`nftables`/`firewalld`/`ufw`) on the tunnel interface itself, especially on split-tunnel setups where the local network is still directly reachable.

### 14.3 IPv6

A very common real-world leak: a full-tunnel WireGuard config that only sets `AllowedIPs = 0.0.0.0/0` (IPv4 only) while the host still has a working IPv6 default route outside the tunnel. Any IPv6-capable destination will then be reached directly, bypassing the VPN entirely. Always include `::/0` in `AllowedIPs` for full-tunnel setups, or explicitly disable IPv6 system-wide if the tunnel/provider doesn't support it:

```bash
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
```

### 14.4 WebRTC leaks

Browsers implementing WebRTC (for video calls, P2P features) can enumerate your real local and, in some configurations, public IP addresses via STUN, independent of your system-level VPN routing, because WebRTC's ICE candidate gathering happens at the browser/application layer. Mitigations: disable WebRTC in browsers that don't need it, or use browser extensions/settings that restrict ICE candidates to the VPN-assigned interface only (e.g., Firefox's `media.peerconnection.ice.default_address_only` and `media.peerconnection.ice.no_host` preferences).

### 14.5 Time sync

Accurate system time matters for VPN security in two ways: TLS certificate validation (used by MASQUE, OpenVPN's TLS handshake, and provider account portals) fails on badly skewed clocks, and some providers rate-limit or reject handshakes with excessive clock drift. Keep `systemd-timesyncd` or `chronyd` enabled and syncing.

### 14.6 PersistentKeepalive

Covered in depth in §3.5 — set it (typically `25` seconds) whenever either endpoint sits behind NAT, which is the common case for any home or mobile client connecting to a cloud-hosted server.

### 14.7 Kernel updates

Because WireGuard on Linux runs as an in-kernel module for performance, keeping your kernel current matters more than it would for a purely userspace VPN client — kernel security fixes (including any future WireGuard-adjacent networking-stack CVEs) only reach you through a kernel update, not an app update.

---

## 15. Performance Tuning

### 15.1 MTU optimization

Rather than guessing an MTU value, measure it with `ping`'s do-not-fragment flag, working from the outside-tunnel path:

```bash
ping -M do -s 1472 -c 3 8.8.8.8   # 1472 + 28 (ICMP+IP header) = 1500 total
```

Reduce the `-s` value in steps of 10–20 until packets stop fragmenting/dropping, to find your true outer-path MTU. Then compute the WireGuard interface MTU as `outer_MTU - 80` (a safe overhead estimate covering IP/UDP/WireGuard framing for IPv4 transport; subtract a little more if your transport path is IPv6 or has extra encapsulation like double-NAT/PPPoE).

```ini
[Interface]
MTU = 1420   # example result for a standard 1500-byte-MTU ISP link
```

### 15.2 Benchmarking

```bash
iperf3 -s                 # on the remote/server side
iperf3 -c <server-ip>     # from the client, over the tunnel interface
```

Compare tunnel throughput against a direct (non-tunneled) `iperf3` run to quantify overhead honestly, rather than assuming all slowdown is the VPN's fault — plenty of it can be your baseline link or the remote server's own load.

### 15.3 CPU usage

```bash
top -p $(pgrep -d, -f wireguard)     # if a userspace fallback is in use
mpstat 1                              # general per-core utilization while under load
```

On a modern kernel with the in-tree module, CPU usage from WireGuard itself should be minimal — most systems bottleneck on the underlying network link or the remote endpoint long before WireGuard's crypto becomes the limiting factor. Elevated CPU tied to `wg`-related processes on Linux more often indicates you're accidentally running a userspace WireGuard implementation (e.g., `boringtun`) rather than the kernel module.

### 15.4 Latency

```bash
mtr <destination>         # combined traceroute+ping, run both through and around the tunnel to isolate where added latency comes from
```

### 15.5 Choosing servers

For any provider offering multiple locations (Proton VPN Plus, Mullvad), prefer the geographically nearest server with acceptable load, unless your specific goal is a particular exit country. Run a quick round-trip comparison before committing to a server for latency-sensitive use (gaming, calls):

```bash
for host in de-fra nl-ams us-nyc; do
  echo -n "$host: "; ping -c 3 "$host.example-provider.net" | tail -1
done
```

---

## 16. Verification

### 16.1 Public IP

```bash
curl -s https://ifconfig.me
curl -s https://api.ipify.org
```

Confirm the returned address matches your VPN provider's exit IP range, not your ISP's.

### 16.2 DNS

```bash
curl -s https://www.cloudflare.com/cdn-cgi/trace/ | grep -E 'ip=|loc='
```

Also cross-check via a purpose-built DNS-leak test site accessed through the tunnel, and compare its reported resolver(s) against your provider's expected DNS server.

### 16.3 Tunnel

```bash
ip addr show wg0
ip route show table all | grep wg0
```

### 16.4 WireGuard status

```bash
sudo wg show
```

Look for a recent "latest handshake" timestamp (should update roughly every ~2 minutes under WireGuard's default rekey timers) and non-zero transfer counters to confirm the tunnel is actively carrying traffic, not just "up" at the interface level.

### 16.5 Cloudflare WARP status

```bash
warp-cli status
curl -s https://www.cloudflare.com/cdn-cgi/trace/ | grep warp
```

### 16.6 Proton VPN status

Check the app's connection indicator, or, for manual WireGuard setups, use the same `wg show` / `curl ifconfig.me` checks as any other WireGuard tunnel.

### 16.7 IPv6

```bash
curl -6 -s https://ifconfig.me
```

If this fails outright while IPv4 works, either your tunnel doesn't carry IPv6 (fine, as long as you've also disabled local IPv6 per §14.3) or something is misconfigured and leaking IPv6 outside the tunnel — verify which with:

```bash
ip -6 route show
```

### 16.8 DNS leaks

Run a DNS-leak test with the tunnel active, and manually verify with:

```bash
resolvectl status
```

Confirm the "Current DNS Server" for your tunnel interface matches the provider's expected resolver, and that it is not silently falling back to another interface's DNS.

---

## 17. Troubleshooting

### 17.1 Handshake problems

**Symptom:** `wg show` never shows a "latest handshake" timestamp.

- Confirm outbound UDP on the configured port isn't blocked by a local or upstream firewall.
- Double-check both sides' public keys are correctly paired (a common copy-paste error is reversing which key goes on which side).
- If the server's IP address changed since your `Endpoint` was resolved, restart the interface so `wg-quick` re-resolves the hostname.

### 17.2 DNS failures

See the full breakdown in §7.12 for the classic `resolvconf: command not found` failure. More generally:

```bash
resolvectl status         # confirm which resolver is active on which interface
cat /etc/resolv.conf      # sanity-check against what resolvectl reports
```

### 17.3 Permission denied

WireGuard interface creation and private-key handling require root. Always run `wg-quick`/`wg` via `sudo`, and ensure config files are `chmod 600 /etc/wireguard/*.conf` — overly open permissions on files containing private keys is both a security problem and, on some setups, a cause of `wg-quick` refusing to load them.

### 17.4 AppArmor

If a distro ships an AppArmor profile that restricts `wg-quick`, `resolvconf`, or NetworkManager's plugin, denials show up in the audit log rather than as an obvious application error:

```bash
sudo journalctl -k | grep -i apparmor
sudo aa-status
```

A denial for a path your tunnel legitimately needs (commonly around `/etc/resolv.conf` or `/run/systemd/resolve/`) means the profile needs a local override rather than the package itself being broken — check `/etc/apparmor.d/local/` for the correct override file naming convention on your distro before editing the shipped profile directly.

### 17.5 SELinux

On Fedora/RHEL-family systems with SELinux enforcing, denials appear via `ausearch`/`sealert`:

```bash
sudo ausearch -m avc -ts recent
sudo sealert -a /var/log/audit/audit.log
```

`sealert` will typically also suggest the exact `audit2allow` policy module to generate if the denial is a legitimate false positive rather than a real security concern.

### 17.6 Firewall

```bash
sudo nft list ruleset          # nftables
sudo iptables -L -n -v         # legacy iptables, if still in use
sudo firewall-cmd --list-all   # firewalld
```

Confirm the WireGuard UDP port is allowed outbound, and that any kill-switch rules (§14.1) aren't blocking legitimate DNS/handshake traffic you actually need.

### 17.7 NetworkManager

```bash
nmcli connection show
nmcli device status
journalctl -u NetworkManager -b
```

A WireGuard connection stuck in "activating" state with no error is often a DNS-priority conflict with another active connection (§11.4) or a peer `AllowedIPs` value that creates a routing conflict with an existing route.

### 17.8 wg-quick

```bash
sudo wg-quick up wg0     # run directly (not via systemd) to see verbose step-by-step output and the exact failing command
```

### 17.9 MTU / fragmentation

**Symptom:** small requests (DNS, initial TLS handshake) succeed, but larger transfers stall or hang.

This is the classic fingerprint of an MTU set too high for the actual path. Follow the measurement procedure in §15.1 rather than trial-and-error.

### 17.10 Routing loops

**Symptom:** the tunnel comes up but nothing routes anywhere, or a specific destination becomes completely unreachable.

Usually caused by a manually-added default route conflicting with the `ip rule`/fwmark policy routing `wg-quick` installs automatically for full-tunnel configs (§3.8). Inspect with:

```bash
ip rule show
ip route show table 51820   # wg-quick's typical policy-routing table number
```

### 17.11 No internet

Checklist, in order:
1. `wg show` — is the tunnel actually established (recent handshake, nonzero transfer)?
2. `ip route` — is a default route actually pointing at the tunnel (or, for split tunnel, are your intended destinations covered)?
3. `resolvectl status` — is DNS resolving at all?
4. `curl -v https://1.1.1.1` — bypass DNS entirely to isolate whether the problem is routing or resolution.

### 17.12 Slow speeds

Work through §15 (Performance Tuning) systematically — MTU, then raw `iperf3` throughput, then CPU, then server choice — rather than changing several variables simultaneously.

---

## 18. FAQ

1. **Do I need a VPN if I only use HTTPS sites?** HTTPS protects the content of your traffic, but a VPN also hides *which* sites you're contacting (from your ISP/local network) and hides your IP from the destination.
2. **Is WireGuard slower than OpenVPN?** No — in essentially every independent benchmark, WireGuard outperforms OpenVPN, often substantially, due to its kernel-space implementation and simpler cryptographic handshake.
3. **Can I run multiple WireGuard tunnels at once?** Yes, each as its own interface (`wg0`, `wg1`, ...), but routing them to different destinations simultaneously requires careful `AllowedIPs`/policy-routing planning to avoid conflicts.
4. **Does WireGuard support TCP?** No, WireGuard is UDP-only by design; if a network blocks UDP entirely, you'll need a protocol like OpenVPN-over-TCP or a QUIC-based option like WARP's MASQUE mode instead.
5. **What happens if my WireGuard private key leaks?** An attacker could potentially decrypt past traffic they've already captured only if you don't use a preshared key layer and depending on the specific data involved; more importantly, they could impersonate you to the peer until you rotate the key — rotate immediately.
6. **Is Cloudflare WARP a real VPN?** It functions as a tunnel with encryption and IP substitution, so in the mechanical sense yes, but its design intent and default feature set (no country selection, corporate Zero Trust focus) differ from a traditional consumer privacy VPN.
7. **Is wgcf legal to use?** It uses Cloudflare's existing public WARP registration API in the same way official apps do; it isn't sanctioned or maintained by Cloudflare and could break if that API changes, but using it isn't inherently different from using an alternate official client.
8. **Why does Proton VPN Free only let me pick a country sometimes?** Free-tier server selection has evolved over time; check Proton's current documentation, since the free tier's country list and selection UI have both expanded and changed recently.
9. **Can I torrent on Proton VPN Free?** No — P2P/BitTorrent support is restricted to paid Proton VPN tiers.
10. **Does Mullvad have a free trial?** No traditional free trial, though some sources note a money-back guarantee window; check Mullvad's current terms directly, as guarantee policies change.
11. **Why did Mullvad drop OpenVPN?** As of January 2026, Mullvad moved to WireGuard exclusively, reflecting the broader industry shift toward it as the default modern VPN protocol.
12. **What's the difference between `wg` and `wg-quick`?** `wg` is the low-level key/config tool; `wg-quick` is a shell wrapper that also creates interfaces, manages routes, and manages DNS.
13. **Do I need `resolvconf` installed for WireGuard to work at all?** No — only if your config includes a `DNS =` directive that `wg-quick` needs to apply; omit that line and you can skip the dependency entirely.
14. **What MTU should I use?** There's no universal answer — measure your path with the do-not-fragment ping method in §15.1 rather than copying a number from a forum post.
15. **Is a kill switch necessary?** For anyone relying on the VPN specifically to avoid a hostile local network, yes; for pure geo-routing or convenience use, it's optional but still good practice.
16. **Can WireGuard leak my real IP?** Only through misconfiguration — most commonly a missing `::/0` entry for IPv6 (§14.3), or DNS resolving outside the tunnel (§13.1).
17. **Does using a VPN protect me from malware?** No — a VPN encrypts and reroutes network traffic; it does nothing about malicious files, phishing, or compromised endpoints, aside from optional DNS-based filtering some providers offer (e.g., WARP's `dns families` modes).
18. **Why does my WireGuard handshake work but no traffic flows?** Check `AllowedIPs` on both sides carefully — a mismatch there is the most common cause of "handshake succeeds, nothing routes."
19. **Can I use WireGuard and NetworkManager for the same tunnel as `wg-quick`?** Not simultaneously for the same interface — pick one management path per tunnel.
20. **Is Cloudflare WARP free forever?** The free WARP tier has no advertised expiration; WARP+ is the paid performance add-on layered on top of it.
21. **Do I need a static IP to run a WireGuard server?** No, but if your server's address changes frequently, clients need to either use dynamic DNS for the `Endpoint` or manually refresh their config on change.
22. **What's `PersistentKeepalive` for exactly?** Keeping NAT/firewall UDP mappings alive between you and the server so inbound packets can still reach you (§3.5).
23. **Does MASQUE replace WireGuard entirely for Cloudflare WARP?** It's the new default transport for the official client, but you can still force WireGuard mode via `warp-cli tunnel protocol set WireGuard`.
24. **Can I self-host my own VPN instead of using a provider?** Yes — a small cloud VPS running plain WireGuard server-side gives you full control, at the cost of managing your own uptime, IP reputation, and updates.
25. **Is a VPS-hosted WireGuard server as private as a dedicated no-log provider?** It shifts trust to your cloud provider and your own operational security instead of a VPN company — neither is automatically "more private," it depends on your specific threat model.
26. **What does "split tunnel" actually protect?** Only the traffic you explicitly route through the tunnel; everything else uses your normal path unprotected, so it's a deliberate performance/access trade-off, not a security shortcut.
27. **Why do some sites block known VPN exit IPs?** Providers' IP ranges are widely known and sometimes blocklisted by services trying to prevent abuse/fraud or enforce geo-restrictions — this is unrelated to your VPN's actual security.
28. **Does a VPN protect me on public Wi-Fi?** Yes, this is one of its strongest use cases — it prevents other devices on that same local network, or the network operator, from intercepting your traffic.
29. **How do I know if my VPN provider actually enforces a no-logs policy?** Look for independent, published third-party audits (as both Proton and Mullvad have undergone) rather than relying on marketing language alone.
30. **Should I leave PersistentKeepalive on all the time, even without NAT?** It's harmless bandwidth-wise (tiny empty packets) but unnecessary if both peers have stable, directly reachable addresses; it's mainly there to counteract NAT/firewall timeout behavior.
31. **Can I run WireGuard inside a container?** Yes, but it typically needs `NET_ADMIN` capability and, depending on your container runtime's network mode, direct access to `/dev/net/tun` or the kernel WireGuard module — rootless containers add extra complexity here.
32. **Why does `wg show` sometimes show a handshake but zero bytes transferred?** The handshake itself is control-plane traffic; zero data bytes just means no actual application traffic has flowed yet, which is normal immediately after connecting.

---

## 19. Appendix

### 19.1 Useful commands cheat sheet

```bash
# Keys
wg genkey | tee privatekey | wg pubkey > publickey

# Bring tunnel up/down (wg-quick)
sudo wg-quick up wg0
sudo wg-quick down wg0

# Inspect state
sudo wg show
sudo wg show wg0 latest-handshakes
sudo wg show wg0 transfer

# systemd
sudo systemctl enable --now wg-quick@wg0
sudo systemctl status wg-quick@wg0
journalctl -u wg-quick@wg0 -f

# NetworkManager
nmcli connection import type wireguard file profile.conf
nmcli connection up profile
nmcli connection modify profile connection.autoconnect yes

# Cloudflare WARP
warp-cli registration new
warp-cli connect
warp-cli status
warp-cli disconnect

# wgcf
wgcf register
wgcf generate
wgcf status
wgcf trace

# Verification
curl -s https://ifconfig.me
curl -s https://www.cloudflare.com/cdn-cgi/trace/
resolvectl status
ip route show table all
```

### 19.2 Common file paths

| Path | Purpose |
|---|---|
| `/etc/wireguard/<name>.conf` | WireGuard interface configuration, consumed by `wg-quick`/the `wg-quick@` systemd template |
| `/etc/systemd/resolved.conf.d/*.conf` | Drop-in overrides for `systemd-resolved` (DoT, custom resolvers) |
| `/etc/NetworkManager/system-connections/` | NetworkManager connection profiles, including imported WireGuard tunnels |
| `~/.config/wgcf/` or the working directory | `wgcf-account.toml` and `wgcf-profile.conf` output from `wgcf` |
| `/etc/yum.repos.d/cloudflare-warp.repo` | RPM-based repository definition for the official Cloudflare WARP client |
| `/etc/apt/sources.list.d/cloudflare-client.list` | APT repository definition for the official Cloudflare WARP client |

### 19.3 Configuration file examples

**Minimal full-tunnel client:**

```ini
[Interface]
PrivateKey = <client private key>
Address = 10.0.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = <server public key>
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

**Split-tunnel client (only route an internal subnet):**

```ini
[Interface]
PrivateKey = <client private key>
Address = 10.0.0.2/32

[Peer]
PublicKey = <server public key>
Endpoint = vpn.example.com:51820
AllowedIPs = 10.0.0.0/24
```

**Minimal server side:**

```ini
[Interface]
PrivateKey = <server private key>
Address = 10.0.0.1/24
ListenPort = 51820

[Peer]
PublicKey = <client public key>
AllowedIPs = 10.0.0.2/32
```

### 19.4 Glossary

- **AllowedIPs** — per-peer prefix list controlling both cryptographic packet filtering and route installation.
- **DAITA** — Mullvad's traffic-shaping feature intended to defeat traffic-analysis attacks by padding/timing obfuscation.
- **DoH / DoT** — DNS-over-HTTPS / DNS-over-TLS, encrypted DNS transports.
- **Full tunnel** — routing all traffic through the VPN (`AllowedIPs = 0.0.0.0/0, ::/0`).
- **Kill switch** — firewall rules blocking non-tunnel traffic if the VPN drops.
- **MASQUE** — QUIC/HTTP-3–based tunneling protocol, Cloudflare WARP's current default transport.
- **MTU** — Maximum Transmission Unit; the largest packet size a link can carry without fragmentation.
- **Peer** — any WireGuard participant identified by a public key.
- **PersistentKeepalive** — periodic empty packets that keep NAT/firewall UDP mappings alive.
- **Split tunnel** — routing only specific subnets through the VPN, leaving the rest on the normal path.
- **wg-quick** — shell script wrapper around `wg` that also manages interface creation, routes, and DNS.
- **wgcf** — unofficial CLI that generates a plain WireGuard profile from a Cloudflare WARP account.

### 19.5 Useful links

- WireGuard official site and quick start: https://www.wireguard.com/quickstart/
- WireGuard whitepaper: https://www.wireguard.com/papers/wireguard.pdf
- Cloudflare WARP client docs: https://developers.cloudflare.com/warp-client/
- Cloudflare WARP package repository: https://pkg.cloudflareclient.com/
- `wgcf` (ViRb3): https://github.com/ViRb3/wgcf
- Proton VPN Linux download page: https://protonvpn.com/download-linux
- Proton VPN free plan details: https://protonvpn.com/free-vpn
- Mullvad help center (WireGuard tag): https://mullvad.net/en/help/tag/wireguard
- Mullvad `mullvad-wg.sh` script: https://github.com/mullvad/mullvad-wg.sh
- ArchWiki: WireGuard: https://wiki.archlinux.org/title/WireGuard
- ArchWiki: Mullvad: https://wiki.archlinux.org/title/Mullvad

---

*Part of the [`clean-system-guide`](https://github.com/itachi-re/clean-system-guide) repository. Contributions and corrections welcome via pull request.*
