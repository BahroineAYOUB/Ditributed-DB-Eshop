# 🗄️ BDD Réparties — Étapes de Création Scénario 1 & 2

> **BARHOINE Ayoub / MOUSSA Yassine — 2ème FI GI**

---

## 🏗️ Architecture Générale

```
┌─────────────────────────────────────────┐
│         ORACLE-MAIN (Coordinateur)       │
│   Tables mères + Triggers + DB Links     │
└──────────────┬──────────────────────────┘
               │
       ┌───────┴────────┐
       ▼                ▼
┌─────────────┐   ┌─────────────┐
│ oracle-site1│   │ oracle-site2│
│  Port 1522  │   │  Port 1523  │
│             │   │             │
│ SC1:categ=50│   │ SC1:categ=35│
│ SC2:qte≥100 │   │ SC2:qte<100 │
└─────────────┘   └─────────────┘
```

---

## 📊 Définition des Scénarios

### Scénario 1 — Fragmentation par Catégorie de Produit

| Site | Critère R1 | Description |
|------|-----------|-------------|
| **Site 1** | `idcateg = 50 AND quantite > 100` | Produits catégorie 50, grandes quantités |
| **Site 2** | `idcateg = 35 AND quantite > 50` | Produits catégorie 35, quantités moyennes |

### Scénario 2 — Fragmentation par Volume de Vente

| Site | Critère R2 | Description | Lignes |
|------|-----------|-------------|--------|
| **Site 1** | `quantite >= 100` | Grossistes / Entrepôt | 20 049 |
| **Site 2** | `quantite < 100` | Détail / Magasins | 9 958 |
| **Total** | — | 20049 + 9958 | 30 007 |

---

## 🐳 ÉTAPE 1 — Lancer l'Infrastructure Docker

```bash
# Arrêter Oracle local (libère le port 1521)
net stop OracleXETNSListener
net stop OracleServiceXE

# Lancer les 3 conteneurs
docker compose up -d

# Vérifier que les 3 conteneurs sont Up
docker ps

# Récupérer les IPs des conteneurs
docker inspect oracle-main  --format="{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"
docker inspect oracle-site1 --format="{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"
docker inspect oracle-site2 --format="{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"

# Tester la connectivité réseau
docker exec oracle-main bash -c "curl -v telnet://oracle-site1:1521"
docker exec oracle-main bash -c "curl -v telnet://oracle-site2:1521"
```

---

## 👤 ÉTAPE 2 — Créer l'Utilisateur sur les 3 Instances

### Sur oracle-main, oracle-site1, oracle-site2 (SYS AS SYSDBA)

```sql
-- Résout ORA-01017 : guillemets doubles obligatoires
-- pour les mots de passe numériques
CREATE USER c##bddvente IDENTIFIED BY "1111";
GRANT CONNECT, RESOURCE, DBA TO c##bddvente;

-- Vérification
SELECT USER FROM DUAL;
-- Attendu : C##BDDVENTE ✓
```

> ⚠️ **ORA-01045** sur les sites : se connecter en `SYS AS SYSDBA`  
> et exécuter `GRANT CONNECT, RESOURCE, DBA TO c##bddvente;`

---

## 🔗 ÉTAPE 3 — Configurer les Database Links

### Sur oracle-main

```sql
-- DB Link vers Site 1
-- Remplacer IP_SITE1 par l'IP de oracle-site1
CREATE DATABASE LINK l_site1
    CONNECT TO c##bddvente IDENTIFIED BY "1111"
    USING 'IP_SITE1:1521/XE';

-- DB Link vers Site 2
-- Remplacer IP_SITE2 par l'IP de oracle-site2
CREATE DATABASE LINK l_site2
    CONNECT TO c##bddvente IDENTIFIED BY "1111"
    USING 'IP_SITE2:1521/XE';

-- Tests de connectivité
SELECT SYSDATE AS test_site1 FROM DUAL@l_site1;
-- Attendu : date courante ✓
SELECT SYSDATE AS test_site2 FROM DUAL@l_site2;
-- Attendu : date courante ✓
```

