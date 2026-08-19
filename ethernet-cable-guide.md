# How to Read an Ethernet Cable: Cat5 to Cat8 and Everything Printed on the Jacket

A practical, standards-grounded guide to understanding ethernet cable categories, labels, and construction — so you can judge a cable yourself instead of trusting a listing.

**Sources used:** ANSI/TIA-568 (TIA-568.2-D, TIA-568-C.2-1), ISO/IEC 11801, IEEE 802.3 (802.3an, 802.3bq, 802.3bt), Fluke Networks knowledge base and application notes, NEC Article 800 (jacket/fire ratings), and manufacturer/cabling-industry technical writeups (Fluke, trueCABLE, Cablify, AMPCOM, Blackbox, CRXCONEC, Allied Wire & Cable). Retailer listings are used only for label examples in Section 17, never as the source of technical claims.

---

## 1. The Basics

**What is an Ethernet cable?**
A cable with four twisted pairs of copper wires (8 wires total) inside a jacket, terminated with 8P8C connectors (commonly called "RJ45"). It carries data between your PC, router, switch, and other network gear over a physical wire instead of Wi-Fi.

**What does "Cat" mean?**
"Cat" = **Category**. It's a performance grade defined by cabling standards — mainly **ANSI/TIA-568** in North America and **ISO/IEC 11801** internationally. A category number is a *promise about electrical performance* (how much interference the cable resists, how much signal it loses over distance, how high a frequency it can carry cleanly) — not a brand name or a marketing tier.

**What does the number after Cat mean?**
Each number is a specific published revision of the standard, each stricter than the last: Cat5 → Cat5e ("enhanced") → Cat6 → Cat6A ("Augmented") → Cat7/Cat7A (ISO only) → Cat8. Higher number = tighter manufacturing tolerances, tighter twists, more crosstalk control, and a higher certified frequency.

**Category vs. actual speed — these are not the same thing.**
A category is tested and rated for a **frequency** (in MHz). Ethernet standards (IEEE 802.3) then specify which categories are the *minimum* required to reliably run a given speed over a given distance. The category doesn't transmit at "10 Gbps" by itself — it's a channel capacity rating that different Ethernet protocols use.

**Does a higher Cat number automatically mean faster Internet?**
No — for two separate reasons:
1. Your **Internet speed** is set by your ISP connection (modem/fiber ONT/plan), not your LAN cable. A Cat8 cable will not make a 100 Mbps internet plan faster.
2. Even for **local network speed**, the cable is only one link in a chain (see Section 12). A Cat6A cable plugged into a Gigabit-only router port will still run at 1 Gbps, not 10 Gbps.

**Does buying Cat7 or Cat8 make sense for a normal home PC?**
Almost never. As you'll see in Sections 19–20, Cat7 isn't even a recognized TIA standard, and Cat8 is designed for 30-meter data-center server-to-switch links at frequencies your home hardware doesn't use. For a home PC, **Cat6 or Cat6A** covers essentially every realistic use case for the next decade.

### Five things people mix up

```text
Cable category      → the performance grade/standard a cable is manufactured and tested to (Cat5e, Cat6…)
Cable bandwidth      → the frequency range in MHz that category is certified to carry cleanly
Ethernet link speed  → the negotiated speed between two connected NICs/ports (e.g., 1 Gbps)
Internet speed       → what your ISP actually delivers to your router (separate from LAN speed entirely)
Cable construction   → the physical build: AWG, shielding, copper purity, stranded/solid, jacket
```

They're related — a higher category *usually* enables higher Ethernet speeds at longer distances, and good construction is *required* for a cable to actually meet its printed category — but none of them determines the others by itself. A cable can be printed "Cat6" and still fail to deliver Cat6 performance if the construction is bad (see Section 6 on CCA). A "10 Gbps" internet plan is meaningless if your switch port only does 1 Gbps.

---

## 2. Every Major Ethernet Category

| Category | Standard body | Bandwidth | Practical Ethernet speed | Max distance for that speed | Shielding | Connector | Typical use | Buy it? |
|---|---|---|---|---|---|---|---|---|
| **Cat5** | Legacy TIA (obsolete) | 100 MHz | 10/100 Mbps reliably; Gigabit unofficial/unreliable | 100 m | Unshielded | RJ45 | Legacy installs only | **No** — no longer sold/made new |
| **Cat5e** | TIA-568 | 100 MHz | 1 Gbps | 100 m | Usually unshielded (U/UTP) | RJ45 | Basic home/office gigabit | OK for tight budgets |
| **Cat6** | TIA-568 | 250 MHz | 1 Gbps to 100 m; 10 Gbps up to ~37–55 m (bundle-dependent) | 100 m (1G) / ~55 m (10G) | U/UTP common, shielded variants exist | RJ45 | Home/office gigabit, short 10G runs | **Good default choice** |
| **Cat6A** | ANSI/TIA-568.2-D | 500 MHz | 10 Gbps | 100 m (full channel) | U/UTP or shielded (F/UTP, S/FTP) | RJ45 | 10GbE at full distance, PoE++ | **Best all-around for future-proofing** |
| **Cat7** | ISO/IEC 11801 Class F (not TIA) | 600 MHz | 10 Gbps (same as Cat6A in practice) | 100 m | Always shielded (S/FTP typical) | GG45/TERA (not RJ45) per spec | Niche EU/industrial; consumer "Cat7" cables use RJ45 (non-standard) | **Skip for home use** |
| **Cat7A** | ISO/IEC 11801 Class FA (not TIA) | 1000 MHz | 10 Gbps (same practical ceiling) | 100 m | Always shielded | GG45/TERA | Broadband/CATV distribution, niche | **Skip** |
| **Cat8** | ANSI/TIA-568.2-D / ISO 11801-1 | 2000 MHz | 25/40 Gbps | **30 m only** (2-connector channel) | Always shielded | RJ45 (Class I) or non-RJ45 (Class II) | Data-center server-to-switch/top-of-rack | **No** for home use |

Key nuance worth flagging up front: Cat6 at 10 Gbps is real but distance-limited by *alien crosstalk* between bundled cables — Cat6A was specifically created to fix that by adding mandatory alien-crosstalk testing (PSANEXT/PSAACR-F) and doubling bandwidth to 500 MHz, which is why Cat6A reaches the full 100 m at 10G where plain Cat6 typically can't.

### Where each category is actually useful

