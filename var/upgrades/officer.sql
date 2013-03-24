
create table office (
    id              int(11) not null auto_increment,
    alliance_id     int(11) not null,
    empire_id       int(11) not null,
    type            varchar(30) not null,
    primary key (id)
);

create table auto_vote (
    id              int(11) not null auto_increment,
    empire_id       int(11) not null,
    station_id      int(11) not null,
    type            varchar(30) not null,
    primary key (id)
);


