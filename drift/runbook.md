RUNBOOK – THE WALL (OKD)

1. SYFTE OCH ARKITEKTUR

Den här runbooken beskriver hur The Wall byggs, driftsätts, verifieras, felsöks och återställs i OKD.

Applikationen består av:

- wall-web: Flask-applikation som körs med Gunicorn.
- wall-db: PostgreSQL-databas.
- wall-web-service: Exponerar webbapplikationen internt på port 80.
- wall-db-service: Exponerar databasen internt på port 5432.
- wall-route: Gör webbapplikationen tillgänglig via HTTPS.
- wall-db-data: Persistent Volume Claim (PVC) som lagrar databasens data.

Konfiguration hämtas från wall-configmap och känsliga uppgifter från wall-secret.

1.1 FÖRUTSÄTTNINGAR OCH BEHÖRIGHETER

För att följa denna runbook krävs:

- Tillgång till ett OKD/OpenShift-kluster.
- Ett tilldelat OKD-projekt (namespace).
- Behörighet att skapa och hantera Deployments, Services, Routes, ConfigMaps, Secrets, PVC och NetworkPolicies.
- Tillgång till persistent storage via en fungerande StorageClass.
- Podman installerat för att bygga och publicera containerimagen.
- Git installerat för att klona projektet.
- Tillgång till ett containerregister där den byggda imagen kan publiceras.
- Tillgång till klustrets API via kommandoradsverktyget oc.

Om ett kommando nekas på grund av otillräckliga behörigheter ska användaren kontrollera sina tilldelade roller och vid behov kontakta klusteradministratören.

Kontrollera aktuell användare och projekt:

oc whoami
oc project

Kontrollera vilka behörigheter användaren har:

oc auth can-i create deployments
oc auth can-i create services
oc auth can-i create routes
oc auth can-i create persistentvolumeclaims
oc auth can-i create secrets
oc auth can-i create networkpolicies

Ett nekande svar innebär att användaren saknar den aktuella behörigheten i det valda projektet. Det betyder inte nödvändigtvis att manifestet är felaktigt.

2. BYGGA OCH PUBLICERA EN NY IMAGE

För att bygga projektet själv behöver användaren först klona GitHub-repot:

git clone https://github.com/Jalag96/the-wall.git

Gå till projektkatalogen:

cd the-wall

Bygg imagen från app-katalogen:

podman build -t the-wall:v2 -f app/Containerfile app/

Kontrollera att imagen har skapats:

podman images

För att OKD ska kunna hämta imagen behöver den publiceras i ett containerregister som klustret har åtkomst till. Följande exempel använder Docker Hub.

Ange användarens eget Docker Hub-användarnamn:

export DOCKERHUB_USERNAME=ditt_dockerhub_användarnamn

Logga in:

podman login docker.io

Tagga imagen med adressen till det egna registret:

podman tag the-wall:v2 docker.io/$DOCKERHUB_USERNAME/the-wall:v2

Publicera imagen:

podman push docker.io/$DOCKERHUB_USERNAME/the-wall:v2

Uppdatera därefter image-adressen i manifests/wall-web-deployment.yaml så att den pekar på den publicerade imagen:

docker.io/DITT_DOCKERHUB_ANVÄNDARNAMN/the-wall:v2

Användarens eget Docker Hub-användarnamn ska ersätta platshållaren.

Om registret är privat måste OKD även ges behörighet att hämta imagen. Vid ett publikt repository behövs normalt ingen separat autentisering.

Vid en ny version bör ett nytt versionsnummer användas, exempelvis v3, i stället för att skriva över en befintlig version.

3. INSTALLATION OCH DRIFTSÄTTNING

Kontrollera först att rätt OKD-projekt används:

oc project

Kontrollera att nödvändiga resurser finns:

oc get configmap wall-configmap
oc get secret wall-secret
oc get pvc wall-db-data

Secret och PVC ska finnas sedan tidigare. De ska inte tas bort vid en vanlig ominstallation.

Applicera databasens och webbapplikationens resurser:

oc apply -f manifests/wall-db-service.yaml
oc apply -f manifests/wall-web-service.yaml
oc apply -f manifests/wall-db-deployment.yaml
oc apply -f manifests/wall-web-deployment.yaml
oc apply -f manifests/wall-db-networkpolicy.yaml
oc apply -f manifests/wall-route.yaml
oc apply -f manifests/wall-web-hpa.yaml

Vid en helt ny installation behöver även PVC, ConfigMap och Secret skapas innan Deployment-resurserna startas. Secret ska skapas med användarens egna databasuppgifter och aldrig sparas med riktiga lösenord i Git.

4. VERIFIERING EFTER DRIFTSÄTTNING

Kontrollera att poddarna är igång:

oc get pods

Kontrollera Deployment-status:

oc get deployments

Kontrollera Services och endpoints:

oc get services
oc get endpoints

Kontrollera PVC:

oc get pvc wall-db-data

PVC ska ha status Bound.

Kontrollera Route:

oc get route wall

Testa applikationen via HTTPS:

curl -i https://<ROUTE-ADRESS>/health

Kontrollera även startsidan:

curl -i https://<ROUTE-ADRESS>/

