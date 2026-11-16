# Inputs needed from the owner

Temporary form. Fill in the lines marked `>>`, save, then tell me "inputs are ready". Leave a line blank to skip it; I will keep that item blocked.
Do not put passwords, API keys or private keys in this file.

## 1. Alert tier mapping (D3)

TMD's CAP `severity` value maps to one app tier. My proposal is filled in; change any row.

| CAP severity | App tier (Safe / Watch / Warning / Danger) |
|---|---|
| Minor | >> Watch |
| Moderate | >> Warning |
| Severe | >> Warning |
| Extreme | >> Danger |
| Unknown / missing | >> Watch |

## 2. Backend host (D1)

- Provider (e.g. a Thai cloud, AWS, Google Cloud, Cloudflare, own server): >>
- Monthly budget: >>
- Who deploys it (you or me writing deploy files): >>
- OK to write the poller code now, without deploying: >> yes

## 3. App identity (D13)

- App display name: >>
- App id / package name (e.g. th.or.yourorg.floodwatch): >>
- Publisher or organisation name: >>
- Contact email shown in the app: >>
- Data controller name for the privacy notice: >>

## 4. Thai and English text (D9)

Thai is the main language. Write the Thai; I will wire up the language files. English as you want it shown.

| Text | Thai | English |
|---|---|---|
| Safe: advice line | >> | No action needed. |
| Watch: advice line | >> | Stay alert and get ready to move. |
| Warning: advice line (my draft, replace it) | >> | Prepare to leave. Follow official instructions. |
| Danger: advice line | >> | Evacuate to a shelter now! |
| Disclaimer 1: not an official channel | >> | This app is not an official government warning channel. |
| Disclaimer 2: follow official warnings first | >> | Official warnings come from Cell Broadcast (T-Alert), DDPM, NDWC and TMD. Follow them and local officials first. |
| Disclaimer 3: may be late or wrong | >> | Alerts here may be late, incomplete or wrong. No alert does not mean no danger. |
| Disclaimer 4: community sensors | >> | Community sensors are not official gauges. |

Other screens (tabs, buttons, SOS dialog, Report): reply "translate the rest as a draft" here if you want me to draft Thai for you to correct: >>

## 5. Emergency numbers

Official source (URL or "I called them") for each. Say "skip" to leave it marked unconfirmed.

- 191 Police: >>
- 199 Fire: >>
- 1155 Tourist police: >>
- Any number to add or remove from the SOS dialog: >>

## 6. Push notifications (D2)

- Firebase project created? (yes / no / later): >> later
- If yes: project id (not the keys): >>
- OK to add Firebase packages to the app once the project exists: >> no

## 7. Data permissions (D5)

Which agencies should I draft a permission request for? I draft; you send.

- HII (water level): >>
- PCD (PM2.5): >>
- DMR (landslide, flash flood): >>
- RID (river telemetry): >>
- GISTDA (flood, fire, drought): >>
- Name and role to sign the letters: >>

## 8. Pilot area

- Province or district to pilot first: >>
- Do you have contact with the local DDPM office for shelter data (yes / no): >>

## 9. Legal and telemetry

- Thai lawyer or counsel contact (name only, optional): >>
- Crash reports: none / opt-in crash reports only (D12): >> opt-in crash reports only

## 10. Reviewers for Guide and safety text

- Medical reviewer (name, organisation): >>
- Disaster-management reviewer (name, organisation): >>

## 11. Anything else

>>
