-- ======================================================================
-- PROCEDURES STOCKEES POUR SITE 1
-- ======================================================================

CREATE OR REPLACE PROCEDURE ESHOP_SITE1.insertligne (
    p_idligne   IN NUMBER,
    p_idcmd     IN NUMBER,
    p_idprod    IN NUMBER,
    p_qte       IN NUMBER,
    p_remise    IN NUMBER
) AS
BEGIN
    INSERT INTO ESHOP_SITE1.LIGNECOMMANDES1 (IDLIGNECOMMANDE, IDCOMMANDE, IDPRODUIT, QUANTITE, REMISE)
    VALUES (p_idligne, p_idcmd, p_idprod, p_qte, p_remise);
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Erreur : Ligne de commande deja existante sur Site 1.');
    WHEN OTHERS THEN
        RAISE;
END insertligne;
/

CREATE OR REPLACE PROCEDURE ESHOP_SITE1.updateligne (
    p_idligne   IN NUMBER,
    p_idprod    IN NUMBER,
    p_qte       IN NUMBER,
    p_remise    IN NUMBER
) AS
BEGIN
    UPDATE ESHOP_SITE1.LIGNECOMMANDES1
    SET IDPRODUIT = p_idprod,
        QUANTITE = p_qte,
        REMISE = p_remise
    WHERE IDLIGNECOMMANDE = p_idligne;
END updateligne;
/

CREATE OR REPLACE PROCEDURE ESHOP_SITE1.deleteligne (
    p_idligne   IN NUMBER
) AS
BEGIN
    -- Suppression de la ligne de commande
    DELETE FROM ESHOP_SITE1.LIGNECOMMANDES1
    WHERE IDLIGNECOMMANDE = p_idligne;
    
    -- NB : L'enonce demande de supprimer les tuples des autres tables liees a LigneCommandes.
    -- Dans notre schema, LigneCommandes est une table fille qui reference Commandes et Produits.
    -- Elle n'a pas de tables enfants. L'instruction DELETE simple suffit donc.
END deleteligne;
/
