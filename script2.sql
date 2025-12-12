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
    email_valide boolean default false,
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
    public boolean default true,
    age_min number(2) not null,
    date_publi date not null,
    prix number(10, 2) default 0.00,
    achat_integre boolean,
    id_store number(10) not null,

    foreign key (id_store) references store(id),
    constraint prix_positif check (prix >= 0)
);


create table distribution (
    num varchar(10) not null,

    changelog clobm,
    date_pub date not null,
    public varchar2(50),
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
    foreign key (id_application) references application(id)

    constraint titre_plus_contenu check (
        (titre is not null and contenu is not null)
);

create table acheter (
    date_achat date default sysdate,
    rembourse boolean default false,
    date_fin date,

    id_utilisateur number(10) not null,
    id_application number(10) not null,
    id_plateforme number(10) not null,

    primary key (id_utilisateur, id_application, id_plateforme),
    foreign key (id_utilisateur) references utilisateur(id),
    foreign key (id_application) references application(id),
    foreign key (id_plateforme) references plateforme(id)

    constraint date_fin_superieure check (date_fin > date_achat),
    constraint remboursement_ check (
        (rembourse = 0 and date_fin is null )
        or (rembourse = 1 and date_fin is not null)
);

create table supporter (
    id_application number(10) not null,
    id_plateforme number(10) not null,

    primary key (id_application, id_plateforme),
    foreign key (id_application) references application(id),
    foreign key (id_plateforme) references plateforme(id)
);


-- Contraintes

create sequence utilisateur_ic start 1 increment 1;
create sequence store_ic start 1 increment 1;
create sequence plateforme_ic start 1 increment 1;
create sequence application_ic start 1 increment 1;

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

create or replace trigger hash_mot_de_passe
before insert or update of mot_de_passe on utilisateur
for each row
begin
    :new.mot_de_passe := STANDARD_HASH(:new.mot_de_passe, 'SHA256');
end
;/


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
        and d.num > :new.num;

    if cpt > 0 then
        raise_application_error(
            -22400381,
            'La nouvelle date a un numero qui est inferieur a l''ancienne date'
            );
    end if;

    select count(*) into cpt
    from distribution d
    where d.date_pub > :new.date_pub  -- L'ancienne date de publication est superieur a la nouvelle date     --  et le numero de distribution est inferieur au new numero
        and d.num < :new.num;       -- Jeudi 12 > Mercredi 11
                                    -- 3        <         4
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
    and a.id_application = :new.id_application;

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
            -22400600,
            'Remboursement impossible'
        );
    end if;
end;
/
