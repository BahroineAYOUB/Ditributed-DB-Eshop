# Rapport de Projet : Bases de Données Distribuées - Fragmentation et Optimisation

**Soumis à :** mohamed.bahaj@uhp.ac.ma

Ce rapport dresse la synthèse des scripts essentiels et de l'architecture mise en place pour répondre aux deux scénarios de fragmentation horizontale de la base de données relationnelle "EShop".

## 1. Configuration Docker Compose
L'environnement a été virtualisé à l'aide de Docker Compose pour garantir la portabilité. Trois conteneurs basés sur l'image Oracle 21c (Express Edition) ont été instanciés :
- `oracle-main` : Nœud central contenant le schéma global.
- `oracle-site1` : Nœud distant pour le fragment 1 (Grossistes / Catégorie 50).
- `oracle-site2` : Nœud distant pour le fragment 2 (Détaillants / Catégorie 35).
*(Conseil : Insérez ici une capture de votre fichier docker-compose.yml illustrant les services)*

## 2. Configuration réseaux Networking : 3 machines
Les trois conteneurs ont été connectés via un réseau de type "bridge" nommé `eshop_network`. Ce réseau privé permet une résolution DNS interne, ce qui signifie que chaque machine peut communiquer avec les autres via leur nom d'hôte (`oracle-main`, `oracle-site1`, `oracle-site2`) au lieu d'utiliser des adresses IP statiques, ce qui facilite grandement l'évolutivité.

## 3. Configuration du Site Principal
Le site principal a été initialisé via le script `01_init_main.sql`. Il centralise :
- Les tables dimensionnelles de référence (Clients, Employés, Fournisseurs, Produits, Catégorie).
- La table globale `COMMANDES`.
- La table globale `LIGNECOMMANDES`, qui sert de point d'entrée pour les écritures et pour la vue globale avant routage.

## 4. Configuration des Sites Distants
Les sites distants ont été initialisés (`01_init_site1.sql` et `01_init_site2.sql`) avec les tables cibles pour héberger les fragments. Ils contiennent les structures `CLIENTS1`, `COMMANDES1`, `PRODUITS1` et `LIGNECOMMANDES1` (et leurs équivalents pour le site 2) pour accueillir de manière sécurisée les données répliquées et fragmentées.

## 5. Tests de Connectivité
La connectivité a été validée à deux niveaux :
1. **Niveau réseau** (Ping) entre les conteneurs Docker pour vérifier la résolution DNS interne.
2. **Niveau SGBD** en exécutant des requêtes de test de type `SELECT * FROM DUAL@site1_link` depuis le nœud principal pour garantir l'authentification croisée.

## 6. Création des Utilisateurs
Sur chaque base de données, un utilisateur/schéma dédié a été créé avec les privilèges appropriés :
- Sur Main : `ESHOP_MAIN`
- Sur Site 1 : `ESHOP_SITE1`
- Sur Site 2 : `ESHOP_SITE2`
Des privilèges stricts comme `CREATE DATABASE LINK`, `CREATE PROCEDURE`, et `CREATE TRIGGER` leur ont été accordés pour permettre l'architecture distribuée.

## 7. Configuration des Database Links : Configuration automatique des liens
Les liens de base de données ont été créés sur le site principal pour pointer vers les sites distants à l'aide de l'alias de service TNS dynamique fourni par l'architecture réseau de Docker :
```sql
CREATE DATABASE LINK site1_link CONNECT TO ESHOP_SITE1 IDENTIFIED BY "Eshop1234" USING '//oracle-site1:1521/XEPDB1';
CREATE DATABASE LINK site2_link CONNECT TO ESHOP_SITE2 IDENTIFIED BY "Eshop1234" USING '//oracle-site2:1521/XEPDB1';
```

## 8. Tables Fragmentées sur les Sites Distants
La table `LIGNECOMMANDES` est au cœur de la stratégie de fragmentation (Horizontale dérivée pour le Scénario 1, et Horizontale primaire pour le Scénario 2). Pour le scénario primaire actif, le site 1 héberge les grosses commandes (`Quantite >= 100`) et le site 2 héberge les commandes de détail (`Quantite < 100`).

## 9. Architecture des Procédures Stockées
Pour des raisons de sécurité, de performance et d'encapsulation métier, les écritures ne se font pas par des requêtes SQL `INSERT` directes à travers les DB Links. Des procédures stockées PL/SQL ont été déployées sur `ESHOP_SITE1` et `ESHOP_SITE2` :
- `insertligne (p_idligne, p_idcmd, p_idprod, p_qte, p_remise)`
- `updateligne (...)`
- `deleteligne (p_idligne)`
Elles reçoivent les paramètres du serveur principal et gèrent l'intégrité locale lors de l'insertion ou suppression des tuples.

## 10. Architecture des Triggers
Le site principal possède des triggers avancés (`SYC_INSERT_LIGNE`, `SYC_DELETE_LIGNE`, `SYC_UPDATE_LIGNE`) qui interceptent le flux DML utilisateur.
- Le trigger évalue la condition (ex: `:NEW.QUANTITE >= 100`).
- Il agit comme un routeur distribué et invoque la procédure stockée distante adéquate (`ESHOP_SITE1.insertligne@site1_link(...)`).
- Le trigger d'Update dispose d'une logique conditionnelle lui permettant de migrer une ligne entre les sites distants si sa quantité modifiée lui fait changer de palier.

## 11. Optimisation des Requêtes
L'optimisation s'est focalisée sur l'analyse analytique : *Calculer le nombre de commandes par client en 2026*.
Le plan d'exécution `EXPLAIN PLAN` standard révélait une opération très coûteuse de type "Full Table Scan" sur la table globale `COMMANDES`, le moteur de la base devant balayer chaque ligne pour évaluer la fonction `EXTRACT(YEAR FROM DATECOMMANDE)` à la volée.

## 12. Stratégie d’Indexation Multi-Niveaux
Pour optimiser les accès en lecture sur cet axe analytique temporel, nous avons défini un **Function-Based Index** (Index basé sur fonction) combiné à la clé étrangère :
```sql
CREATE INDEX idx_cmd_year_client ON ESHOP_MAIN.COMMANDES(EXTRACT(YEAR FROM DATECOMMANDE), IDCLIENT);
```
Cette stratégie permet à l'optimiseur de filtrer directement l'année sans accéder aux blocs de données, et de regrouper par client depuis le bloc d'index lui-même.

## 13. Analyse Comparative des Performances
- **Sans index** : Coût d'exécution I/O extrêmement élevé sur de gros volumes, obligation de réaliser des accès disques pour évaluer la date sur la totalité de la table (Table Access Full).
- **Avec l'index sur fonction** : Le plan d'exécution bascule sur un "Index Range Scan", diminuant le coût global de manière drastique et garantissant un temps de réponse constant même face à une croissance des données historiques.

## 14. Monitoring et Maintenance des Performances
La vue `TABLE(DBMS_XPLAN.DISPLAY)` est utilisée comme outil principal de monitoring pour valider la prise en charge de nos stratégies d'indexation par l'optimiseur Oracle. En production distribuée, un suivi régulier du plan d'exécution est recommandé pour s'assurer que les statistiques du dictionnaire de données justifient toujours l'utilisation de l'index.

---
*Ce rapport technique et architectural a vocation à accompagner la présentation orale visant à valider la synchronisation des insertions, modifications et suppressions distribuées.*