### Sur oracle-site1 ET oracle-site2 (lien inverse)

```sql
-- Remplacer IP_MAIN par l'IP de oracle-main
CREATE DATABASE LINK ORACLE_MAIN
    CONNECT TO c##bddvente IDENTIFIED BY "1111"
    USING 'IP_MAIN:1521/XE';

-- Test
SELECT SYSDATE FROM DUAL@ORACLE_MAIN;
-- Attendu : date courante ✓
```

> ⚠️ **Après chaque redémarrage Docker**, les IPs changent.  
> Recréer les DB Links avec les nouvelles IPs :
> ```sql
> DROP DATABASE LINK l_site1;
> CREATE DATABASE LINK l_site1 ...
> ```

---

## 🗄️ ÉTAPE 4 — Créer les Tables sur les Sites

### Sur oracle-site1

```sql
CREATE TABLE clients1 (
    idclient    NUMBER NOT NULL,
    codeclient  VARCHAR2(100),
    societe     VARCHAR2(100) NOT NULL,
    contact     VARCHAR2(100) NOT NULL,
    fonction    VARCHAR2(100) NOT NULL,
    adresse     VARCHAR2(100),
    ville       VARCHAR2(100),
    naissance   DATE,
    region      VARCHAR2(100),
    cp          VARCHAR2(10),
    pays        VARCHAR2(100),
    telephone   VARCHAR2(100),
    fax         VARCHAR2(100),
    CONSTRAINT pk_clients1 PRIMARY KEY (idclient)
);

CREATE TABLE produits1 (
    idproduit    NUMBER NOT NULL,
    designation  VARCHAR2(400),
    idfour       NUMBER,
    idcateg      NUMBER,
    prixunitaire FLOAT(126),
    CONSTRAINT pk_produits1 PRIMARY KEY (idproduit)
);

CREATE TABLE commandes1 (
    idcommande    NUMBER NOT NULL,
    idemploye     NUMBER,
    idclient      NUMBER,
    datecommande  DATE,
    datelivraison DATE,
    nmessager     NUMBER(4),
    portnumber    NUMBER(4),
    CONSTRAINT pk_commandes1 PRIMARY KEY (idcommande)
);

-- Table fragment 1
-- Scénario 1 : contiendra lignes categ=50 AND qte>100
-- Scénario 2 : contiendra lignes quantite >= 100
CREATE TABLE lignecommandes1 (
    idlignecommande NUMBER NOT NULL,
    idcommande      NUMBER,
    idproduit       NUMBER,
    quantite        NUMBER,
    remise          FLOAT(126),
    CONSTRAINT pk_lc1 PRIMARY KEY (idlignecommande)
);
```

### Sur oracle-site2

```sql
CREATE TABLE clients2 (
    idclient    NUMBER NOT NULL,
    codeclient  VARCHAR2(100),
    societe     VARCHAR2(100) NOT NULL,
    contact     VARCHAR2(100) NOT NULL,
    fonction    VARCHAR2(100) NOT NULL,
    adresse     VARCHAR2(100),
    ville       VARCHAR2(100),
    naissance   DATE,
    region      VARCHAR2(100),
    cp          VARCHAR2(10),
    pays        VARCHAR2(100),
    telephone   VARCHAR2(100),
    fax         VARCHAR2(100),
    CONSTRAINT pk_clients2 PRIMARY KEY (idclient)
);

CREATE TABLE produits2 (
    idproduit    NUMBER NOT NULL,
    designation  VARCHAR2(400),
    idfour       NUMBER,
    idcateg      NUMBER,
    prixunitaire FLOAT(126),
    CONSTRAINT pk_produits2 PRIMARY KEY (idproduit)
);

CREATE TABLE commandes2 (
    idcommande    NUMBER NOT NULL,
    idemploye     NUMBER,
    idclient      NUMBER,
    datecommande  DATE,
    datelivraison DATE,
    nmessager     NUMBER(4),
    portnumber    NUMBER(4),
    CONSTRAINT pk_commandes2 PRIMARY KEY (idcommande)
);

-- Table fragment 2
-- Scénario 1 : contiendra lignes categ=35 AND qte>50
-- Scénario 2 : contiendra lignes quantite < 100
CREATE TABLE lignecommandes2 (
    idlignecommande NUMBER NOT NULL,
    idcommande      NUMBER,
    idproduit       NUMBER,
    quantite        NUMBER,
    remise          FLOAT(126),
    CONSTRAINT pk_lc2 PRIMARY KEY (idlignecommande)
);
```

