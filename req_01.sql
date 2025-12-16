/* Quels utilisateurs ont ouvert un store ?  */



SELECT U.id, U.nom
FROM UTILISATEUR U, Store S
WHERE U.id = S.id_gestionnaire
