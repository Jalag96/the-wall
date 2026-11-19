# Verifieringsprotokoll – The Wall

**Projekt:** The Wall  
**Miljö:** OKD 4.22  
**Namespace:** student-jacob-lagstrom-lerniastudent-se  
**Repository:** https://github.com/Jalag96/the-wall  
**Senast uppdaterad:** 2026-11-18

## Syfte

Detta protokoll dokumenterar verifieringen av projektets funktionella krav
(A–H) och verifieringstester (V1–V10).

Varje test ska innehålla:
- Krav- eller test-ID.
- Datum och tid.
- Kommando eller testmetod.
- Förväntat resultat.
- Faktiskt resultat.
- Referens till sparat bevis.
- Status.

Status anges som:
- Ej testad
- Godkänd
- Underkänd
- Behöver kompletteras

---

## Krav B – Route, TLS och nätverksisolering

### B1 – HTTPS och TLS

| Fält | Resultat |
|---|---|
| Datum | 2026-11-18 |
| Testmetod | curl mot HTTPS-Route |
| Kommando | `curl -sS -o /dev/null -w "HTTPS status: %{http_code}\n" "https://$ROUTE"` |
| Förväntat | HTTP 200 |
| Faktiskt | HTTP 200 |
| Bevis | `bevis/B-route-tls-redirect.txt` |
| Status | Godkänd |

### B2 – HTTP omdirigeras till HTTPS

| Fält | Resultat |
|---|---|
| Datum | 2026-11-18 |
| Testmetod | curl mot HTTP-Route |
| Förväntat | Redirect till HTTPS |
| Faktiskt | HTTP 302, Location pekar på HTTPS |
| Slutresultat | HTTPS, HTTP 200 |
| Bevis | `bevis/B-route-tls-redirect.txt` |
| Status | Godkänd |

### B3 – NetworkPolicy tillåter webbapplikationens databasanslutning

| Fält | Resultat |
|---|---|
| Datum | Ej testad |
| Testmetod | Ej genomförd |
| Förväntat | wall-web kan ansluta till wall-db på TCP 5432 |
| Faktiskt | Ej testat |
| Bevis | Saknas |
| Status | Ej testad |

### B4 – NetworkPolicy blockerar obehörig klient

| Fält | Resultat |
|---|---|
| Datum | Ej testad |
| Testmetod | Ej genomförd |
| Förväntat | Pod utan tillåten etikett kan inte ansluta till wall-db på TCP 5432 |
| Faktiskt | Ej testat |
| Bevis | Saknas |
| Status | Ej testad |

---

## Övriga krav och verifieringstester

A – Container image och reproducerbar deployment: Ej dokumenterad  
B – Route, TLS och nätverksisolering: Pågår  
C – Konfiguration, secrets och säkerhet: Ej dokumenterad  
D – Persistent storage och databas: Ej dokumenterad  
E – Probes, resurser och autoskalning: Ej dokumenterad  
F – Versionshantering, rollout och rollback: Ej dokumenterad  
G – Incidenthantering: Ej dokumenterad  
H – Runbook och återskapande: Ej dokumenterad  

V1–V10: Ej dokumenterade.

