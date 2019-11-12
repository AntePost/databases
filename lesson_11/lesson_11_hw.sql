/* Практическое задание по теме “Оптимизация запросов” №1
Описание задания: Создайте таблицу logs типа Archive. Пусть при каждом создании записи в таблицах users, catalogs и products в таблицу logs помещается время и дата создания записи, название таблицы, идентификатор первичного ключа и содержимое поля name.
*/

drop database if exists lesson_11;
create database lesson_11;
use lesson_11;

-- создание таблиц
create table `logs` (
	id serial,
    added_at datetime,
    tablename varchar(20),
    row_id bigint unsigned not null,
    name_field varchar(50)
) engine = archive;

create table users (
	id serial primary key,
    name varchar(50)
);

create table catalogs (
	id serial primary key,
    name varchar(50)
);

create table products (
	id serial primary key,
    name varchar(50),
    catalog_id bigint unsigned not null,
    foreign key (catalog_id) references catalogs(id)
);

-- наполнение нужными данными
-- наполнение происходит ниже

-- скрипт самого задания
delimiter //

create trigger save_users_in_log after insert on users for each row
begin
	insert into logs (added_at, tablename, row_id, name_field) values (now(), 'users', new.id, new.name);
end//

create trigger save_catalogs_in_log after insert on catalogs for each row
begin
	insert into logs (added_at, tablename, row_id, name_field) values (now(), 'catalogs', new.id, new.name);
end//

create trigger save_products_in_log after insert on products for each row
begin
	insert into logs (added_at, tablename, row_id, name_field) values (now(), 'products', new.id, new.name);
end//

delimiter ;

insert into users (name)
values
	('john'),
    ('jim'),
    ('jack');

insert into catalogs (name)
values
	('CPUs'),
    ('Memory'),
    ('Videocards');

insert into products (name, catalog_id)
values
	('Intel i7', 1),
    ('DDR4 8GB', 2),
    ('GeForce GTX 1050', 3);

select * from logs;