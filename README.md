## The Wall – OpenShift

The Wall är en Flask-applikation som använder PostgreSQL för att lagra meddelanden.

## Förberedelser

Innan installationen behöver du tillgång till OpenShift-projektet, oc CLI och en fungerande StorageClass för databasens lagring.
Podman eller Docker behövs om webbimagen ska byggas och publiceras på nytt.

## Applikationens filer

Följande filer finns i katalogen app/:
- app.py – Flask-applikationens kod, inklusive databasanslutningar och routes.
- Containerfile – beskriver hur containerimagen byggs.
- requirements.txt – innehåller applikationens Python-beroenden.
- start.sh – initierar databasen och startar Gunicorn.

## 1. Projektinformation

- OpenShift-projekt: student-jacob-lagstrom-lerniastudent-se
- Repository: https://github.com/Jalag96/the-wall
- Upstream: https://github.com/jonasbjork/the-wall
- Webbimage: docker.io/jalag004/the-wall:v2
- Databasimage: quay.io/kurs/postgresql:16

## 2. Förutsättningar

För att installera applikationen behövs:
- Tillgång till OpenShift-projektet.
- oc CLI installerat.
- En aktiv inloggning till OpenShift.
- En fungerande StorageClass för databasens lagring.
- Podman eller Docker om webbimagen ska byggas på nytt.

## 3. Konfiguration

Databasens inställningar finns i manifests/wall-configmap.yaml.

Databasens användarnamn och lösenord lagras i en Secret. Logga först in på OpenShift och välj rätt projekt:
oc login
oc project student-jacob-lagstrom-lerniastudent-se


Skapa sedan Secret innan installationen:
oc create secret generic wall-secret \
  --from-literal=DB_USER=walluser \
  --from-literal=DB_PASSWORD='DITT_LÖSENORD' \
  --dry-run=client -o yaml | oc apply -f -

Använd ett eget lösenord. Om Secret redan finns uppdateras den med de nya värdena.
Secret ska inte publiceras i Git. Se till att lösenordet inte skrivs ut eller delas i dokumentation.

## 4. Bygg containerimagen

Gå till app-katalogen:
cd app

Bygg och publicera imagen:
podman build -t docker.io/jalag004/the-wall:v2 -f Containerfile .
podman push docker.io/jalag004/the-wall:v2


Gå tillbaka till projektets rotkatalog:
cd ~/the-wall


## 5. Installera The Wall

Kontrollera att du står i projektets rotkatalog och att rätt OpenShift-projekt är valt:
oc project

Gör installationsskriptet körbart:
chmod +x scripts/deploy.sh

Starta installationen:
./scripts/deploy.sh

Skriptet skapar eller uppdaterar applikationens resurser. Om databasens PVC saknas skapas en ny tom volym. Finns den redan används den befintliga volymen.

## 6. Kontrollera installationen

Kontrollera att applikationens resurser har startat:
oc get pods
oc get services
oc get routes

Applikationens adress visas med:
oc get route wall

Öppna adressen via HTTPS för att kontrollera att webbapplikationen fungerar.

Kontrollera även applikationens health-endpoint: curl -i https://DIN-ROUTE/health
Ett fungerande svar ska ge HTTP 200 OK.

## 7. Backup

Skapa en databasbackup med:
./scripts/backup-db.sh

Backupfilerna sparas lokalt i katalogen backups/, utanför OpenShift-volymen.

Det är viktigt att spara backupfilerna på en säker plats eftersom de inte automatiskt skyddas av databasens PVC.

## 7.1. Återställa en backupdatabas

Om databasen behöver återställas kan en tidigare backup importeras till databasen.

Återställningen förutsätter att databasen och tabellen messages redan finns. Importen nedan återställer meddelandedata, inte hela databasschemat.

Gå till katalogen med backupfilerna:
cd ~/the-wall/backups


Importera backupfilen. Byt BACKUPFIL.sql till namnet på den backup du vill använda:
sed -n '/^COPY public\.messages /,/^\\\.$/p' BACKUPFIL.sql | oc exec -i deployment/wall-db -- sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRESQL_USER" -d "$POSTGRESQL_DATABASE"'

