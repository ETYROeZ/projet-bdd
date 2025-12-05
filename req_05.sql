/* Quel est le revenu mensuel d’un store donné le long d’une année ? */
SELECT
    EXTRACT(MONTH FROM a.date_achat) AS mois,
    SUM(ap.prix) AS revenu_mensuel
FROM
    ACHETER a, APPLICATION ap
WHERE
    a.id_application = ap.id
    AND ap.id_store = :store_id
    AND EXTRACT(YEAR FROM a.date_achat) = :annee
GROUP BY
    EXTRACT(MONTH FROM a.date_achat)
ORDER BY
    mois;
