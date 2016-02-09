alter table empire add column test_codes varchar(128) not null default ""; 

create table server_features (
  id           integer NOT NULL auto_increment,
  name         varchar(32) NOT NULL,
  who          varchar(32) NOT NULL,
  description  varchar(256) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

insert into server_features (name, who, description) values ('starmap', 'star_testers', 'Test a new version of the starmap. Very experimental.');