Förväntat resultat är HTTP 200 när applikationen och databasen fungerar.

5. LÖSENORDSROTATION

Databasens lösenord finns i Kubernetes Secret wall-secret.

Att bara uppdatera Secret är inte tillräckligt för en redan initierad PostgreSQL-databas. Databasens faktiska användarlösenord måste också ändras.

Arbetsgång:

1. Ta reda på databasens användarnamn utan att skriva ut lösenordet.
2. Anslut till PostgreSQL med behörig administratör.
3. Ändra användarens lösenord i PostgreSQL med ALTER ROLE.
4. Uppdatera DB_PASSWORD i Kubernetes Secret wall-secret med samma nya lösenord.
5. Starta om webbapplikationen så att den läser in det uppdaterade värdet:

oc rollout restart deployment/wall-web

6. Kontrollera att webbapplikationen startar och kan läsa och skriva meddelanden.

Lösenord ska hanteras säkert och aldrig läggas i Git eller i rapportens kommandoutskrifter.

6. FELSÖKNING

Kontrollera poddar:

oc get pods
oc describe pod <POD-NAMN>

Describe visar bland annat status, events, probes och eventuella startproblem.

Kontrollera loggar för webbapplikationen:

oc logs deployment/wall-web

Kontrollera loggar för databasen:

oc logs deployment/wall-db

Kontrollera föregående containerinstans:

oc logs <POD-NAMN> --previous

Kontrollera events:

oc get events

Kontrollera nätverk och endpoints:

oc get services
oc get endpoints
oc get networkpolicy

Om en Service saknar endpoints bör dess selector jämföras med poddarnas labels.

Kontrollera rollout:

oc rollout status deployment/wall-web
oc rollout history deployment/wall-web

Vanliga problem är felaktiga miljövariabler, saknade Secrets, felaktiga Service-selectors, databasanslutningsproblem och misslyckade probes.

7. ROLLBACK AV WEBBAPPLIKATIONEN

Om en ny version av webbapplikationen inte fungerar kan Deployment återställas till föregående revision:

oc rollout history deployment/wall-web
oc rollout undo deployment/wall-web

Verifiera återställningen:

oc rollout status deployment/wall-web
oc get pods -l app=wall-web

Testa därefter /health och startsidan.

En rollback av webbapplikationen återställer inte automatiskt databasens schema eller innehåll. Databasändringar behöver hanteras separat.

8. OMSTART MED BIBEHÅLLEN DATABASVOLYM

För att starta om databasen utan att förlora sparade meddelanden ska den befintliga PVC:n wall-db-data behållas.

Kontrollera först att webbapplikationen inte tar emot nya skrivningar. Skala ned webbapplikationen:

oc scale deployment/wall-web --replicas=0

Kontrollera att webbapplikationens poddar har avslutats:

oc get pods -l app=wall-web

Skala sedan ned databasen:

oc scale deployment/wall-db --replicas=0

När databaspodden har avslutats kan databasen startas igen:

oc scale deployment/wall-db --replicas=1
oc rollout status deployment/wall-db

Starta därefter webbapplikationen:

oc scale deployment/wall-web --replicas=2
oc rollout status deployment/wall-web

Kontrollera att PVC fortfarande är Bound:

oc get pvc wall-db-data

Viktigt: PVC:n får inte raderas. Det är den som bevarar databasens data när databaspodden ersätts.

9. SEPARAT TEST MED EN NY TOM PVC

Ett separat test kan genomföras för att verifiera att databasen kan initieras med en helt ny, tom volym.

Testet ska göras isolerat, exempelvis i ett separat OKD-projekt eller med en separat testdeployment och test-PVC. Produktions-PVC:n wall-db-data ska inte användas eller ersättas i testet.

Arbetsgång:

1. Skapa en ny PVC med ett separat namn, exempelvis wall-db-data-empty-test.
2. Skapa en separat testdeployment för PostgreSQL som använder den nya PVC:n.
3. Använd testkonfiguration och lämpliga testuppgifter.
4. Kontrollera att databasen startar och att den kan initieras.
5. Starta en separat testinstans av webbapplikationen mot testdatabasen.
6. Skapa ett testmeddelande och kontrollera att det går att läsa tillbaka.
7. Ta bort testresurserna när testet är färdigt.

Den nya PVC:n ska vara tom från början. Därför förväntas inga gamla meddelanden finnas i testdatabasen.

Det här testet ska hållas separat från produktion så att befintliga meddelanden inte riskerar att försvinna.

10. ÅTERSTÄLLNING EFTER TEST OCH SLUTKONTROLL

När tester och felsökning är färdiga ska miljön lämnas i fungerande skick.

Kontrollera och ta bort tillfälliga testresurser, exempelvis:

- Testklienter.
- Load generator.
- Tillfälliga testpoddar.
- Deployment-konfigurationer med avsiktliga fel.

Kontrollera slutligen:

oc get pods
oc get deployments
oc get services
oc get routes
oc get pvc

Webbapplikationen ska vara tillgänglig via HTTPS och databasens PVC ska fortfarande vara Bound.

ROUTE:

<ROUTE-ADRESS>