| Use case | Recommended category |
|---|---|
| Home users, general browsing/streaming | Cat5e or Cat6 |
| Gaming PC | Cat6 (Cat6A if you want headroom) |
| NAS (network storage) | Cat6A if the NAS/switch support 2.5G/10G |
| 1 GbE | Cat5e or Cat6 |
| 2.5 GbE / 5 GbE | Cat5e technically works over short runs, but Cat6 is the sane real-world minimum |
| 10 GbE | Cat6 (short runs) or Cat6A (full 100 m, recommended) |
| Enterprise networking | Cat6A is the current TIA standard baseline for new installs |
| Data centers (server-to-switch, ≤30 m) | Cat8 |

---

## 3. Reading the Label on the Jacket

Real cable jackets print a compact string of codes. Here are three realistic examples:

```text
CAT6 U/UTP 23AWG 4PR 100% COPPER 250MHz
CAT6 UTP 24AWG 4PR
CAT6 S/FTP 23AWG LSZH 500MHz
```

Breaking every token down:

| Token | Meaning | Good / Bad / Depends |
|---|---|---|
| `CAT6` | Category the cable claims to meet | Meaningless on its own — everything else on the label tells you if the claim is credible |
| `U/UTP` | Unshielded overall, unshielded pairs (see Section 5) | Depends — fine for home use, not for high-EMI environments |
| `23AWG` | Wire gauge — thicker conductor (see Section 4) | Generally good for Cat6/6A, better for PoE and long runs |
| `4PR` | 4 twisted pairs (8 conductors) | Standard — should always be 4PR for real Ethernet cable |
| `100% COPPER` | Solid/bare copper conductors, not CCA | **Good** — the single most important phrase to look for |
| `250MHz` | Certified bandwidth matching Cat6's spec | Good — confirms the Cat6 claim rather than just asserting it |
| `LSZH` | Low Smoke Zero Halogen jacket (see Section 10) | Good for indoor/enclosed spaces, safety-oriented |
| `CM` / `CMR` / `CMP` | Fire/installation rating (see Section 10) | Depends on where you're installing it |

