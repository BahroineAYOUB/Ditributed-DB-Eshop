-- ======================================================================
-- TRIGGERS POUR SCENARIO 1 (Fragmentation Horizontale Derivee)
-- R1 (Site 1) : idCategorie = 50 AND quantite > 100
-- R2 (Site 2) : idCategorie = 35 AND quantite > 50
-- ======================================================================

-- Remarque : Ces triggers utilisent les procedures stockees distantes 
-- "insertligne", "updateligne" et "deleteligne"

CREATE OR REPLACE TRIGGER ESHOP_MAIN.SYC_INSERT_LIGNE
AFTER INSERT ON ESHOP_MAIN.LIGNECOMMANDES
FOR EACH ROW
DECLARE
    v_idcateg NUMBER;
BEGIN
    -- Recuperation de la categorie du produit pour la fragmentation derivee
    SELECT IDCATEG INTO v_idcateg FROM ESHOP_MAIN.PRODUITS WHERE IDPRODUIT = :NEW.IDPRODUIT;
    
    IF v_idcateg = 50 AND :NEW.QUANTITE > 100 THEN
        ESHOP_SITE1.insertligne@site1_link(:NEW.IDLIGNECOMMANDE, :NEW.IDCOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE);
    ELSIF v_idcateg = 35 AND :NEW.QUANTITE > 50 THEN
        ESHOP_SITE2.insertligne@site2_link(:NEW.IDLIGNECOMMANDE, :NEW.IDCOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE);
    END IF;
END;
/

CREATE OR REPLACE TRIGGER ESHOP_MAIN.SYC_DELETE_LIGNE
AFTER DELETE ON ESHOP_MAIN.LIGNECOMMANDES
FOR EACH ROW
DECLARE
    v_idcateg NUMBER;
BEGIN
    SELECT IDCATEG INTO v_idcateg FROM ESHOP_MAIN.PRODUITS WHERE IDPRODUIT = :OLD.IDPRODUIT;
    
    IF v_idcateg = 50 AND :OLD.QUANTITE > 100 THEN
        ESHOP_SITE1.deleteligne@site1_link(:OLD.IDLIGNECOMMANDE);
    ELSIF v_idcateg = 35 AND :OLD.QUANTITE > 50 THEN
        ESHOP_SITE2.deleteligne@site2_link(:OLD.IDLIGNECOMMANDE);
    END IF;
END;
/

CREATE OR REPLACE TRIGGER ESHOP_MAIN.SYC_UPDATE_LIGNE
AFTER UPDATE ON ESHOP_MAIN.LIGNECOMMANDES
FOR EACH ROW
DECLARE
    v_old_idcateg NUMBER;
    v_new_idcateg NUMBER;
    v_was_site1 BOOLEAN := FALSE;
    v_was_site2 BOOLEAN := FALSE;
    v_is_site1 BOOLEAN := FALSE;
    v_is_site2 BOOLEAN := FALSE;
BEGIN
    SELECT IDCATEG INTO v_old_idcateg FROM ESHOP_MAIN.PRODUITS WHERE IDPRODUIT = :OLD.IDPRODUIT;
    SELECT IDCATEG INTO v_new_idcateg FROM ESHOP_MAIN.PRODUITS WHERE IDPRODUIT = :NEW.IDPRODUIT;
    
    -- Evaluation de l'ancien etat
    IF v_old_idcateg = 50 AND :OLD.QUANTITE > 100 THEN v_was_site1 := TRUE; END IF;
    IF v_old_idcateg = 35 AND :OLD.QUANTITE > 50 THEN v_was_site2 := TRUE; END IF;
    
    -- Evaluation du nouvel etat
    IF v_new_idcateg = 50 AND :NEW.QUANTITE > 100 THEN v_is_site1 := TRUE; END IF;
    IF v_new_idcateg = 35 AND :NEW.QUANTITE > 50 THEN v_is_site2 := TRUE; END IF;
    
    -- Application des regles
    IF v_was_site1 AND v_is_site1 THEN
        ESHOP_SITE1.updateligne@site1_link(:NEW.IDLIGNECOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE);
    ELSIF v_was_site2 AND v_is_site2 THEN
        ESHOP_SITE2.updateligne@site2_link(:NEW.IDLIGNECOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE);
    ELSE
        -- Migration entre sites ou sortie de la fragmentation
        IF v_was_site1 THEN ESHOP_SITE1.deleteligne@site1_link(:OLD.IDLIGNECOMMANDE); END IF;
        IF v_was_site2 THEN ESHOP_SITE2.deleteligne@site2_link(:OLD.IDLIGNECOMMANDE); END IF;
        
        IF v_is_site1 THEN ESHOP_SITE1.insertligne@site1_link(:NEW.IDLIGNECOMMANDE, :NEW.IDCOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE); END IF;
        IF v_is_site2 THEN ESHOP_SITE2.insertligne@site2_link(:NEW.IDLIGNECOMMANDE, :NEW.IDCOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE); END IF;
    END IF;
END;
/
