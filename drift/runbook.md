# RUNBOOK – THE WALL (OKD)

## 1. Syfte och arkitektur

Den här runbooken beskriver hur The Wall driftsätts, verifieras, underhålls och felsöks i OKD-klustret.

The Wall är en webbapplikation byggd med Flask och PostgreSQL. Applikationen körs som containrar i OKD och nås via en HTTPS-skyddad Route.

### 1.1 Arkitektur

Applikationen består av följande resurser:

- wall-web: Flask-applikationen som körs med Gunicorn.
- wall-db: PostgreSQL-databasen som lagrar meddelanden.
- wall-web Service: Intern tjänst som distribuerar trafik till webbapplikationens Pods.
- wall-db Service: Intern tjänst som gör databasen tillgänglig för webbapplikationen.
- Route: Exponerar webbapplikationen via HTTPS.
- PersistentVolumeClaim (PVC): Lagrar databasens data så att den finns kvar när databas-Poden ersätts.
- ConfigMap: Innehåller icke-känslig konfiguration, exempelvis databasens värdnamn och databasnamn.
- Secret: Innehåller databasens användarnamn och lösenord.
- NetworkPolicy: Begränsar åtkomsten till databasen så att endast webbapplikationens Pods får ansluta till PostgreSQL.
- HorizontalPodAutoscaler (HPA): Anpassar antalet webb-Pods efter CPU-belastningen.

Webbapplikationen kör normalt två repliker och kan skalas upp till tre med hjälp av HPA. Databasen körs med en replik och använder en persistent volym.

### 1.2 Förutsättningar och behörigheter

Följande verktyg och behörigheter behövs:

- Tillgång till OKD/OpenShift-klustret.
- `oc` CLI installerat och inloggat.
- Behörighet att skapa och hantera Deployments, Services, Routes, ConfigMaps, Secrets, PVC och NetworkPolicies.
- Tillgång till aktuell StorageClass.
- Podman för att bygga och publicera containerimages.
- Git för att hämta och hantera projektets källkod.
- Ett konto och ett repository i ett containerregister, exempelvis Docker Hub.

Kontrollera att du är inloggad:

oc whoami

Kontrollera vilket projekt som är aktivt:

oc project

Byt till projektet om det behövs:

oc project student-jacob-lagstrom-lerniastudent-se

Kontrollera behörigheter vid behov:

oc auth can-i create deployments
oc auth can-i create services
oc auth can-i create routes
oc auth can-i create secrets
oc auth can-i create persistentvolumeclaims
oc auth can-i create networkpolicies

## 2. Bygga och publicera containerimage

Containerimagen byggs med Podman från projektets Containerfile i katalogen app/

Gå till projektets rotkatalog:

cd ~/the-wall

Bygg imagen:

podman build -t docker.io/jalag004/the-wall:v2 -f app/Containerfile app/

Kontrollera att imagen har skapats:

podman images

Logga in på Docker Hub:

podman login docker.io

Publicera imagen:

podman push docker.io/jalag004/the-wall:v2

Kontrollera att rätt image används i:

manifests/wall-web-deployment.yaml

Image-inställningen ska vara:

image: docker.io/jalag004/the-wall:v2

Vid en ny version bör ett nytt versionsnummer användas, exempelvis `v3`, i stället för att skriva över en befintlig version. Uppdatera därefter Deployment-manifestet så att det pekar på den nya imagen.

Om ett annat containerregister används behöver image-adressen anpassas. Vid användning av ett privat register kan OKD även behöva autentiseringsuppgifter för att kunna hämta imagen.

## 3. Installation och driftsättning

### 3.1 Förberedelser

Kontrollera att rätt OKD-projekt är aktivt:

oc project student-jacob-lagstrom-lerniastudent-se

Kontrollera att Secret finns:

oc get secret wall-secret

Secret måste finnas innan Deployment-resurserna skapas eftersom både webbapplikationen och databasen använder uppgifter från den.

Om Secret saknas behöver det skapas innan driftsättningen. Exempel:

oc create secret generic wall-secret \
--from-literal=DB_USER='walluser' \
--from-literal=DB_PASSWORD='DITT_LÖSENORD' \
--dry-run=client -o yaml | oc apply -f -

Ersätt lösenordet med det aktuella lösenordet. Lägg aldrig in riktiga lösenord i Git eller i projektets manifestfiler.

### 3.2 Installation med deploy.sh

Projektet innehåller ett driftsättningsskript som automatiserar installationen.

Från projektets rotkatalog körs:

./scripts/deploy.sh

Skriptet kontrollerar först att `wall-secret` finns och applicerar därefter projektets resurser i rätt ordning.

Det omfattar bland annat ConfigMap, PVC, Services, NetworkPolicy, Deployments, HPA och Route.

