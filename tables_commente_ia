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
    -- CORRECTION : Oracle ne supporte pas BOOLEAN dans les tables -> remplacer par NUMBER(1)
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
    -- CORRECTION : ajoutez "OR date_fermeture IS NULL" sinon insertion impossible
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
    -- CORRECTION : BOOLEAN non supporté -> remplacer par NUMBER(1)
    age_min number(2) not null,
    date_publi date not null,
    prix number(10, 2) default 0.00,
    achat_integre boolean,
    -- CORRECTION : même remarque, BOOLEAN non supporté
    id_store number(10) not null,

    foreign key (id_store) references store(id),
    constraint prix_positif check (prix >= 0)
);


create table distribution (
    num varchar(10) not null,

    changelog clobm,
    -- CORRECTION : type "clobm" n'existe pas -> remplacer par "clob"
    date_pub date not null,
    public varchar2(50),
    telechargement number(10) default 0,
    id_application number(10) not null,

    primary key (num, id_application),
    foreign key (id_application) references application(id)
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
);

create table acheter (
    date_achat date default sysdate,
    rembourse boolean default false,
    -- CORRECTION : BOOLEAN non supporté -> remplacer par NUMBER(1)
    date_fin date,

    id_utilisateur number(10) not null,
    id_application number(10) not null,
    id_plateforme number(10) not null,

    primary key (id_utilisateur, id_application, id_plateforme),
    foreign key (id_utilisateur) references utilisateur(id),
    foreign key (id_application) references application(id),
    foreign key (id_plateforme) references plateforme(id)
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

    -- CORRECTION : ajouter exception when NO_DATA_FOUND pour éviter erreur si l'utilisateur ne gère aucun store

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
before insert on acheter for each row
declare
    diff number;
begin
    select (sysdate - u.date_naissance) - a.age_min into diff
    from utilisateur u, application a
    where u.id = :new.id_utilisateur
    and a.id = :new.id_application;

    -- CORRECTION : calcul d'âge incorrect, sysdate - date_naissance donne des jours !
    -- utiliser : floor(months_between(sysdate, date_naissance)/12)

    if diff < 0 then
        raise_application_error(
        -22400381,
        'L\'utilisateur n\' a pas l\'âge requis pour cette application'
        );
    end if;
end
;/