Notice the second example — `CAT6 UTP 24AWG 4PR` — has **no copper claim and no frequency rating**. That's not automatically fraudulent, but it's a label giving you less to verify against, which is itself a signal to look closer (check the manufacturer's datasheet, weight, price).

---

## 4. AWG — Wire Gauge, Explained Properly

**AWG (American Wire Gauge)** is a standardized scale for conductor thickness. Critically, **the scale is inverted**: a *smaller* AWG number means a *thicker* wire. This trips people up constantly.

- **23 AWG** — thicker conductor. Common in Cat6/Cat6A cable, especially solid-core installation cable.
- **24 AWG** — the traditional Cat5e/Cat6 standard patch-cable gauge.
- **26 AWG** — thinner, common in slim/flexible stranded patch cables.
- **28 AWG** — very thin, used in ultra-slim patch cables and some short device cords.

**Why does thickness matter?** A thicker conductor has lower electrical resistance, which means less signal attenuation (loss) over distance, less voltage drop, and less heat under load — all of which matter most for **long cable runs** and **PoE**, where real current is flowing through the copper, not just a data signal.

**Is thicker always better?** No — thicker wire is stiffer, harder to route, and adds cost with no benefit if your run is short and there's no PoE involved. There's a real trade-off between conductor thickness and cable flexibility.

**AWG vs. resistance/PoE/flexibility/durability — practical comparison:**

| AWG | Resistance | Flexibility | PoE suitability | Best for |
|---|---|---|---|---|
| 23 AWG | Lowest | Stiffest | Best | Permanent wall/in-conduit runs, long PC cables, PoE cameras/APs |
| 24 AWG | Low | Moderate | Very good | General-purpose patch cables, most home use |
| 26 AWG | Moderate | Flexible | OK for short PoE runs | Short/medium patch cables, cable management-heavy setups |
| 28 AWG | Highest | Most flexible | Weak — avoid for PoE if run is long | Very short device cords, ultra-slim routing |

**Recommendations for your scenarios:**
- **Permanent home wiring (in-wall):** 23 AWG solid core.
- **A 20 m PC cable:** 23 or 24 AWG — don't go below 24 AWG at that length.
- **Short patch cables (under 2 m):** 26–28 AWG is fine; the run is too short for resistance to matter much.
- **PoE cameras:** 23 AWG strongly preferred, especially for anything beyond ~20 m or higher-wattage PoE+/PoE++.
- **Wi-Fi access points:** Same logic as cameras — thicker gauge if the AP is PoE-powered and the run is long.
- **Long Ethernet runs (30–100 m):** 23 AWG, ideally solid core.

---

## 5. Shielding: UTP / FTP / STP / SFTP and Friends

The shielding code is written as **`X/YTP`**, where the two letters mean two *different* things:

```text
Position before the slash → overall cable shield (around ALL 4 pairs together)
Position after the slash  → shield around EACH INDIVIDUAL pair

U = Unshielded
F = Foil shield
S = Braided screen (heavier-duty shield)
TP = Twisted Pair (always present)
```

So:

| Code | Overall shield | Per-pair shield | Common name |
|---|---|---|---|
| **U/UTP** | None | None | Fully unshielded — most common consumer cable |
| **F/UTP** | Foil around all 4 pairs | None | "FTP" in casual use |
| **U/FTP** | None | Foil around each pair | Less common |
| **S/UTP** | Braided screen overall | None | Screened unshielded |
| **S/FTP** | Braided screen overall | Foil per pair | Heavy shielding — common in Cat6A/Cat7 |
| **F/FTP** | Foil overall | Foil per pair | Double-foil |

A simple mental diagram:

```text
U/UTP:   [ pair ] [ pair ] [ pair ] [ pair ]              (no shield anywhere)
F/UTP:   ( foil around: [pair][pair][pair][pair] )        (one shield, whole bundle)
S/FTP:   ( braid around: (foil[pair]) (foil[pair]) (foil[pair]) (foil[pair]) )  (shield on every pair AND the bundle)
```

**Answering the common questions:**
- **Does shielding improve internet speed?** No. It has nothing to do with your ISP connection, and no direct effect on LAN throughput either — it improves *signal integrity/reliability* under interference, which indirectly matters if interference would otherwise cause errors and retransmissions.
- **Does shielding reduce interference?** Yes — that's specifically what it's for: rejecting electromagnetic interference (EMI) from motors, fluorescent ballasts, power lines, other cable bundles, etc.
- **When is shielding actually useful?** Runs near electrical conduit, industrial/commercial environments, dense cable bundles carrying 10G+ (alien crosstalk), or outdoor runs.
- **Does shielded cable need grounding?** Yes — a shield only works correctly if it's properly grounded at (typically) one end through shielded connectors, shielded keystone jacks/patch panels, and a bonded rack/enclosure.
- **What happens if shielded cable is used incorrectly (ungrounded or badly grounded)?** It can perform *worse* than unshielded cable — an improperly grounded shield can act as an antenna and introduce noise, or create ground loops.
- **Is shielded cable necessary inside a normal house?** No, for the vast majority of home installs — household EMI levels are low, and U/UTP Cat6/Cat6A is standard practice.
- **Is U/UTP Cat6 enough for a gaming PC?** Yes, comfortably.
- **When should you choose S/FTP?** Commercial/industrial installs, dense conduit runs, near heavy electrical equipment, or when a 10GbE Cat6A install needs guaranteed alien-crosstalk protection in a large bundle.

**Bottom line: more shielding is not automatically "better" — it's a tool for a specific interference problem, and it adds cost, stiffness, and a grounding requirement most home users don't need.**

---

## 6. Copper vs. CCA — the Most Important Section

**Solid/bare copper (100% copper):** the conductor is copper all the way through. This is what every ANSI/TIA and ISO/IEC category standard actually requires.

**CCA (Copper-Clad Aluminum):** an aluminum core with a thin copper coating on the outside.

**CCS (Copper-Clad Steel):** a steel core with a copper coating — even less conductive, mainly seen in some coax/specialty cable, rare in Ethernet.

### Why CCA exists and why it's marketed as Cat5e/Cat6

Aluminum is much cheaper than copper, so CCA cable costs manufacturers significantly less to produce. Many sellers print "Cat6," a UL mark, and TIA-compliance language on CCA cable anyway — testing and industry sources describe this directly as **non-compliant, and in some cases counterfeit marking**: <cite index="47-1,47-2">CCA cable "claims TIA-568-C compliance, includes the UL listing mark and even has a ETL verification legend printed right on the cable," but "if the cable is made with CCA and claims standards compliance, it could be counterfeit cable, and that means the UL mark is likely unauthorized."</cite>

### Is CCA actually standards-compliant category cable?

No. <cite index="52-1,52-2">A major difference is that CCA cable "is not approved for Ethernet networking usage by any regulatory body," and "any supposed compliance claims are false — only stranded or solid copper conductor cables are approved for Ethernet data cabling."</cite> Fluke Networks' own lab testing found the same thing from the electrical side: <cite index="46-1,46-2">"Data from the field suggests that CCA cable fails DC Resistance Unbalance, regardless of length" — a parameter defined in ANSI/TIA, ISO/IEC, and IEEE standards — and when Fluke tested a CCA cable, "the DC Resistance Unbalance" came back "clearly out of specification."</cite>

### The technical problems, one by one

- **Higher resistance:** <cite index="48-1">Aluminum has roughly 60% of copper's conductivity, so CCA has significantly higher resistance</cite> — commonly cited around 40–60% higher DC resistance than solid copper at the same gauge.
- **Signal loss / attenuation:** <cite index="50-1">CCA has higher attenuation than pure copper, resulting in a greater loss of data as packets have to be re-transmitted, and the longer the cable, the worse the problem compounds.</cite>
- **Voltage drop & heating:** <cite index="59-1">Expect more attenuation, higher heat rise under PoE, and shorter stable distances for 2.5/5/10G with CCA.</cite>
- **PoE problems:** <cite index="53-1">PoE and PoE+ may work intermittently with CCA, but higher resistance causes increased heat buildup at the conductors, and PoE++ (60 W) is described as unreliable with CCA.</cite> One vendor summary goes further: <cite index="55-1">industry professionals have reported insulation melting and cables smoking in PoE++ systems delivering over 60 watts when CCA was used.</cite>
- **Mechanical durability:** aluminum is more brittle than copper and fatigues/breaks more easily when flexed or re-terminated repeatedly.
- **Termination problems:** aluminum oxidizes differently than copper (its oxide is non-conductive, unlike copper oxide), which can degrade connections at punch-downs and RJ45 crimps over time.
- **Long-distance reliability:** resistance and attenuation problems get worse with every added meter, so CCA is *especially* bad for the long runs where good copper matters most.
- **Code/legal concerns:** in jurisdictions using the NEC, <cite index="60-1">Article 800.179 states that "conductors in communications cables, other than coaxial, shall be copper,"</cite> so a CCA cable installed as permanent structured cabling may not even be code-legal, independent of performance.

### Why "Cat6" printed on a cable doesn't guarantee it's real Cat6

The word "Cat6" on a jacket is a manufacturer's *claim*, not a certification the cable has actually passed. Nothing stops a factory from printing a category name on cheap CCA cable — there is no packet inspecting jacket text at the border. The only way to know for sure is either (a) independent lab/field certification with a tool like a Fluke DSX CableAnalyzer, or (b) buying from a manufacturer with enough reputation and liability exposure that mislabeling would be commercially costly.

### How to spot suspicious CCA cable before buying

- **Price is far below other "Cat6" listings of similar length** — CCA is the most common reason.
- **Label omits conductor material entirely** (no "copper," "bare copper," "100% copper," or "CCA" stated at all) — reputable cable states this explicitly; omission is a yellow flag.
- **Cable is unusually light for its length and gauge** — aluminum is much less dense than copper, so a CCA reel weighs noticeably less than a solid-copper reel of the same length/AWG.
- **A cheap magnet test is not reliable** (neither copper nor aluminum is magnetic) — but if you can strip a bit of insulation and the wire is dull-silver rather than orange/pink under the copper sheen, or scratches to reveal silver underneath, that's a red flag.
- **No manufacturer name, no datasheet, generic "Cat6 High Speed Cable" branding only.**
- **Bends stiffly, or the conductor feels unusually light/springy compared to known copper cable.**

---

## 7. Solid Core vs. Stranded

**Solid conductor** — one continuous strand of copper per wire.
- Best for: **permanent wiring**, in-wall runs, patch panels, keystone jacks.
- Lower resistance and better long-term signal characteristics, but **less flexible** and more prone to breaking if flexed repeatedly (fatigue fracture) — it's meant to be installed once and left alone.

**Stranded conductor** — many thin copper strands twisted together per wire.
- Best for: **patch cables**, PC-to-router, router-to-switch, any short cable that gets moved, coiled, or flexed.
- More flexible and durable under repeated bending, but has slightly higher resistance/attenuation than solid core of the same gauge, so it's not the first choice for very long permanent runs.

**Why not always choose solid "because it's better"?** Solid core is *more* rigid, *more* fragile under flexing, and *harder to terminate* with a standard RJ45 crimp plug (RJ45 plugs are usually designed for stranded wire; solid-core needs proper keystone jacks/punch-down tools, or specific solid-core-rated plugs). Using solid-core as a flexible desk patch cable that gets moved around is a durability mistake, not an upgrade.

---

## 8. 4PR, 8P8C, RJ45, and Twisted Pairs

```text
4PR   = 4 pairs of wires (8 conductors total) inside the cable
8P8C  = "8 Position, 8 Contact" — the technically correct name for the modular connector
RJ45  = the common (technically incorrect) name everyone uses for the same connector
```

**RJ45 vs. 8P8C:** "RJ45" originally referred to a specific telephone registered-jack wiring standard that is not what Ethernet uses. The connector Ethernet actually uses is the 8P8C modular connector. The industry uses "RJ45" so universally that it's effectively become the accepted colloquial name — but 8P8C is the precise term you'll see in standards documents.

**Why twisted pairs?** Twisting two wires together causes electromagnetic interference picked up by each wire to largely cancel out, because the two wires are exposed to nearly the same interference field but carry opposite-polarity signals. Different pairs are twisted at different rates specifically to reduce **crosstalk** — interference between the pairs *inside the same cable*, not just outside noise.

**Crosstalk and pair separation:** Higher categories tighten twist rates and physically separate pairs (sometimes with a center spline/divider in Cat6+) to reduce Near-End Crosstalk (NEXT) and related measurements, which is a big part of why higher categories can carry higher frequencies cleanly.

**Why proper termination matters:** Untwisting the pairs too far back from the connector (common in sloppy RJ45 crimping) reintroduces exactly the crosstalk the twist was designed to prevent. TIA-568 installation practice specifies a maximum untwist length at termination for this reason — a poorly terminated Cat6A cable can perform worse than a well-terminated Cat5e cable.

---

## 9. Frequency Ratings

Labels like `100 MHz`, `250 MHz`, `500 MHz`, `600 MHz`, `2000 MHz` describe the cable's certified **bandwidth** — the range of signal frequencies it can carry without excessive loss or crosstalk.

**Simple analogy:** think of the cable as a pipe and MHz as the pipe's *diameter capacity for water pressure*, not the flow rate itself. A wider pipe (higher MHz) *allows* more complex, higher-frequency signaling — which Ethernet standards use to pack in more bits per second — but the pipe itself doesn't decide how much water is actually being pushed through; that's determined by what's connected at each end (your NIC and switch/router port).

**Why higher MHz doesn't automatically mean faster internet:** same logic as Section 1 — bandwidth is a *cable channel* property; internet speed is an *ISP delivery* property; they don't touch each other.

**Cat5e vs. Cat6 vs. Cat6A frequency:** 100 MHz vs. 250 MHz vs. 500 MHz respectively — <cite index="5-1">Cat6a's copper conductor is typically 24 AWG, and its tighter twist reduces crosstalk by roughly 30% compared to Cat5e, which is why it can sustain 10 Gbps over distances where Cat5e is limited to 1 Gbps.</cite>

**Bandwidth vs. Ethernet speed:** bandwidth is the *ceiling the cable is certified for*; Ethernet speed is what the two connected devices actually negotiate to use, which depends on hardware capability, distance, and cable quality together — not the cable's MHz rating alone.

---

## 10. Cable Jacket Ratings

These letters describe **fire/smoke behavior and installation environment**, not network performance. A Cat6 cable can be CM, CMR, or CMP — that has zero effect on speed.

| Marking | Meaning | Where it's rated for |
|---|---|---|
| **CM** | Communications, general purpose | Basic indoor use, single room/floor, not for risers or plenums |
| **CMG** | Communications, general | Same class as CM, general indoor use |
| **CMR** | Communications, **Riser** | Vertical shafts between floors; better flame-spread resistance than CM, but not plenum-rated |
| **CMP** | Communications, **Plenum** | Air-handling spaces (ducts, drop ceilings, raised floors) — the highest common fire rating |
| **CMX** | Communications, limited purpose | General/light-duty and some outdoor-rated variants; **not** fire-rated for riser/plenum use |
| **LSZH / LSOH** | Low Smoke Zero Halogen (a *jacket material*, not a fire-rating class) | Reduces toxic/acidic smoke when burned; common where people may need to evacuate through smoke |
| **PVC** | Polyvinyl chloride (a common jacket base material) | General purpose; releases more smoke/toxic gas than LSZH when burned |
| **PE** | Polyethylene | Common for **outdoor** jackets — better UV/moisture resistance than indoor PVC |

**Important distinction:** <cite index="72-1">jacket material (PVC, LSZH, PE) is the chemical compound that determines how the cable burns — smoke density, halogen content, acid gas emission — while fire rating (CMP, CMR, CM, CMX) is the NEC classification that determines where the cable can legally be installed, and these are independent attributes that both must be specified.</cite> A given material can be manufactured to different fire-rating levels.

**Ranking (higher substitutes for lower, never the reverse):** <cite index="70-1">a simple rule that works every time: look for the letter "P" in the rating code — CMP confirms plenum compliance — and higher-rated cable can always substitute for lower-rated cable, but never the other way around; you can install CMP anywhere CMR or CM is required.</cite>

**Why "PVC" alone doesn't tell you everything:** PVC is a jacket *base material*, but doesn't by itself specify the fire-rating class (CM vs CMR vs CMP), UV resistance, or moisture resistance — you need the fire-rating code and any outdoor-specific markings alongside it.

**Indoor cable used outdoors — why not:** standard indoor PVC/LSZH jackets aren't UV-stabilized and lack a real moisture barrier; they'll crack, become brittle, and let water in over time. A true outdoor cable is marked for it (often PE jacket, UV-resistant, sometimes gel-filled) — indoor cable degrades outdoors even if it "works" on day one.

- **UV resistance:** required for any cable exposed to direct sunlight for extended periods; indoor jackets typically lack UV stabilizers.
- **Moisture resistance:** outdoor cable needs a real water-resistant jacket; some are gel-filled internally to stop water wicking along the cable length if the jacket is ever breached.
- **Direct burial:** needs an explicit "direct burial" rating — outdoor-rated alone isn't automatically burial-rated unless stated.
- **Conduit:** running outdoor cable through conduit is a common, sensible way to add mechanical/UV protection without needing a full direct-burial cable.

---

## 11. Length and Ethernet Distance Limits

**Permanent Link vs. Channel vs. Patch cable — the terms matter:**

```text
Permanent Link  = the fixed, installed cabling in walls/floors, from wall jack to patch panel (max 90 m under TIA-568)
Channel         = Permanent Link + patch cords at both ends (max 100 m total under TIA-568, for standard categories)
Patch cable      = the short, flexible cable connecting equipment to a jack/panel — typically part of the 10 m allowance
```

All standard copper categories (Cat5e through Cat6A) share the **100-meter maximum channel** under TIA-568 — 90 m permanent link + up to 10 m combined patch cords at both ends. Cat8 is the exception, capped at a 30 m channel for its full 25G/40G speeds (see Section 20).

For a home setup like yours (a single PC-to-router run), you're almost always dealing with one continuous cable rather than a formal "permanent link + patch cords" split — so practically speaking, just stay under 100 m total, and prefer good-quality 23/24 AWG solid copper as you get closer to that limit.

- **1–20 m:** Easy — virtually any reasonable-quality cable of the right category will perform fine at this length. Construction quality matters less the shorter the run.
- **30–50 m:** Construction starts to matter more — prefer real copper, correct AWG, decent shielding if the path crosses noisy areas.
- **100 m:** At the standard's absolute limit — cable quality, correct termination, and avoiding cheap CCA cable become genuinely important, not just "nice to have."

---

## 12. Ethernet Speeds and What They Actually Require

| Ethernet standard | Minimum cable category | Practical max distance | Common use |
|---|---|---|---|
| 100 Mbps (Fast Ethernet) | Cat5 (Cat5e in practice) | 100 m | Legacy devices |
| 1 Gbps (1000BASE-T) | Cat5e | 100 m | Standard home/office |
| 2.5 Gbps (2.5GBASE-T) | Cat5e (Cat6 recommended) | 100 m | Modern NICs, multi-gig switches |
| 5 Gbps (5GBASE-T) | Cat6 | 100 m | Multi-gig NAS/switch links |
| 10 Gbps (10GBASE-T) | Cat6 (short runs) / Cat6A (full 100 m) | ~37–55 m on Cat6, 100 m on Cat6A | 10GbE workstations, NAS, servers |
| 25/40 Gbps (25/40GBASE-T) | Cat8 | 30 m | Data-center rack interconnects |

**The cable alone does not determine your link speed.** The final speed you actually get depends on the *weakest link* across:

```text
NIC (network card) capability
Cable category and construction
Switch/router port capability
Connector/termination quality
Distance
Interference (EMI/alien crosstalk)
Auto-negotiation between both ends
```

A Cat6A cable connected between a Gigabit NIC and a Gigabit switch port will link at 1 Gbps, full stop — the cable's extra headroom simply goes unused. That's not wasted forever (it helps if you upgrade the NIC/switch later), but it doesn't retroactively speed anything up today.

---

## 13. PoE (Power over Ethernet)

| Standard | Common name | Max power at source | Power guaranteed at device | Pairs used |
|---|---|---|---|---|
| IEEE 802.3af | PoE (Type 1) | 15.4 W | 12.95 W | 2 pairs |
| IEEE 802.3at | PoE+ (Type 2) | 30 W | 25.5 W | 2 pairs |
| IEEE 802.3bt Type 3 | PoE++ | 60 W | ~51 W | 4 pairs |
| IEEE 802.3bt Type 4 | PoE++ / Hi-PoE | ~90–100 W | ~71.3 W | 4 pairs |

**Why conductor quality matters for PoE specifically:** unlike pure data transmission, PoE pushes real DC current through the copper conductors continuously. Resistance directly converts to heat (I²R losses) and voltage drop along the cable — a marginal conductor that "just barely" carries a data signal can genuinely overheat or under-deliver power under PoE load, in a way that's much more physically consequential than a few retransmitted data packets.

**Why CCA is particularly bad for PoE:** CCA's ~40–60% higher DC resistance directly worsens both the heat and voltage-drop problems above; combined with CCA's documented DC Resistance Unbalance failures, this is the scenario where using fake-copper cable is most likely to cause a real device fault or, in extreme high-wattage cases, a genuine heat hazard rather than just a slow network.

**Practical examples:**
- **IP camera:** typically PoE or PoE+ — use solid copper, 23/24 AWG for any run over ~15–20 m.
- **Wi-Fi access point:** often PoE+ (some Wi-Fi 6E/7 APs need PoE++) — same guidance.
- **VoIP phone:** usually low-wattage PoE — less critical, but copper is still recommended.
- **Security/access-control device (locks, sensors):** often continuously powered — reliability over years matters, so avoid CCA entirely.

---

## 14. Flat Ethernet Cables

**Flat cables** are wide, ribbon-like cables (pairs laid side-by-side rather than bundled round); **round cables** bundle the twisted pairs in a traditional circular jacket.

**Why flat cables are convenient:** they slide easily under carpets, doors, and rugs, and route flush against walls/baseboards more discreetly than round cable.

**Disadvantages:**
- The flat, side-by-side pair layout is a compromise on maintaining consistent twist geometry and pair spacing — the very things that control crosstalk — so flat cables often have *worse* real-world crosstalk performance than an equivalent round cable, even when both are labeled the same category.
- Bend-radius and heat dissipation in a bundle of flat cables can behave differently than round cable.
- Are flat Cat6 cables suitable for 2.5/10 GbE? They *can* pass at short lengths, but given the crosstalk compromise, they're a weaker bet than round Cat6/Cat6A the closer you get to 10G at longer distances.
- Are they suitable for permanent installations? Generally no — they're a patch-cable convenience product, not something rated for in-wall/under-floor permanent runs.

**Practical recommendation:** flat cable is fine for short, visible desk-to-router runs where routing convenience matters more than squeezing out maximum multi-gig performance. For anything permanent or high-speed over distance, use round cable.

---

## 15. Slim Ethernet Cables

Labels like `Slim Cat6`, `28 AWG`, `30 AWG` describe cables deliberately built thin for easier routing.

- **Why easier to route:** thinner overall diameter bends more freely and takes up less space in cable management, behind furniture, through tight conduit fill.
- **Why higher resistance:** thinner AWG conductors inherently have more resistance per meter than 23/24 AWG — this is physics, not a manufacturing shortcut, so it applies even to a genuinely 100%-copper slim cable.
- **PoE considerations:** slim (28/30 AWG) cable is a weaker choice for PoE, especially at longer lengths or higher PoE+/PoE++ wattages, purely because of the AWG-resistance relationship in Section 4.
- **When slim cables make sense:** short desk/rack patch cables where routing density matters more than raw performance headroom.
- **When standard 23/24 AWG is preferable:** any run over roughly 10–15 m, any PoE application, or anything semi-permanent.

---

## 16. Patch Cables vs. Installation (Bulk) Cable

| | Patch cable | Bulk/installation cable |
|---|---|---|
| Conductor | Stranded | Solid |
| Connectors | Factory-molded RJ45 plugs on both ends | Sold as a spool; terminated on-site into keystone jacks/patch panels or field-crimped plugs |
| Flexibility | High — meant to be moved/coiled | Low — meant to be installed once |
| Typical length | Short (0.3–15 m) | Long (30 m to 300+ m spools) |
| Use | Device-to-jack, device-to-switch | In-wall, under-floor, permanent structured cabling |

**What a normal PC user should buy:** a pre-made **stranded patch cable** in the exact length you need (5/10/20/30 m as you mentioned) is the right product — you don't need bulk spool cable, keystone jacks, or a punch-down tool unless you're doing an in-wall install with a patch panel.

---

## 17. Decoding Real Product Labels — 10 Examples

**A — Good cable**
```text
CAT6 U/UTP 23AWG 4PR 100% COPPER 250MHz CMR
```
Correct category+bandwidth match, real copper stated, solid AWG, riser-rated jacket. **Good choice** for a permanent home run.

**B — Cheap but acceptable cable**
```text
CAT6 UTP 24AWG 4PR PVC
```
No explicit copper claim, no MHz confirmation — but a known, established brand and reasonable price can still make this fine for a short desk cable. **Acceptable with some diligence** (check brand/reviews).

**C — Misleading cable (suspicious)**
```text
CAT6 UTP 33AWG 128M
```
33 AWG doesn't meaningfully exist for Cat6 category cable (far too thin for the standard's electrical requirements) and "128M" isn't a real, recognized bandwidth rating for any category. This combination doesn't map to any real standard — **treat as fabricated marketing, avoid.**

