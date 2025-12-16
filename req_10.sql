/* Quels sont les utilisateurs ayant laissé un avis sur chaque application qu’ils ont achetée ? */
f

SELECT
    U.id,
    U.nom
FROM UTILISATEUR U, ACHETER A, EVALUER E
WHERE U.id = A.id_utilisateur
    AND A.id_application = E.id_application(+)
    AND A.id_utilisateur = E.id_utilisateur(+)
GROUP BY U.id, U.nom
HAVING COUNT(DISTINCT A.id_application) = COUNT(DISTINCT E.id_application);