---

## 📥 ÉTAPE 5 — Peupler les Fragments

### Désactiver les triggers avant le peuplement

```sql
-- Sur oracle-main
ALTER TRIGGER SYC_INSERT_LIGNE           DISABLE;
ALTER TRIGGER SYC_INSERT_LIGNE_SCENARIO2 DISABLE;
```

### Peupler les tables de référence (clients, produits, commandes)

```sql
-- Tables communes aux 2 scénarios
INSERT INTO clients1@l_site1
    (idclient,codeclient,societe,contact,fonction,
     adresse,ville,naissance,region,cp,pays,telephone,fax)
SELECT idclient,codeclient,societe,contact,fonction,
       adresse,ville,naissance,region,cp,pays,telephone,fax
FROM clients;

INSERT INTO produits1@l_site1
    (idproduit,designation,idfour,idcateg,prixunitaire)
SELECT idproduit,designation,idfour,idcateg,prixunitaire
FROM produits;

INSERT INTO commandes1@l_site1
    (idcommande,idemploye,idclient,
     datecommande,datelivraison,nmessager,portnumber)
SELECT idcommande,idemploye,idclient,
       datecommande,datelivraison,nmessager,portnumber
FROM commandes;

-- Pareil pour site2
INSERT INTO clients2@l_site2   (...) SELECT ... FROM clients;
INSERT INTO produits2@l_site2  (...) SELECT ... FROM produits;
INSERT INTO commandes2@l_site2 (...) SELECT ... FROM commandes;

COMMIT;
```

### Scénario 1 — Peupler lignecommandes par catégorie

```sql
-- Fragment Site 1 : categ=50 AND quantite>100
INSERT INTO lignecommandes1@l_site1
    (idlignecommande,idcommande,idproduit,quantite,remise)
SELECT lc.idlignecommande,lc.idcommande,
       lc.idproduit,lc.quantite,lc.remise
FROM lignecommandes lc
JOIN produits p ON lc.idproduit = p.idproduit
WHERE p.idcateg = 50 AND lc.quantite > 100;

-- Fragment Site 2 : categ=35 AND quantite>50
INSERT INTO lignecommandes2@l_site2
    (idlignecommande,idcommande,idproduit,quantite,remise)
SELECT lc.idlignecommande,lc.idcommande,
       lc.idproduit,lc.quantite,lc.remise
FROM lignecommandes lc
JOIN produits p ON lc.idproduit = p.idproduit
WHERE p.idcateg = 35 AND lc.quantite > 50;

COMMIT;

-- Validation Scénario 1
SELECT
    (SELECT COUNT(*) FROM lignecommandes1@l_site1) AS site1_categ50,
    (SELECT COUNT(*) FROM lignecommandes2@l_site2) AS site2_categ35
FROM DUAL;
```

### Scénario 2 — Peupler lignecommandes par quantité

```sql
-- Vider les fragments d'abord si déjà peuplés
DELETE FROM lignecommandes1@l_site1;
DELETE FROM lignecommandes2@l_site2;
COMMIT;

-- Fragment Site 1 : Grossistes (quantite >= 100)
INSERT INTO lignecommandes1@l_site1
    (idlignecommande,idcommande,idproduit,quantite,remise)
SELECT idlignecommande,idcommande,idproduit,quantite,remise
FROM lignecommandes WHERE quantite >= 100;

-- Fragment Site 2 : Détail (quantite < 100)
INSERT INTO lignecommandes2@l_site2
    (idlignecommande,idcommande,idproduit,quantite,remise)
SELECT idlignecommande,idcommande,idproduit,quantite,remise
FROM lignecommandes WHERE quantite < 100;

COMMIT;

-- Validation Scénario 2
SELECT
    (SELECT COUNT(*) FROM lignecommandes1@l_site1) AS site1_grossistes,
    (SELECT COUNT(*) FROM lignecommandes2@l_site2) AS site2_detail,
    (SELECT COUNT(*) FROM lignecommandes1@l_site1)
  + (SELECT COUNT(*) FROM lignecommandes2@l_site2) AS total
FROM DUAL;
-- Attendu : 20049 | 9958 | 30007 ✓
```