**D — CCA cable**
```text
CAT6 CCA 26AWG
```
Explicitly admits CCA. Per Section 6, this is not standards-compliant Ethernet cable regardless of the "Cat6" printed alongside it. **Avoid**, especially for PoE or long runs.

**E — Slim cable**
```text
CAT6 Slim 28AWG U/UTP 100% Copper
```
Real copper, but thin gauge trades resistance/PoE headroom for flexibility. **Fine for short patch use, not for PoE or long runs.**

**F — Shielded cable**
```text
CAT6A S/FTP 23AWG LSZH 500MHz
```
Correct bandwidth for Cat6A, proper heavy shielding, safety-rated jacket. **Good choice** for a noisy environment or dense bundle run — overkill but harmless for a simple home desk run.

**G — Outdoor cable**
```text
CAT6 U/UTP 23AWG Outdoor UV-Resistant Direct Burial Gel-Filled
```
Explicit outdoor/UV/burial claims — this is what a real outdoor label should say, not just "Cat6" alone. **Good, if you actually need outdoor/burial use.**

**H — PoE-oriented cable**
```text
CAT6 U/UTP 23AWG 100% Bare Copper 250MHz (PoE++ Rated)
```
23 AWG + explicit bare-copper claim is exactly what you want to see for a PoE camera/AP run. **Good choice for PoE.**

