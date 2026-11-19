# The Wall – OpenShift

The Wall är en Flask-applikation som använder PostgreSQL för att lagra meddelanden.

---

## 1. Projektinformation

- OpenShift-projekt: `student-jacob-lagstrom-lerniastudent-se`
- Repository: https://github.com/Jalag96/the-wall
- Upstream: https://github.com/jonasbjork/the-wall
- Webbimage: `docker.io/jalag004/the-wall:v2`
- Databasimage: `quay.io/kurs/postgresql:16`

## 2. Förutsättningar

För att installera applikationen behövs tillgång till OpenShift-projektet, `oc` CLI, en aktiv inloggning och en fungerande StorageClass för databasens lagring. Podman eller Docker behövs om webbimagen ska byggas på nytt.

## 3. Konfiguration

Databasens inställningar finns i `manifests/wall-configmap.yaml`.

Databasens användarnamn och lösenord lagras i en Secret. Skapa den innan installationen:

`oc create secret generic wall-secret --from-literal=DB_USER=walluser --from-literal=DB_PASSWORD='DITT_LÖSENORD'`

Använd ett eget lösenord. Secret ska inte publiceras i Git.

## 4. Bygg webbimagen

Gå till app-katalogen och bygg samt publicera imagen:

`cd app`

`podman build -t docker.io/jalag004/the-wall:v2 -f Containerfile .`

`podman push docker.io/jalag004/the-wall:v2`

`cd ..`

## 5. Installera The Wall

Logga in på OpenShift och välj rätt projekt:

`oc login`

`oc project student-jacob-lagstrom-lerniastudent-se`

Starta installationen från projektets rotkatalog:

`chmod +x deploy.sh`

`./deploy.sh`

Skriptet skapar eller uppdaterar applikationens resurser. Om databasens PVC saknas skapas en ny tom volym. Finns den redan används den befintliga volymen.

## 6. Kontrollera installationen

Kontrollera att applikationens resurser har startat:

`oc get pods`

`oc get services`

`oc get routes`

Applikationens adress visas med:

`oc get route wall`

Öppna adressen via HTTPS för att kontrollera att webbapplikationen fungerar.

## 7. Backup

Skapa en databasbackup med:

`./backup-db.sh`

Backupfilerna sparas lokalt i katalogen `backups/`, utanför OpenShift-volymen.

## 7.5 Återställa en backupdatabas

Om databasen behöver återställas kan en tidigare backup importeras till den nya databasen.

Gå till katalogen med backupfilerna:

cd ~/the-wall/backups

Hämta namnet på databaspodden:

oc get pods -l app=wall-db

Importera sedan backupfilen (byt filnamn till den backup du vill använda):

oc exec -i DATABASPODD -- sh -c 'psql -U "$POSTGRESQL_USER" -d "$POSTGRESQL_DATABASE"' < BACKUPFIL.sql

När importen är klar finns de tidigare meddelandena tillgängliga i webbapplikationen igen.

Observera: Återställningen ska göras till en ny eller tom databas. Kontrollera alltid att du väljer rätt backupfil och databaspod.


## 8. Ta bort installationen

Kör:

`./remove-deploy.sh`

Skriptet skapar först en databasbackup och tar sedan bort applikationens resurser, inklusive PVC:n.

**Observera:** När PVC:n tas bort försvinner även databasens lagrade data. StorageClass `gp3-csi` använder `reclaimPolicy: Delete`.

För att starta med en helt ny databas behöver Secret skapas igen och `./deploy.sh` köras på nytt. Då skapas en ny tom PVC.

## 9. Manifest

Alla manifestfiler finns i katalogen `manifests/`:

- `wall-configmap.yaml` – databasinställningar
- `wall-secret.yaml` – lokala databasuppgifter, ska inte publiceras
- `wall-pvc.yaml` – databaslagring
- `wall-db-deployment.yaml` – PostgreSQL
- `wall-db-service.yaml` – databasens Service
- `wall-db-networkpolicy.yaml` – begränsar trafik till databasen
- `wall-web-deployment.yaml` – webbapplikationen
- `wall-web-service.yaml` – webbens Service
- `wall-web-hpa.yaml` – automatisk skalning
- `wall-route.yaml` – extern HTTPS-adress