---

## ⚙️ ÉTAPE 6 — Créer les Procédures Stockées

### Sur oracle-site1

```sql
-- INSERTLIGNE
CREATE OR REPLACE PROCEDURE INSERTLIGNE(
    p_idlignecommande IN NUMBER,
    p_idcommande      IN NUMBER,
    p_idproduit       IN NUMBER,
    p_quantite        IN NUMBER,
    p_remise          IN NUMBER
) IS
BEGIN
    INSERT INTO lignecommandes1
        (idlignecommande,idcommande,idproduit,quantite,remise)
    VALUES
        (p_idlignecommande,p_idcommande,
         p_idproduit,p_quantite,p_remise);
    -- Pas de COMMIT (géré par la transaction appelante)
END;
/

-- DELETELIGNE
CREATE OR REPLACE PROCEDURE DELETELIGNE(p_idligne IN NUMBER) AS
    v_idcommande NUMBER;
    v_idclient   NUMBER;
    v_count      NUMBER;
BEGIN
    SELECT idcommande INTO v_idcommande
    FROM lignecommandes1 WHERE idlignecommande = p_idligne;
    DELETE FROM lignecommandes1
    WHERE idlignecommande = p_idligne;
    SELECT COUNT(*) INTO v_count
    FROM lignecommandes1 WHERE idcommande = v_idcommande;
    IF v_count = 0 THEN
        SELECT idclient INTO v_idclient
        FROM commandes1 WHERE idcommande = v_idcommande;
        DELETE FROM commandes1 WHERE idcommande = v_idcommande;
        SELECT COUNT(*) INTO v_count
        FROM commandes1 WHERE idclient = v_idclient;
        IF v_count = 0 THEN
            DELETE FROM clients1 WHERE idclient = v_idclient;
        END IF;
    END IF;
END;
/

-- UPDATELIGNE
CREATE OR REPLACE PROCEDURE UPDATELIGNE(
    p_idligne           IN NUMBER,
    p_nouveau_idproduit IN NUMBER,
    p_nouvelle_quantite IN NUMBER,
    p_nouvelle_remise   IN NUMBER
) AS
BEGIN
    UPDATE lignecommandes1
    SET idproduit = p_nouveau_idproduit,
        quantite  = p_nouvelle_quantite,
        remise    = p_nouvelle_remise
    WHERE idlignecommande = p_idligne;
END;
/

-- INSERT_COMMANDE1
CREATE OR REPLACE PROCEDURE INSERT_COMMANDE1(
    p_idcom IN NUMBER,
    p_idcli IN NUMBER,
    p_date  IN DATE
) IS
BEGIN
    INSERT INTO commandes1(idcommande,idclient,datecommande)
    VALUES (p_idcom,p_idcli,p_date);
    COMMIT;
END;
/
```

### Sur oracle-site2

```sql
-- Identique avec suffixe 2 et table lignecommandes2
CREATE OR REPLACE PROCEDURE INSERTLIGNE2(...) ...
CREATE OR REPLACE PROCEDURE DELETELIGNE2(...) ...
CREATE OR REPLACE PROCEDURE UPDATELIGNE2(...) ...

-- Vérifier compilation
SELECT object_name, status FROM user_objects
WHERE object_type = 'PROCEDURE';
-- Attendu : tous VALID ✓
```

---

## ⚡ ÉTAPE 7 — Créer les Triggers

### Sur oracle-main — Scénario 1 (par Catégorie)

