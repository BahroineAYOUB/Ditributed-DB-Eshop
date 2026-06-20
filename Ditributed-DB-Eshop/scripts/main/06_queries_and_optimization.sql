-- ======================================================================
-- REQUETES, PLAN D'EXECUTION ET OPTIMISATION
-- ======================================================================

-- 1. Requete : Nombre de commandes par client realisees en 2026
-- ----------------------------------------------------------------------
SELECT c.IDCLIENT, c.SOCIETECLI, COUNT(cmd.IDCOMMANDE) as NB_COMMANDES
FROM ESHOP_MAIN.CLIENTS c
JOIN ESHOP_MAIN.COMMANDES cmd ON c.IDCLIENT = cmd.IDCLIENT
WHERE EXTRACT(YEAR FROM cmd.DATECOMMANDE) = 2026
GROUP BY c.IDCLIENT, c.SOCIETECLI;

-- 2. Generation du plan d'execution
-- ----------------------------------------------------------------------
EXPLAIN PLAN FOR
SELECT c.IDCLIENT, c.SOCIETECLI, COUNT(cmd.IDCOMMANDE) as NB_COMMANDES
FROM ESHOP_MAIN.CLIENTS c
JOIN ESHOP_MAIN.COMMANDES cmd ON c.IDCLIENT = cmd.IDCLIENT
WHERE EXTRACT(YEAR FROM cmd.DATECOMMANDE) = 2026
GROUP BY c.IDCLIENT, c.SOCIETECLI;

-- Affichage du plan
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

/*
ANALYSE DEMANDEE DANS L'ENONCE :
- Sans index, le SGBD devra probablement faire un "TABLE ACCESS FULL" (Full Table Scan) 
  sur la table COMMANDES pour filtrer toutes les lignes dont l'annee est 2026.
- Ensuite, il devra faire un "HASH JOIN" ou "NESTED LOOPS" avec la table CLIENTS.
- Le Full Table Scan sur COMMANDES est tres couteux si la table contient des millions de lignes.
*/

-- 3. Proposition et creation d'un index d'optimisation
-- ----------------------------------------------------------------------
-- JUSTIFICATION :
-- L'index idx_cmd_date_client cible exactement les colonnes utilisees 
-- dans les clauses WHERE (DATECOMMANDE) et JOIN/GROUP BY (IDCLIENT).
-- De plus, comme nous utilisons une fonction (EXTRACT YEAR) sur la date, 
-- un index classique pourrait etre ignore. Un index base sur une fonction (Function-Based Index)
-- est la solution la plus performante ici.

CREATE INDEX idx_cmd_year_client ON ESHOP_MAIN.COMMANDES(EXTRACT(YEAR FROM DATECOMMANDE), IDCLIENT);

-- 4. Requete Distribuee : Chiffre d'affaires par categorie en 2026 (Somme des deux sites)
-- ----------------------------------------------------------------------
SELECT p.IDCATEG, cat.NOMDECATEGORIE, ROUND(SUM(lc.QUANTITE * p.PRIXUNITAIRE * (1 - lc.REMISE)), 2) as CA_TOTAL
FROM (
    -- Donnees du Site 1
    SELECT l1.IDPRODUIT, l1.QUANTITE, l1.REMISE, cmd1.DATECOMMANDE
    FROM ESHOP_SITE1.LIGNECOMMANDES1@site1_link l1
    JOIN ESHOP_SITE1.COMMANDES1@site1_link cmd1 ON l1.IDCOMMANDE = cmd1.IDCOMMANDE
    WHERE EXTRACT(YEAR FROM cmd1.DATECOMMANDE) = 2026
    
    UNION ALL
    
    -- Donnees du Site 2
    SELECT l2.IDPRODUIT, l2.QUANTITE, l2.REMISE, cmd2.DATECOMMANDE
    FROM ESHOP_SITE2.LIGNECOMMANDES2@site2_link l2
    JOIN ESHOP_SITE2.COMMANDES2@site2_link cmd2 ON l2.IDCOMMANDE = cmd2.IDCOMMANDE
    WHERE EXTRACT(YEAR FROM cmd2.DATECOMMANDE) = 2026
) lc
JOIN ESHOP_MAIN.PRODUITS p ON lc.IDPRODUIT = p.IDPRODUIT
JOIN ESHOP_MAIN.CATEGORIE cat ON p.IDCATEG = cat.IDCATEG
GROUP BY p.IDCATEG, cat.NOMDECATEGORIE
ORDER BY CA_TOTAL DESC;
