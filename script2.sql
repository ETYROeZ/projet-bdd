-- Tables

-- entitées

create table utilisateur (
    id number(10) primary key,

    pays varchar2(100) not null,
    nom varchar2(255) not null,
    mot_de_passe varchar2(255) not null
        check (length(mot_de_passe) > 8),
    email varchar2(255) unique not null,
    date_creation date default sysdate,
    email_valide number(1) default 0,
    date_naissance date
);


create table store (
    id number(10) primary key,

    email varchar2(255) unique not null,
    pays varchar2(100) not null,
    date_ouverture date not null,
    date_fermeture date,
    nom varchar2(255) not null,
    id_gestionnaire number(10) unique not null,

    foreign key (id_gestionnaire) references utilisateur(id),
    constraint fermeture check (date_fermeture > date_ouverture)
);


create table plateforme (
    id number(10) primary key,

    libelle varchar2(100) unique not null
);


create table application (
    id number(10) primary key,

    nom varchar2(255) not null,
    description clob,
    categorie varchar2(100),
    est_public number(1) default 1,
    age_min number(2) not null,
    date_publi date not null,
    date_retrait date not null,
    prix number(10, 2) default 0.00,
    achat_integre number(1) default 0,
    id_store number(10) not null,

    foreign key (id_store) references store(id),
    constraint date_retait_sup_date_publi check (date_retrait > date_publi),
    constraint prix_positif check (prix >= 0),
    constraint prix_not_null check (prix is not null),
    constraint publi_date_valide check (
        (est_public = 0) or (est_public = 1 and date_publi is not null)
    )
);


create table distribution (
    num varchar(10) not null,

    changelog clob,
    date_pub date not null,
    est_public varchar2(50),
    telechargement number(10) default 0,
    id_application number(10) not null,

    primary key (num, id_application),
    foreign key (id_application) references application(id),
    constraint telechargement_sup_0 check (telechargement >= 0)
);

-- NOTE: lui faire les triggers nécessaires.
create table remboursement (
    id number(10) primary key,
    id_utilisateur number(10) not null,
    id_application number(10) not null,
    date_emission date,
    motif varchar(255),
    status varchar(24) default 'en attente',

    foreign key (id_utilisateur) references utilisateur(id),
    foreign key (id_application) references application(id),
    constraint enum_status check (status in ('en attente', 'validé', 'refusé'))
);

-- associations

create table suivre (
    id_utilisateur number(10) not null,
    id_store number(10) not null,

    primary key (id_utilisateur, id_store),
    foreign key (id_utilisateur) references utilisateur(id),
    foreign key (id_store) references store(id)
);

create table evaluer (
    id_utilisateur number(10) not null,
    id_application number(10) not null,
    titre varchar2(255),
    contenu clob,
    date_publi date default sysdate,
    date_expir date,
    note number(1) check (note >= 1 and note <= 5),

    primary key (id_utilisateur, id_application),
    foreign key (id_utilisateur) references utilisateur(id),
    foreign key (id_application) references application(id),

    constraint titre_plus_contenu check (
        (titre is not null and contenu is not null))
);

create table acheter (
    date_achat date default sysdate,
    rembourse number(1) default 0,
    date_fin date,

    id_utilisateur number(10) not null,
    id_application number(10) not null,
    id_plateforme number(10) not null,

    primary key (id_utilisateur, id_application, id_plateforme),
    foreign key (id_utilisateur) references utilisateur(id),
    foreign key (id_application) references application(id),
    foreign key (id_plateforme) references plateforme(id),

    constraint date_fin_superieure check (date_fin > date_achat),
    constraint remboursement_ check (
        (rembourse = 0 and date_fin is null )
        or (rembourse = 1 and date_fin is not null))
);

create table supporter (
    id_application number(10) not null,
    id_plateforme number(10) not null,

    primary key (id_application, id_plateforme),
    foreign key (id_application) references application(id),
    foreign key (id_plateforme) references plateforme(id)
);


-- Contraintes

create sequence utilisateur_ic start with 1 increment by 1;
create sequence store_ic start with 1 increment by 1;
create sequence plateforme_ic start with 1 increment by 1;
create sequence application_ic start with 1 increment by 1;

create or replace trigger uti_auto_incr
before insert on utilisateur for each row
begin
    :new.id := utilisateur_ic.nextval;
end
;/

create or replace trigger sto_auto_incr
before insert on store for each row
begin
    :new.id := store_ic.nextval;
end
;/

create or replace trigger pla_auto_incr
before insert on plateforme for each row
begin
    :new.id := plateforme_ic.nextval;
end
;/

create or replace trigger app_auto_incr
before insert on application for each row
begin
    :new.id := application_ic.nextval;
end
;/