```sql
-- INSERT Scénario 1
CREATE OR REPLACE TRIGGER SYC_INSERT_LIGNE
BEFORE INSERT ON lignecommandes
FOR EACH ROW
DECLARE v_idcateg NUMBER;
BEGIN
    SELECT idcateg INTO v_idcateg
    FROM produits WHERE idproduit = :NEW.idproduit;
    IF v_idcateg = 50 AND :NEW.quantite > 100 THEN
        INSERTLIGNE@l_site1(
            :NEW.idlignecommande,:NEW.idcommande,
            :NEW.idproduit,:NEW.quantite,:NEW.remise);
    ELSIF v_idcateg = 35 AND :NEW.quantite > 50 THEN
        INSERTLIGNE2@l_site2(
            :NEW.idlignecommande,:NEW.idcommande,
            :NEW.idproduit,:NEW.quantite,:NEW.remise);
    END IF;
END;
/

-- UPDATE Scénario 1 (migration inter-fragment)
CREATE OR REPLACE TRIGGER SYC_UPDATE_LIGNE
AFTER UPDATE ON lignecommandes
FOR EACH ROW
DECLARE
    v_idcateg_old NUMBER;
    v_idcateg_new NUMBER;
BEGIN
    SELECT idcateg INTO v_idcateg_old
    FROM produits WHERE idproduit = :OLD.idproduit;
    SELECT idcateg INTO v_idcateg_new
    FROM produits WHERE idproduit = :NEW.idproduit;
    -- Supprimer de l'ancien site
    IF v_idcateg_old = 50 AND :OLD.quantite > 100 THEN
        DELETE FROM lignecommandes1@l_site1
        WHERE idlignecommande = :OLD.idlignecommande;
    ELSIF v_idcateg_old = 35 AND :OLD.quantite > 50 THEN
        DELETE FROM lignecommandes2@l_site2
        WHERE idlignecommande = :OLD.idlignecommande;
    END IF;
    -- Insérer dans le nouveau site
    IF v_idcateg_new = 50 AND :NEW.quantite > 100 THEN
        INSERT INTO lignecommandes1@l_site1
            (idlignecommande,idcommande,idproduit,quantite,remise)
        VALUES (:NEW.idlignecommande,:NEW.idcommande,
                :NEW.idproduit,:NEW.quantite,:NEW.remise);
    ELSIF v_idcateg_new = 35 AND :NEW.quantite > 50 THEN
        INSERT INTO lignecommandes2@l_site2
            (idlignecommande,idcommande,idproduit,quantite,remise)
        VALUES (:NEW.idlignecommande,:NEW.idcommande,
                :NEW.idproduit,:NEW.quantite,:NEW.remise);
    END IF;
END;
/

-- DELETE Scénario 1
CREATE OR REPLACE TRIGGER SYC_DELETE_LIGNE
AFTER DELETE ON lignecommandes
FOR EACH ROW
DECLARE v_idcateg NUMBER;
BEGIN
    SELECT idcateg INTO v_idcateg
    FROM produits WHERE idproduit = :OLD.idproduit;
    IF v_idcateg = 50 AND :OLD.quantite > 100 THEN
        DELETE FROM lignecommandes1@l_site1
        WHERE idlignecommande = :OLD.idlignecommande;
    ELSIF v_idcateg = 35 AND :OLD.quantite > 50 THEN
        DELETE FROM lignecommandes2@l_site2
        WHERE idlignecommande = :OLD.idlignecommande;
    END IF;
END;
/
```

### Sur oracle-main — Scénario 2 (par Quantité)