Efter importen behöver PostgreSQLs ID-räknare synkroniseras med de återställda meddelandena. Annars kan databasen försöka tilldela ett ID som redan används när ett nytt meddelande skapas.

Kör:
oc exec deployment/wall-db -- psql -U walluser -d walldb -c "SELECT setval(pg_get_serial_sequence('messages', 'id'), COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM messages;"

När importen och synkroniseringen är klar finns de tidigare meddelandena tillgängliga i webbapplikationen igen, och nya meddelanden kan skapas utan ID-konflikter.

Observera:
- Återställningen ska göras till en ny eller tom databas.
- Kontrollera alltid att du väljer rätt backupfil.
- Kontrollera att databasen och tabellen messages finns innan importen.
- Importera inte en backup ovanpå befintliga meddelanden om du inte avsiktligt vill riskera dubbletter.

## 7.2. Byta databaslösenord

Om databasens lösenord ska bytas behöver det uppdateras på två ställen: i Kubernetes Secret och i PostgreSQL.

1. Uppdatera Secret:

oc create secret generic wall-secret \
  --from-literal=DB_USER=walluser \
  --from-literal=DB_PASSWORD='LÖSENORD' \
  --dry-run=client -o yaml | oc apply -f -


Detta uppdaterar lösenordet i wall-secret. Webbapplikationen använder värdet för att ansluta till databasen.

2. Ändra lösenordet i PostgreSQL:

Öppna en shell-session i databaspodden:
oc exec -it deployment/wall-db -- bash

Anslut till PostgreSQL med miljövariablerna:
psql -U "$POSTGRESQL_USER" -d "$POSTGRESQL_DATABASE"

Alternativt kan användarnamn och databas anges direkt:
psql -U walluser -d walldb

När du är inne i PostgreSQL kör du:
ALTER ROLE walluser WITH PASSWORD 'LÖSENORD';

Använd samma lösenord som du angav i Secret.

3. Starta om webbapplikationen:

Avsluta PostgreSQL-sessionen och shell-sessionen. Kör sedan:
oc rollout restart deployment/wall-web

Detta gör att de nya webb-Poddarna läser in de uppdaterade Secret-värdena vid start.

Verifiera att applikationen fungerar efter lösenordsbytet genom att testa webbapplikationen och kontrollera att ett nytt meddelande kan sparas.

Hur fungerar det?
- Kubernetes Secret lagrar lösenordet som webbapplikationen använder.
- PostgreSQL har sitt eget lösenord för databasanvändaren.
- Båda måste ha samma lösenord för att anslutningen ska fungera.
- När webbapplikationen startas om läser de nya Podarna in de uppdaterade Secret-värdena.

## 8. Ta bort installationen

Kör:./scripts/remove-deploy.sh

Skriptet skapar först en databasbackup och tar sedan bort applikationens resurser, inklusive PVC:n.

Observera! När PVC:n tas bort försvinner även databasens lagrade data. StorageClass gp3-csi använder reclaimPolicy: Delete.

Om du vill starta med en helt ny databas behöver en ny PVC skapas. Kontrollera även om wall-secret finns kvar innan du kör installationen igen:
oc get secret wall-secret

Om Secret saknas behöver den skapas igen enligt avsnitt 3.

Därefter kan installationen startas på nytt:
./scripts/deploy.sh

En ny PVC innebär en tom databas. Läs avsnitt 7.1 och 7.2 för att förstå hur sparade meddelanden kan återställas från en tidigare backup.

## 9. Manifest

Alla manifestfiler finns i katalogen manifests/:
- wall-configmap.yaml – databasinställningar.
- wall-secret.yaml – lokala databasuppgifter, ska inte publiceras.
- wall-pvc.yaml – databaslagring.
- wall-db-deployment.yaml – PostgreSQL.
- wall-db-service.yaml – databasens Service.
- wall-db-networkpolicy.yaml – begränsar trafik till databasen.
- wall-web-deployment.yaml – webbapplikationen.
- wall-web-service.yaml – webbens Service.
- wall-web-hpa.yaml – automatisk skalning.
- wall-route.yaml – extern HTTPS-adress.