**I — Cat7 cable**
```text
CAT7 S/FTP 23AWG 600MHz RJ45 Connectors
```
Note the contradiction: real Class F/Cat7 per ISO/IEC 11801 specifies GG45/TERA connectors to hit its full 600 MHz — RJ45 connectors cap performance at roughly Cat6A levels regardless of what the cable itself is rated for. **Not fraudulent necessarily, but the "Cat7" claim is functionally meaningless with RJ45 ends — you're paying for shielding and a number, not real Cat7 performance.**

**J — Fake/marketing-heavy cable**
```text
Ultra High Speed Gaming Ethernet Cable 40Gbps 2000MHz 24K Gold Connectors
```
"Gaming Ethernet cable" isn't a technical category; "40 Gbps" and "2000 MHz" from a plain consumer RJ45 cable strongly imply unsubstantiated Cat8-tier claims without any category/AWG/copper information at all. **Avoid — no real standards information given, marketing language dominates the label.**

---

## 18. Marketing Terms Decoded

| Term | Classification | Why |
|---|---|---|
| "Gigabit" / "1000 Mbps" | Meaningful (if accurate) | Refers to a real, well-defined Ethernet speed — check it matches the stated category properly |
| "High Speed" | Mostly marketing | No defined technical meaning |
| "Ultra High Speed" | Mostly marketing | Same — no standard defines this |
| "Gaming Ethernet Cable" | Mostly marketing | Ethernet doesn't have a "gaming mode" — a correctly built Cat6/6A cable performs the same for gaming as for anything else |
| "Premium" | Mostly marketing | Meaningless without supporting specs (AWG, copper, category, MHz) |
| "High Purity Copper" / "OFC" (Oxygen-Free Copper) | Useful but context-dependent | OFC matters a lot for high-fidelity *audio* cabling (subtle purity differences can matter for analog signal); for **digital Ethernet data**, the digital signal is far more tolerant, so OFC claims add little real benefit over standard-grade solid copper for networking |
| "Gold Plated" / "24K Gold Plated" RJ45 contacts | Useful but context-dependent | Gold resists corrosion and gives more consistent, long-term-reliable contact resistance at the pins — a genuine benefit for connector longevity, but it does not increase data speed or bandwidth |
| "Hi-Fi Ethernet" | Mostly marketing / red flag | Digital Ethernet data is packet-based and error-checked; there's no meaningful "audio fidelity" improvement path the way there is with analog audio cable — this term borrows audiophile marketing language that doesn't map to digital networking physics |
| "Future Proof" | Mostly marketing | Vague; only meaningful if paired with a real category + construction claim (e.g., genuine Cat6A copper cable IS reasonably future-proof — the label alone isn't) |
| "10 Gbps" alone | Potential red flag if unsupported | Only credible when paired with the actual category, AWG, and copper claim it takes to deliver that — as a bare number with no other spec, it proves nothing |
| "40Gbps" on RJ45 consumer cable | Potential red flag | Only Cat8 delivers this, and only at 30 m with proper construction — extremely suspicious on a generic patch cable |
| "600MHz" / "2000MHz" on unlabeled category cable | Potential red flag | Legitimate only if it matches a real category claim (600 MHz ≈ Cat7 class F; 2000 MHz ≈ Cat8) with matching connector/shielding — a bare MHz number pasted onto vague "gaming" cable is not trustworthy |

**Specific answers:**
- **Does gold plating matter?** Yes, modestly — for connector corrosion resistance and long-term reliability, not for speed.
- **Does OFC matter for Ethernet?** Marginal at best for digital data; matters much more for audio cable.
- **Does "gaming Ethernet cable" mean anything technically?** No defined technical meaning.
- **Does "2000 MHz Cat7" mean what the seller claims?** Only if paired with proper GG45/TERA connectors and genuine Class FA construction — on an RJ45-terminated consumer cable, treat with skepticism.
- **Does "10 Gbps" alone prove anything?** No — it needs category, AWG, and copper backing it up.

---

## 19. Cat7 — A Careful Look

**Cat7 vs. Cat6A:** Cat7 (ISO/IEC 11801 Class F) is rated to 600 MHz vs. Cat6A's 500 MHz, and is always fully shielded — but in *practical* achievable Ethernet speed, both top out at 10 Gbps over 100 m, since no consumer IEEE Ethernet standard currently uses more than 500 MHz worth of that headroom over copper at 100 m.

**The core problem: TIA never recognized it.** <cite index="19-1">CAT7 is standardized by ISO/IEC as Class F; the TIA did not ratify CAT7 and instead moved straight from CAT6A to CAT8, though CAT7 is still widely sold and recognized globally, mostly outside North America.</cite>

**Connector requirements:** the official standard doesn't use RJ45 at all. <cite index="21-1">The official ISO standard for a Class F (Cat7) channel doesn't use the familiar 8P8C (RJ45) connector every modern router/computer uses — instead it specifies proprietary connectors like GG45 or TERA, designed to handle the higher 600 MHz frequency.</cite> But <cite index="21-2">nearly every "Cat7" patch cord sold to consumers is terminated with standard RJ45 ends for plug-and-play compatibility, and since the RJ45 connector itself is only rated to about 500 MHz (Cat6A level), a "Cat7" cable with RJ45 connectors is, by definition, unable to deliver true Cat7 performance.</cite>

**Why it's heavily marketed to consumers anyway:** "Cat7" *sounds* like a straightforward upgrade over Cat6A (bigger number = better, intuitively), and shielded cable *feels* premium — both are effective marketing hooks even though the RJ45 bottleneck erases the actual technical advantage in a home setup.

**Does Cat7 provide meaningful benefit for a normal home PC?** No — with RJ45 connectors (which is what you'll almost always get as a consumer), you're functionally capped at roughly Cat6A performance anyway, at a higher price and with stiffer, harder-to-route cable.

**Is Cat7 worth paying extra for?** Generally no, for home use. It only makes sense if you're specifically deploying a true GG45/TERA-terminated Class F/FA system, which essentially never happens outside specialized European industrial/broadcast contexts.

**When does Cat7 actually make sense?** <cite index="20-1">Its real value proposition is in applications that need bandwidth beyond 500 MHz but don't require Cat8's 2 GHz/40 Gbps — such as broadband CATV distribution or high-frequency video — and it has niche adoption in European broadcast/telecom infrastructure; for standard Ethernet networking in North America, Cat7/7A is not TIA-recognized and offers no practical advantage over Cat6A.</cite>

**Is Cat6A usually more sensible for 10GbE home networking?** Yes — <cite index="42-1">for any project referencing TIA-568 standards, skip Cat7 entirely; if you need 10G at 100 meters, spec Cat6a (TIA-recognized, RJ45-native, cost-competitive), and if you need extreme EMI immunity, spec Cat6a S/FTP or F/UTP, which delivers equivalent real-world shielding with standard RJ45 termination.</cite>

---

## 20. Cat8 — Is It Worth It?

**Cat8 in one line:** a 2000 MHz-certified copper standard designed to carry 25GBASE-T/40GBASE-T (25/40 Gbps) over very short data-center runs.

- <cite index="31-1">CAT8 was developed to support the IEEE 25GBASE-T and 40GBASE-T specs, has a maximum channel length of 30 meters with two connectors, and is tested from 1 MHz to 2000 MHz — versus a 4-connector, 100-meter, 500 MHz channel for CAT6A.</cite>
- <cite index="40-1">Category 8 has a maximum Permanent Link Length of 24 m and a maximum Channel length of 30 m when supporting 25 Gbps and 40 Gbps speeds — but it can support data speeds of 10 Gbps and lower at the full 100 m channel configuration, same as lower categories.</cite>
- Connectors: <cite index="40-2">the ANSI/TIA Category 8 solution uses the standard 8-position modular connector (RJ45), designed to be backward compatible with existing connectors used from Category 5e through Category 6A.</cite> So unlike Cat7, Cat8 keeps the familiar RJ45 plug — but the 30 m distance cap is the real constraint, not the connector.
- **25GBASE-T / 40GBASE-T:** IEEE Ethernet speed standards designed specifically for short-reach, high-density data-center links (server-to-top-of-rack switch), not general building/office cabling.
- **Why 30 m and not 100 m:** the 2000 MHz signal degrades too much over longer distances to reliably hit 25/40 Gbps error rates — it's a direct physical trade-off for the extreme frequency, exactly parallel to why Cat7's higher MHz doesn't translate into more usable home speed either.
- **Data-center applications:** short, dense server-to-switch/top-of-rack interconnects where fiber would otherwise be used, but copper is cheaper and simpler at very short reach.
- **Why unnecessary at home:** a home network essentially never has a legitimate 25/40 Gbps requirement, and even if it did, the 30 m hard limit makes it unsuitable for most home cable runs (router-to-PC across a house routinely exceeds 30 m).

**Clear recommendation: skip Cat8 for home use.** It solves a data-center problem (extreme short-reach bandwidth density) that doesn't exist in a home network, at a real cost in price and flexibility.

---

## 21. What Should Different People Buy?

| User | Recommended cable | Why |
|---|---|---|
| Basic 100 Mbps internet user | Cat5e U/UTP | Any real Cat5e comfortably exceeds what 100 Mbps needs |
| 1 Gbps home user | Cat5e or Cat6 U/UTP, 24 AWG copper | Cat5e is technically sufficient; Cat6 adds cheap headroom |
| Gaming PC | Cat6 U/UTP, 23/24 AWG, 100% copper | Plenty of bandwidth and low latency characteristics; shielding unnecessary indoors |
| 2.5 GbE PC | Cat6 U/UTP | Comfortably covers 2.5G at home distances |
| 10 GbE NAS | Cat6A U/FTP or S/FTP, 23 AWG | Guarantees the full 100 m 10G channel without the alien-crosstalk ceiling of plain Cat6 |
| Wi-Fi 6/6E/7 AP | Cat6/Cat6A, 23 AWG, real copper — check PoE+/PoE++ needs | Many modern APs need PoE+ or PoE++; copper quality matters here |
| PoE camera | Cat6 U/UTP, 23 AWG, 100% bare copper | Prioritize copper purity and AWG over category number |
| Home server | Cat6A U/UTP or shielded | Matches likely 2.5G/5G/10G NIC upgrades over time |
| Long 50–100 m run | Cat6/Cat6A, 23 AWG solid copper | Distance is exactly where cheap CCA/thin-AWG cable fails hardest |
| Outdoor run | Cat6 (or Cat6A) explicitly outdoor/UV-rated, gel-filled if buried | Category matters less than the outdoor/burial jacket claim here |
| Data center | Cat6A (general) or Cat8 (≤30 m server-to-switch) | Matches actual IEEE speed targets and channel-length limits |

---

## 22. What to Avoid — the "DO NOT BUY" Checklist

- **CCA (Copper-Clad Aluminum)** — non-standards-compliant, higher resistance, PoE-unsafe. Always a problem unless you fully understand and accept the trade-off for a trivial, non-critical, very short cable.
- **CCS (Copper-Clad Steel)** — even worse conductivity than CCA; essentially never appropriate for Ethernet.
- **Unclear/unstated conductor material** — a real problem specifically when the price is suspiciously low; less of a concern from an established, reputable brand at a normal price.
- **Suspiciously cheap Cat6/Cat7 vs. comparable listings** — a real problem; price is one of the most reliable CCA signals.
- **Extremely thin conductors (28+ AWG) without a stated reason** — only a problem for long runs or PoE; fine for a genuinely short flexible patch cable.
- **Fake certification logos** (UL/ETL marks with no real backing) — a real problem, and often paired with CCA.
- **No manufacturer information** — a real problem for anything permanent; less critical for a throwaway short cable you can easily replace.
- **No cable specifications at all** (no AWG, no copper claim, no MHz) — a real problem; you have nothing to verify against.
- **"Cat7" with RJ45-only construction and no GG45/TERA option** — not fraud exactly, but functionally you're paying Cat7 prices for Cat6A performance; treat as a "why bother" rather than an outright scam.
- **Marketing claims with no standards information** ("Ultra High Speed," "Gaming," "Hi-Fi") — a real problem when they're the *only* information given.
- **Indoor cable sold/used for outdoor installation** — a real problem; it will degrade (UV, moisture) regardless of category.
- **Poor-quality connectors** (loose crimps, visibly misaligned pins, no strain relief) — a real problem regardless of the cable behind them; termination quality can bottleneck a good cable.
- **Unnecessarily long cables** — not a safety/compliance problem, just wasted cost and cable clutter; buy close to the length you need.
- **Cheap flat cable for permanent installation** — a real problem for anything meant to stay in a wall/floor for years; fine for a temporary/visible desk run.
- **Unknown-brand cable with exaggerated speed claims** ("40 Gbps" on a generic RJ45 patch cable) — a real problem; treat as a hard signal to walk away.

---

## 23. What Should a Normal Person Buy?

For a typical home user whose main need is a **PC-to-router/switch Ethernet cable** in lengths like 5 m, 10 m, 20 m, and 30 m:

**Buy: Cat6 U/UTP, 23 or 24 AWG, 100% (bare/solid) copper, stranded, from a known brand, with an explicit copper claim and a real MHz rating printed on the jacket.**

Reasoning:
- Cat5e is technically enough for 1 Gbps, but Cat6 costs barely more and gives you 2.5G/5G/10G headroom at home distances without paying for anything you don't need.
- Cat6A is a reasonable step up specifically if you already own or plan to own 10GbE gear (NAS, workstation NIC, multi-gig switch) — it removes Cat6's distance ceiling for 10G.
- Cat7 and Cat8 are the wrong tool for this job for the reasons in Sections 19–20 — skip both.
- U/UTP is sufficient indoors; you don't need S/FTP shielding for a normal home routing path.
- Real copper and correct AWG matter far more to actual reliability than the category number itself.

---

## 24. Worked Example: Buying a 20 m Cable

You need a 20 m Ethernet cable for your desktop PC. Five labels to rank:

```text
A: Cat6 U/UTP 24AWG 100% Copper
B: Cat6 UTP 33AWG CCA
C: Cat7 S/FTP 26AWG
D: Cat6A U/FTP 23AWG Solid Copper
E: Cat6 "Gaming" 28AWG
```

| Rank | Label | Reasoning |
|---|---|---|
| **Best choice** | **D — Cat6A U/FTP 23AWG Solid Copper** | Real copper, thick 23 AWG (great for the 20 m run), Cat6A headroom for future 10G upgrades. Slight overkill in shielding for home use, but harmless and well-built. |
| **Good choice** | **A — Cat6 U/UTP 24AWG 100% Copper** | Real copper, standard AWG, correct category for the job. This is the sensible, no-frills pick for most people. |
| **Acceptable** | **C — Cat7 S/FTP 26AWG** | Real shielding and presumably real copper (unstated, so verify), but "Cat7" is functionally wasted without GG45/TERA connectors, and 26 AWG is thinner than ideal for 20 m. You're paying extra for a shielding level you don't need and a category claim you can't actually use. |
| **Questionable** | **E — Cat6 "Gaming" 28AWG** | No copper claim at all, thin 28 AWG for a 20 m run, and "Gaming" is a marketing label with no technical meaning. Might be fine, might not — insufficient information to trust it. |
| **Avoid** | **B — Cat6 UTP 33AWG CCA** | Explicitly CCA (non-compliant conductor) *and* an absurdly thin, almost certainly fabricated 33 AWG figure for category cable. Two red flags stacked on the same label. |

---

## 25. How to Read an Ethernet Cable in 10 Seconds

```text
1. Check the category         (Cat5e/6/6A — ignore Cat7/8 hype for home use)
2. Check conductor material   (must say copper / bare copper / solid copper — CCA = no)
3. Check AWG                  (23–24 AWG for most uses; not below 26 for long runs or PoE)
4. Check UTP/FTP/SFTP          (U/UTP is fine indoors; shielding only if you have a real EMI need)
5. Check solid vs stranded     (solid = permanent wall runs; stranded = patch/movable cables)
6. Check jacket rating         (CM/CMR/CMP/outdoor — match to where it's actually installed)
7. Check manufacturer          (a named, reputable brand you can look up beats an anonymous listing)
8. Check certifications        (UL/ETL marks should be verifiable, not just printed)
9. Check intended use          (patch cable vs. bulk/installation cable — buy the right product type)
10. Ignore meaningless marketing (“Gaming,” “Hi-Fi,” “Ultra,” “Future Proof” with no specs behind them)
```

**One-line rule to remember:**

> For most home users, buy **Cat6 (or Cat6A for future-proofing), U/UTP, 23–24 AWG, 100% solid/bare copper, from a known brand** — and skip Cat7/Cat8 entirely.