```sql
-- INSERT Scénario 2
CREATE OR REPLACE TRIGGER SYC_INSERT_LIGNE_SCENARIO2
BEFORE INSERT ON lignecommandes
FOR EACH ROW
BEGIN
    IF :NEW.quantite >= 100 THEN
        INSERTLIGNE@l_site1(
            :NEW.idlignecommande,:NEW.idcommande,
            :NEW.idproduit,:NEW.quantite,:NEW.remise);
    ELSE
        INSERTLIGNE2@l_site2(
            :NEW.idlignecommande,:NEW.idcommande,
            :NEW.idproduit,:NEW.quantite,:NEW.remise);
    END IF;
END;
/

-- UPDATE Scénario 2 (migration automatique)
CREATE OR REPLACE TRIGGER SYC_UPDATE_LIGNE_SCENARIO2
AFTER UPDATE ON lignecommandes
FOR EACH ROW
BEGIN
    -- Supprimer de l'ancien site
    IF :OLD.quantite >= 100 THEN
        DELETE FROM lignecommandes1@l_site1
        WHERE idlignecommande = :OLD.idlignecommande;
    ELSE
        DELETE FROM lignecommandes2@l_site2
        WHERE idlignecommande = :OLD.idlignecommande;
    END IF;
    -- Insérer dans le nouveau site
    IF :NEW.quantite >= 100 THEN
        INSERT INTO lignecommandes1@l_site1
            (idlignecommande,idcommande,idproduit,quantite,remise)
        VALUES (:NEW.idlignecommande,:NEW.idcommande,
                :NEW.idproduit,:NEW.quantite,:NEW.remise);
    ELSE
        INSERT INTO lignecommandes2@l_site2
            (idlignecommande,idcommande,idproduit,quantite,remise)
        VALUES (:NEW.idlignecommande,:NEW.idcommande,
                :NEW.idproduit,:NEW.quantite,:NEW.remise);
    END IF;
END;
/

-- DELETE Scénario 2
CREATE OR REPLACE TRIGGER SYC_DELETE_LIGNE_SCENARIO2
AFTER DELETE ON lignecommandes
FOR EACH ROW
BEGIN
    IF :OLD.quantite >= 100 THEN
        DELETE FROM lignecommandes1@l_site1
        WHERE idlignecommande = :OLD.idlignecommande;
    ELSE
        DELETE FROM lignecommandes2@l_site2
        WHERE idlignecommande = :OLD.idlignecommande;
    END IF;
END;
/
```

### Sur oracle-site1 ET oracle-site2 — Sync inverse (Site → Main)

```sql
-- Trigger INSERT : sync site → main
CREATE OR REPLACE TRIGGER SYNC_TO_MAIN_INSERT
AFTER INSERT ON lignecommandes1  -- (lignecommandes2 sur site2)
FOR EACH ROW
BEGIN
    INSERT INTO lignecommandes@ORACLE_MAIN
        (idlignecommande,idcommande,idproduit,quantite,remise)
    VALUES (:NEW.idlignecommande,:NEW.idcommande,
            :NEW.idproduit,:NEW.quantite,:NEW.remise);
END;
/

-- Trigger UPDATE : sync site → main
CREATE OR REPLACE TRIGGER SYNC_TO_MAIN_UPDATE
AFTER UPDATE ON lignecommandes1
FOR EACH ROW
BEGIN
    UPDATE lignecommandes@ORACLE_MAIN
    SET idproduit = :NEW.idproduit,
        quantite  = :NEW.quantite,
        remise    = :NEW.remise
    WHERE idlignecommande = :NEW.idlignecommande;
END;
/

-- Trigger DELETE : sync site → main
CREATE OR REPLACE TRIGGER SYNC_TO_MAIN_DELETE
AFTER DELETE ON lignecommandes1
FOR EACH ROW
BEGIN
    DELETE FROM lignecommandes@ORACLE_MAIN
    WHERE idlignecommande = :OLD.idlignecommande;
END;
/

-- Vérifier tous VALID
SELECT object_name, status FROM user_objects
WHERE object_type = 'TRIGGER';
-- Attendu : tous VALID ✓
```

---

## 📈 ÉTAPE 8 — Créer la Vue Globale et les Index

```sql
-- Vue globale sur oracle-main
CREATE OR REPLACE VIEW vue_global_lignecommandes AS
    SELECT * FROM lignecommandes1@l_site1
    UNION ALL
    SELECT * FROM lignecommandes2@l_site2;

-- Test transparence
SELECT COUNT(*) FROM vue_global_lignecommandes;
-- Attendu : 30007 ✓

-- Index FBI (Function-Based Index) sur oracle-main
CREATE INDEX IDX_CMD_ANNEE
    ON commandes(EXTRACT(YEAR FROM datecommande));

EXEC DBMS_STATS.GATHER_TABLE_STATS('C##BDDVENTE','COMMANDES');

-- Index secondaires sur Site 1
CREATE INDEX idx_site1_idproduit  ON lignecommandes1(idproduit);
CREATE INDEX idx_site1_idcommande ON lignecommandes1(idcommande);

-- Index secondaires sur Site 2
CREATE INDEX idx_site2_idproduit  ON lignecommandes2(idproduit);
CREATE INDEX idx_site2_idcommande ON lignecommandes2(idcommande);
```

