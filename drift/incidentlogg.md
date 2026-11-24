# Incident 1 – Databasberoende och felaktig Service-selector

24 november 2026  

Berörda komponenter: wall-db Service och wall-web Deployment

1. Symptom

Webbapplikationen kunde inte längre kommunicera med databasen. Databas-Poden var fortfarande igång, men webbapplikationens readiness-probe misslyckades.

Före incidenten fungerade applikationen normalt:
- Båda webb-Poddarna var 1/1 Ready.
- Databas-Podden var 1/1 Running.
- GET /health och GET / returnerade HTTP 200.
- Databasens Service hade en aktiv endpoint.

2. Hypotes

Misstanken var att webbapplikationen inte kunde nå databasen via Kubernetes Service. För att testa detta ändrades wall-db Service selector från app: wall-db till app: felaktig-db.

Databas-Podens label ändrades inte.

3. Undersökning och bevis

Efter ändringen visade oc get endpoints wall-db:

NAME      ENDPOINTS
wall-db   <none>

Databas-Poden fortsatte samtidigt att vara 1/1 Running.

Webb-Podarna visade:

NAME                        READY   STATUS    RESTARTS
wall-web-596c544665-9jjth   0/1     Running   0
wall-web-596c544665-bsb4q   0/1     Running   0

För att testa applikationen direkt användes port-forward till en befintlig webb-Pod.

GET /health:

HTTP/1.1 200 OK
{"pod":"wall-web-596c544665-9jjth","status":"ok"}

GET /:

HTTP/1.1 503 SERVICE UNAVAILABLE
Database unavailable. Check application logs.

Detta visade att webbprocessen fortfarande körde, men att databasen inte fungerade.

4. Åtgärd

Service-selectorn återställdes till rätt label:

oc patch svc wall-db -p '{"spec":{"selector":{"app":"wall-db"}}}'

Därefter visade oc get endpoints wall-db att databasens endpoint var tillbaka:

NAME      ENDPOINTS
wall-db   10.130.1.129:5432

Webb-Podarna återgick till:

NAME                        READY   STATUS    RESTARTS
wall-web-596c544665-9jjth   1/1     Running   0
wall-web-596c544665-bsb4q   1/1     Running   0

Applikationen fungerade igen efter att Service-selectorn hade återställts.

5. Analys

Incidenten visade tydligt skillnaden mellan readiness och liveness. När databasen inte gick att nå misslyckades readiness-proben eftersom / behöver databasen. Webb-Podarna markerades därför som NotReady och togs bort från Service-endpoints.

Däremot fungerade /health fortfarande eftersom den inte behöver någon databaskoppling. Containrarna fortsatte alltså att köra utan omstarter, vilket också syntes på att RestartCount låg kvar på 0.

6. Förebyggande förbättring
- Kontrollera att Service-selectors matchar Podarnas labels.
- Hålla koll på att viktiga Services har aktiva endpoints.
- Ha separata readiness- och liveness-prober med tydliga syften.
- Se till att /health kontrollerar att webbprocessen lever och att readiness även kontrollerar att applikationen kan hantera trafik.



## Incident 2 – Felaktigt databasnamn

Detta test fick jag inspiration från incidentpasset "DB_ABSUER".

2026-11-24

1. Symptom
Webbapplikationen slutade fungera i de nya Podarna efter att DB_NAME ändrats till nonexistent_db. De nya Podarna hamnade i en omstartsloop medan de gamla Podarna fortsatte att hantera trafik.

2. Felsökning
Jag kontrollerade Pod-status, Deployment, ReplicaSets, events och applikationsloggar.

Loggarna visade att PostgreSQL gick att nå, men att databasen nonexistent_db inte existerade. Applikationen försökte ansluta 30 gånger innan initialiseringen misslyckades.

Eftersom applikationen inte kunde initiera databaskopplingen startade aldrig Gunicorn. Startup-proben fick därför connection refused, vilket ledde till att containern startades om.

3. Åtgärd
Jag återställde databasnamnet:

oc set env deployment/wall-web DB_NAME=walldb

Därefter inväntade jag att Deployment skulle rulla ut den nya konfigurationen.

4. Verifiering
Efter återställningen visade kontrollerna:

- Båda webb-Podarna var 1/1 Running.
- Deployment var 2/2 Available.
- Databastjänsten hade en aktiv endpoint på port 5432.
- /health svarade med HTTP 200.
- / svarade med HTTP 200 och kunde läsa meddelanden från databasen.
- Ett nytt meddelande kunde skrivas och visas efter återställningen.

5. Analys
Det här felet skiljde sig från incident 1. Där var databastjänsten inte nåbar på grund av en felaktig Service-selector. Här gick det att nå PostgreSQL, men själva databasnamnet var fel.

Eftersom applikationen försöker ansluta till databasen innan Gunicorn startar kunde den nya Poden inte börja hantera trafik alls. Startup-proben misslyckades och containern startades om. De gamla Podarna fortsatte däremot att fungera under rollback.

6. Förebyggande förbättringar
- Kontrollera att databasnamnet i konfigurationen stämmer med databasen som faktiskt finns.
- Verifiera konfigurationsändringar innan de rullas ut i produktion.
- Använd readiness- och startup-prober för att upptäcka problem innan en Pod tar emot trafik.
- Övervaka applikationsloggar och omstarter för att snabbt upptäcka misslyckad databasinitialisering.
