-- ======================================================================
-- TRIGGERS POUR SCENARIO 2 (Fragmentation Horizontale Primaire)
-- R1 (Site 1) : Quantite >= 100
-- R2 (Site 2) : Quantite < 100
-- ======================================================================

-- Remarque : Ces triggers utilisent les procedures stockees distantes 
-- "insertligne", "updateligne" et "deleteligne"

CREATE OR REPLACE TRIGGER ESHOP_MAIN.SYC_INSERT_LIGNE
AFTER INSERT ON ESHOP_MAIN.LIGNECOMMANDES
FOR EACH ROW
BEGIN
    IF :NEW.QUANTITE >= 100 THEN
        ESHOP_SITE1.insertligne@site1_link(:NEW.IDLIGNECOMMANDE, :NEW.IDCOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE);
    ELSE
        ESHOP_SITE2.insertligne@site2_link(:NEW.IDLIGNECOMMANDE, :NEW.IDCOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE);
    END IF;
END;
/

CREATE OR REPLACE TRIGGER ESHOP_MAIN.SYC_DELETE_LIGNE
AFTER DELETE ON ESHOP_MAIN.LIGNECOMMANDES
FOR EACH ROW
BEGIN
    IF :OLD.QUANTITE >= 100 THEN
        ESHOP_SITE1.deleteligne@site1_link(:OLD.IDLIGNECOMMANDE);
    ELSE
        ESHOP_SITE2.deleteligne@site2_link(:OLD.IDLIGNECOMMANDE);
    END IF;
END;
/

CREATE OR REPLACE TRIGGER ESHOP_MAIN.SYC_UPDATE_LIGNE
AFTER UPDATE ON ESHOP_MAIN.LIGNECOMMANDES
FOR EACH ROW
BEGIN
    -- Si la ligne reste sur Site 1
    IF :OLD.QUANTITE >= 100 AND :NEW.QUANTITE >= 100 THEN
        ESHOP_SITE1.updateligne@site1_link(:NEW.IDLIGNECOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE);
        
    -- Si la ligne reste sur Site 2
    ELSIF :OLD.QUANTITE < 100 AND :NEW.QUANTITE < 100 THEN
        ESHOP_SITE2.updateligne@site2_link(:NEW.IDLIGNECOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE);
        
    -- Si la ligne migre de Site 1 vers Site 2
    ELSIF :OLD.QUANTITE >= 100 AND :NEW.QUANTITE < 100 THEN
        ESHOP_SITE1.deleteligne@site1_link(:OLD.IDLIGNECOMMANDE);
        ESHOP_SITE2.insertligne@site2_link(:NEW.IDLIGNECOMMANDE, :NEW.IDCOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE);
        
    -- Si la ligne migre de Site 2 vers Site 1
    ELSIF :OLD.QUANTITE < 100 AND :NEW.QUANTITE >= 100 THEN
        ESHOP_SITE2.deleteligne@site2_link(:OLD.IDLIGNECOMMANDE);
        ESHOP_SITE1.insertligne@site1_link(:NEW.IDLIGNECOMMANDE, :NEW.IDCOMMANDE, :NEW.IDPRODUIT, :NEW.QUANTITE, :NEW.REMISE);
    END IF;
END;
/