---

## ✅ ÉTAPE 9 — Tests de Validation

### Test Scénario 2 — Fragmentation par quantité

```sql
-- Validation disjonction et exhaustivité
SELECT
    (SELECT COUNT(*) FROM lignecommandes)          AS source,
    (SELECT COUNT(*) FROM lignecommandes1@l_site1) AS site1,
    (SELECT COUNT(*) FROM lignecommandes2@l_site2) AS site2,
    (SELECT COUNT(*) FROM lignecommandes1@l_site1)
  + (SELECT COUNT(*) FROM lignecommandes2@l_site2) AS total
FROM DUAL;
-- Attendu : source = total ✓

-- Disjonction Site 1 (aucune ligne qte < 100)
SELECT COUNT(*) FROM lignecommandes1@l_site1
WHERE quantite < 100;
-- Attendu : 0 ✓

-- Disjonction Site 2 (aucune ligne qte >= 100)
SELECT COUNT(*) FROM lignecommandes2@l_site2
WHERE quantite >= 100;
-- Attendu : 0 ✓
```

### Test Scénario 2 — Migration Site1 → Site2

```sql
-- Désactiver trigger scénario 1
ALTER TRIGGER SYC_INSERT_LIGNE  DISABLE;
ALTER TRIGGER SYC_UPDATE_LIGNE  DISABLE;
ALTER TRIGGER SYC_DELETE_LIGNE  DISABLE;

-- INSERT quantite >= 100 → doit aller sur site1
INSERT INTO lignecommandes
    (idlignecommande,idcommande,idproduit,quantite,remise)
VALUES (999991, 1, 1, 150, 0);
COMMIT;

SELECT COUNT(*) FROM lignecommandes1@l_site1
WHERE idlignecommande = 999991;
-- Attendu : 1 ✓ (sur site1)

-- UPDATE 150 → 50 : migration automatique site1 → site2
UPDATE lignecommandes SET quantite = 50
WHERE idlignecommande = 999991;
COMMIT;

SELECT COUNT(*) FROM lignecommandes1@l_site1
WHERE idlignecommande = 999991;
-- Attendu : 0 ✓ (supprimé de site1)

SELECT COUNT(*) FROM lignecommandes2@l_site2
WHERE idlignecommande = 999991;
-- Attendu : 1 ✓ (migré vers site2)

-- Nettoyer
ALTER TRIGGER SYC_DELETE_LIGNE_SCENARIO2 DISABLE;
DELETE FROM lignecommandes WHERE idlignecommande = 999991;
COMMIT;
ALTER TRIGGER SYC_DELETE_LIGNE_SCENARIO2 ENABLE;

-- Réactiver scénario 1
ALTER TRIGGER SYC_INSERT_LIGNE  ENABLE;
ALTER TRIGGER SYC_UPDATE_LIGNE  ENABLE;
ALTER TRIGGER SYC_DELETE_LIGNE  ENABLE;
```

### Test Scénario 1 — Migration Site1 → Site2