create or replace trigger auto_suivi
before insert on suivre for each row
declare
    store_id number;
begin
    select s.id into store_id
    from store s
    where s.id_gestionnaire = :new.id_utilisateur;

    if store_id = :new.id_store then
        raise_application_error(
        -22400381,
        'Un utilisateur ne peut suivre son propre store.'
        );
    end if;
end
;/

--Un utilisateur doit avoir un mot de passe d’une longueur minimum de 8 caractères(check) comportant au moins une minuscule,
--majuscule, un chiffre, et un symbole.

create or replace trigger verif_et_hash_mdp
before insert or update of mot_de_passe on utilisateur
for each row
declare
    mdp varchar2(255);
begin
    -- éviter le double hash lors d'un UPDATE
    if inserting or :old.mot_de_passe != :new.mot_de_passe then

        mdp := :new.mot_de_passe;

        if regexp_instr(mdp, '[A-Z]') = 0 then
            raise_application_error(
                -22400381,
                'Le mot de passe doit contenir au moins une lettre majuscule.'
            );
        end if;

        if regexp_instr(mdp, '[a-z]') = 0 then
            raise_application_error(
                -22400381,
                'Le mot de passe doit contenir au moins une lettre minuscule.'
            );
        end if;

        if regexp_instr(mdp, '[0-9]') = 0 then
            raise_application_error(
                -22400381,
                'Le mot de passe doit contenir au moins un chiffre.'
            );
        end if;

        if regexp_instr(mdp, '[^a-zA-Z0-9]') = 0 then
            raise_application_error(
                -22400381,
                'Le mot de passe doit contenir au moins un symbole.'
            );
        end if;

        :new.mot_de_passe := standard_hash(mdp, 'SHA256');
    end if;
end;
/



create or replace trigger verif_age
before insert on acheter
for each row
declare
    age number;
    min_age number;
begin
    -- âge réel en années (Oracle : months_between/12)
    select floor(months_between(sysdate, u.date_naissance) / 12),
           a.age_min
    into age, min_age
    from utilisateur u
    join application a
        on a.id = :new.id_application
    where u.id = :new.id_utilisateur;

    if age < min_age then
        raise_application_error(-22400381,
            'L''utilisateur n''a pas l''âge requis pour cette application.');
    end if;
end;
/

 -- Le nombre de téléchargements doit être supérieur ou égal à 0. (ajout d'un check dans la table distribution)

 -- Les numéros de distribution doivent être en ordre croissant lorsque les distributions sont triées par date.
 create or replace trigger verif_ordre_des_distributions
 before insert or update on distribution
 for each row
 declare
     cpt number;
 begin
     select count(*) into cpt
     from distribution d
     where d.date_pub < :new.date_pub
         and d.num > :new.num
         and d.id_application = :new.id_application;

     if cpt > 0 then
         raise_application_error(
             -22400381,
             'La nouvelle date a un numero qui est inferieur a l''ancienne date'
         );
     end if;

     select count(*) into cpt
     from distribution d
     where d.date_pub > :new.date_pub
         and d.num < :new.num
         and d.id_application = :new.id_application;

     if cpt > 0 then
         raise_application_error(
             -22400381,
             'La nouvelle date a un numero qui est superieur a une date plus recente'
         );
     end if;
 end;
 /



-- Le titre d'un avis doit être associé au contenu, et le contenu doit avoir un titre.(J'ai fait un check dans evaluer)

-- L'utilisateur doit avoir acheté l'application qu'il évalue.
create or replace trigger verif_achat_avant_evaluation
before insert or update on evaluer
for each row
declare
    cpt number;
begin
    select count(*) into cpt
    from acheter a
    where a.id_utilisateur = :new.id_utilisateur
    and a.id_application = :new.id_application
    and a.rembourse = 0;

    if cpt = 0 then
        raise_application_error(
            -22400381,
            'L'utilisateur n'as jamais acheté cet application, impossible d''evaluer'
            );
    end if;
end;
/

    --La date de fin doit être supérieure à la date d’achat. (Check table acheter)

    --Si l’achat est remboursé, la date de fin doit être renseignée.(Check table acheter)

  --Un utilisateur ne peut être remboursé que si sa demande se situe dans les 14 jours suivant son achat.
create or replace trigger remboursement_14j
before insert or update on remboursement
for each row
declare
    cpt number;
begin
    select count(*) into cpt
    from acheter a
    where a.id_utilisateur = :new.id_utilisateur
      and a.id_application = :new.id_application
      and :new.date_emission <= a.date_achat + 14;

    if cpt = 0 then
        raise_application_error(
            -22400381,
            'Remboursement impossible'
        );
    end if;
end;
/