Skriptet skapar inte databassecreten. Den måste alltså finnas sedan tidigare.

### 3.3 Manuell driftsättning

Vid felsökning eller om resurser behöver appliceras separat kan manifestfilerna användas direkt med `oc apply`.

Börja med att kontrollera att Secret finns:

oc get secret wall-secret

Om Secret saknas kan det skapas med:

oc create secret generic wall-secret \
--from-literal=DB_USER='walluser' \
--from-literal=DB_PASSWORD='DITT_LÖSENORD' \
--dry-run=client -o yaml | oc apply -f -

Applicera därefter ConfigMap och PVC:

oc apply -f manifests/wall-configmap.yaml
oc apply -f manifests/wall-pvc.yaml

Skapa databasens resurser:

oc apply -f manifests/wall-db-service.yaml
oc apply -f manifests/wall-db-networkpolicy.yaml
oc apply -f manifests/wall-db-deployment.yaml

Skapa webbapplikationens resurser:

oc apply -f manifests/wall-web-service.yaml
oc apply -f manifests/wall-web-deployment.yaml

Avsluta med HPA och Route:

oc apply -f manifests/wall-web-hpa.yaml
oc apply -f manifests/wall-route.yaml

Kontrollera att resurserna har skapats och att Pods startar innan installationen betraktas som färdig.

## 4. VERIFIERING EFTER DRIFTSÄTTNING

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

Kontrollera HPA:

oc get hpa wall-web

Kontrollera att HPA:n är kopplad till Deployment wall-web och att den har minst två repliker.

Kontrollera Route:

oc get route wall

Testa applikationens hälsokontroll via HTTPS:

curl -i https://<ROUTE-ADRESS>/health

Förväntat resultat är HTTP 200 OK och ett JSON-svar med status ok.

Kontrollera även startsidan:

curl -i https://<ROUTE-ADRESS>/

Förväntat resultat är HTTP 200 OK och att webbapplikationens HTML-innehåll returneras.

Slutligen bör ett testmeddelande skapas via webbapplikationen och sedan kontrolleras att det går att läsa tillbaka. Detta verifierar att webbapplikationen kan kommunicera med databasen och att läsning och skrivning fungerar.

## 5. LÖSENORDSROTATION

Databasens lösenord finns i Kubernetes Secret wall-secret.

Att bara uppdatera Secret är inte tillräckligt för en redan initierad PostgreSQL-databas. Databasens faktiska användarlösenord måste också ändras.

Arbetsgång:

1. Ta reda på databasens användarnamn utan att skriva ut lösenordet.
2. Anslut till PostgreSQL med behörig administratör.
3. Ändra användarens lösenord i PostgreSQL med ALTER ROLE.
4. Uppdatera DB_PASSWORD i Kubernetes Secret wall-secret med samma nya lösenord.
5. Starta om webbapplikationen så att den läser in det uppdaterade värdet:

oc rollout restart deployment/wall-web

### 5.1 Verifiera lösenordsrotationen

Kontrollera att webbapplikationens Pods har startat om:

oc get pods -l app=wall-web

Kontrollera att Deployment är färdig:

oc rollout status deployment/wall-web

Testa därefter att läsa in startsidan och skapa ett nytt meddelande. Det bekräftar att applikationen kan kommunicera med databasen med de uppdaterade inloggningsuppgifterna.

Lösenord ska hanteras säkert och aldrig läggas i Git eller i rapportens kommandoutskrifter.

## 6. FELSÖKNING

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

## 7. ROLLBACK AV WEBBAPPLIKATIONEN

Om en ny version av webbapplikationen inte fungerar kan Deployment återställas till föregående revision:

oc rollout history deployment/wall-web
oc rollout undo deployment/wall-web

Verifiera återställningen:

oc rollout status deployment/wall-web
oc get pods -l app=wall-web

Testa därefter /health och startsidan.

En rollback av webbapplikationen återställer inte automatiskt databasens schema eller innehåll. Databasändringar behöver hanteras separat.

## 8. OMSTART MED BIBEHÅLLEN DATABASVOLYM

För att starta om databasen utan att förlora sparade meddelanden ska den befintliga PVC:n wall-db-data behållas.

Kontrollera först att webbapplikationen inte tar emot nya skrivningar. Skala ned webbapplikationen:

oc delete hpa wall-web 
(HPA skalar upp Deployment till 2 replicas, därför måste den tillfälligt tas bort)
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
oc apply -f manifests/wall-web-hpa.yaml

Kontrollera att PVC fortfarande är Bound:

oc get pvc wall-db-data

Viktigt: PVC:n får inte raderas. Det är den som bevarar databasens data när databaspodden ersätts.

## 9. SEPARAT TEST MED EN NY TOM PVC

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

## 10. ÅTERSTÄLLNING EFTER TEST OCH SLUTKONTROLL

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