```sql
-- Désactiver scénario 2
ALTER TRIGGER SYC_INSERT_LIGNE_SCENARIO2 DISABLE;
ALTER TRIGGER SYC_UPDATE_LIGNE_SCENARIO2 DISABLE;
ALTER TRIGGER SYC_DELETE_LIGNE_SCENARIO2 DISABLE;

-- Désactiver triggers sync site→main
-- Sur oracle-site1 et oracle-site2 :
ALTER TRIGGER SYNC_TO_MAIN_INSERT DISABLE;
ALTER TRIGGER SYNC_TO_MAIN_UPDATE DISABLE;
ALTER TRIGGER SYNC_TO_MAIN_DELETE DISABLE;

-- Ligne 3435 : categ=50, qte=297 → sur Site1
-- AVANT UPDATE
SELECT lc.idlignecommande, lc.idproduit,
       p.idcateg, lc.quantite, 'SITE1' AS emplacement
FROM lignecommandes1@l_site1 lc
JOIN produits1@l_site1 p ON lc.idproduit = p.idproduit
WHERE lc.idlignecommande = 3435;
-- Attendu : categ=50, qte=297, sur Site1 ✓

-- UPDATE : categ50→categ35, qte 297→60
-- → conditions Site1 FAUSSES → conditions Site2 VRAIES
UPDATE lignecommandes
SET idproduit = 281,  -- categ=35
    quantite  = 60
WHERE idlignecommande = 3435;
COMMIT;

-- APRÈS UPDATE
-- Absent de Site1
SELECT COUNT(*) AS absent_site1
FROM lignecommandes1@l_site1
WHERE idlignecommande = 3435;
-- Attendu : 0 ✓ (supprimé automatiquement)

-- Présent sur Site2
SELECT lc.idlignecommande, lc.idproduit,
       p.idcateg, lc.quantite, 'MIGRÉ→SITE2 ✓' AS statut
FROM lignecommandes2@l_site2 lc
JOIN produits2@l_site2 p ON lc.idproduit = p.idproduit
WHERE lc.idlignecommande = 3435;
-- Attendu : categ=35, qte=60 ✓

-- Toujours dans BD Globale
SELECT idlignecommande, idproduit, quantite
FROM lignecommandes
WHERE idlignecommande = 3435;
-- Attendu : idproduit=281, qte=60 ✓

-- Réactiver scénario 2
ALTER TRIGGER SYC_INSERT_LIGNE_SCENARIO2 ENABLE;
ALTER TRIGGER SYC_UPDATE_LIGNE_SCENARIO2 ENABLE;
ALTER TRIGGER SYC_DELETE_LIGNE_SCENARIO2 ENABLE;
```

---

## 🔍 ÉTAPE 10 — Monitoring Final

```sql
-- Vérifier tous les objets VALID
SELECT object_name, object_type, status
FROM user_objects
WHERE object_type IN ('TABLE','PROCEDURE','TRIGGER','VIEW','INDEX')
ORDER BY object_type, object_name;
-- Attendu : tous VALID ✓

-- Vérifier les DB Links
SELECT db_link, username, host FROM user_db_links;

-- Bilan final
SELECT 'SITE 1' AS site,
    (SELECT COUNT(*) FROM lignecommandes1@l_site1) AS lignes
FROM DUAL
UNION ALL
SELECT 'SITE 2',
    (SELECT COUNT(*) FROM lignecommandes2@l_site2)
FROM DUAL
UNION ALL
SELECT 'BD GLOBALE',
    (SELECT COUNT(*) FROM lignecommandes)
FROM DUAL;
```

---

## ⚠️ Problèmes Connus & Solutions

| Erreur | Cause | Solution |
|--------|-------|----------|
| ORA-01017 | Mauvais mot de passe | `ALTER USER c##bddvente IDENTIFIED BY "1111"` |
| ORA-01045 | Pas de CREATE SESSION | `GRANT CONNECT, RESOURCE, DBA` en SYSDBA |
| ORA-00988 | Mot de passe numérique | Encadrer de guillemets doubles `"1111"` |
| ORA-12545 | Host non résolu | Utiliser les IPs Docker |
| ORA-12170 | Timeout connexion | Ajouter `DISABLE_OOB=ON` dans sqlnet.ora |
| ORA-02021 | DDL interdit via DB Link | Se connecter directement sur le site |
| ORA-04092 | COMMIT dans trigger | Supprimer le COMMIT des procédures |
| ORA-02067 | Transaction distribuée | Utiliser DML direct sans procédures |

---

## 👥 Auteurs

**BARHOINE Ayoub / MOUSSA Yassine — 2ème FI GI — 2025/2026**