create or replace function contenu_ratio(contenu clob)
return number
as
    texte varchar2(32000);
    positive number := 0;
    negative number := 0;
    total number := 0;
begin
    if contenu is null then
        return 50;
    end if;

    texte := lower(substr(contenu, 1, 32000));
    if texte like '%bien%' then positive := positive + 1; end if;
    if texte like '%rapide%' then positive := positive + 1; end if;
    if texte like '%stable%' then positive := positive + 1; end if;
    if texte like '%performante%' then positive := positive + 1; end if;
    if texte like '%pratique%' then positive := positive + 1; end if;
    if texte like '%moderne%' then positive := positive + 1; end if;
    if texte like '%intuitive%' then positive := positive + 1; end if;
    if texte like '%facile%' then positive := positive + 1; end if;
    if texte like '%fluide%' then positive := positive + 1; end if;
    if texte like '%efficace%' then positive := positive + 1; end if;
    if texte like '%utile%' then positive := positive + 1; end if;
    if texte like '%fiable%' then positive := positive + 1; end if;
    if texte like '%ergonomique%' then positive := positive + 1; end if;
    if texte like '%agréable%' then positive := positive + 1; end if;
    if texte like '%recommandée%' then positive := positive + 1; end if;

    if texte like '%mauvais%' then negative := negative + 1; end if;
    if texte like '%lente%' then negative := negative + 1; end if;
    if texte like '%incomplete%' then negative := negative + 1; end if;
    if texte like '%bugguée%' then negative := negative + 1; end if;
    if texte like '%inutile%' then negative := negative + 1; end if;
    if texte like '%instable%' then negative := negative + 1; end if;
    if texte like '%compliquée%' then negative := negative + 1; end if;
    if texte like '%confuse%' then negative := negative + 1; end if;
    if texte like '%frustrante%' then negative := negative + 1; end if;
    if texte like '%nulle%' then negative := negative + 1; end if;
    if texte like '%décevante%' then negative := negative + 1; end if;
    if texte like '%peu pratique%' then negative := negative + 1; end if;
    if texte like '%lent%' then negative := negative + 1; end if;
    if texte like '%bug%' then negative := negative + 1; end if;
    if texte like '%plante%' then negative := negative + 1; end if;

    total := positive + negative;

        if total = 0 then
            return 50;
        end if;

        return 50 + ((positive - negative) / total) * 50;
    end;
    /

create or replace trigger verif_eval_avis
before insert or update on evaluer
for each row
declare
    ratio number ;
begin
    ratio := contenu_ratio(:new.contenu);

    if :new.note in (1,2) then
        if ratio > 50 then
            raise_application_error(
                -22400381,
                'Pour une note negatif un avis positive');
        end if;
    end if;

    if :new.note in (4,5) then
        if ratio < 50 then
            raise_application_error(
                -22400381,
                'Pour une note positif un avis negatif');
        end if;
    end if;
end
/

--Un utilisateur qui a acheté une application X doit d'abord être
-- remboursé avant de pouvoir l'acquérir à nouveau. (trigger)
create or replace trigger acheter_meme_application
before insert on acheter
for each row
declare
    cpt number;
begin
    select count(*) into cpt
    from acheter a
    where a.id_utilisateur = :new.id_utilisateur
      and a.id_application = :new.id_application
      and a.rembourse = 0;

    if cpt > 0 then
        raise_application_error(
            -22400381,
            'Vous devez etre remboursé avant de pouvoir acquérir à nouveau'
        );
    end if;
end;
/



--Seuls les utilisateurs majeurs dans leur pays peuvent ouvrir un magasin. (trigger)
create or replace trigger verif_age_pour_store
before insert or update on store
for each row
declare
    age_gestio number;
begin
    select floor(months_between(sysdate, u.date_naissance) /12) into age_gestio -- exemple : 15/12/2025  15/9/2025 = 3/12
    from utilisateur u
    where u.id = :new.id_gestionnaire
    and u.pays = :new.pays;


    if age_gestio < 18 then
        raise_application_error(
            -22400381,
             'utilisateur n''est pas majeur, interdiction d''ouvrir un store');
    end if;
end;
/

--Plusieurs applications ne peuvent pas avoir le même nom,
-- sauf si l’application ayant le même nom est supprimée.  (trigger)
create or replace trigger verifi_doublons_appli
before insert or update on application
for each row
declare
    cpt number;
begin
    select count(*) into cpt
    from application a
    where lower(a.nom) = lower(:new.nom)
        and a.id <> :new.id          -- on verfie si une l'application existe avec ce nom, et qu'elle est active
        and a.date_retrait > sysdate;

    if cpt > 0 then
        raise_application_error(
            -22400381,
            'Il existe deja une application avec ce nom, qui est active');
    end if;
end;
/
