/* Практическое задание по теме “Транзакции, переменные, представления” №1
Описание задания: В базе данных shop и sample присутствуют одни и те же таблицы, учебной базы данных. Переместите запись id = 1 из таблицы shop.users в таблицу sample.users. Используйте транзакции.
*/

drop database if exists shop_2;
create database shop_2;
drop database if exists sample;
create database sample;

-- создание таблиц
use shop_2;
create table users (
	id serial primary key,
    name varchar(255)
);
use sample;
create table users (
	id serial primary key,
    name varchar(255)
);

-- наполнение нужными данными
use shop_2;
insert into users (id, name)
values
	(1, 'john'),
    (2, 'jack'),
    (3, 'jim');

-- скрипт самого задания
select * from shop_2.users; -- в таблице есть запись с id 1
select * from sample.users; -- в таблице нет записи с id 1

start transaction;
	insert into sample.users (id, name)
    select id, name from shop_2.users
    where id = 1;
    delete from shop_2.users
    where id = 1;
commit;

select * from shop_2.users; -- в таблице нет записи с id 1
select * from sample.users; -- в таблице есть запись с id 1

/* Практическое задание по теме “Транзакции, переменные, представления” №2
Описание задания: Создайте представление, которое выводит название name товарной позиции из таблицы products и соответствующее название каталога name из таблицы catalogs.
*/

drop database if exists lesson_09;
create database lesson_09;
use lesson_09;

-- создание таблиц
create table catalogs (
	id serial primary key,
    name varchar(255)
);

create table products (
	id serial primary key,
    name varchar(255),
    catalog_id bigint unsigned not null,
    foreign key (id) references catalogs(id)
);

-- наполнение нужными данными
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

-- скрипт самого задания
create view products_with_catalogs as
select p.name as 'product_name', c.name as 'catalog_name'
from products as p
join catalogs as c
on p.catalog_id = c.id;

select * from products_with_catalogs;

/* Практическое задание по теме “Хранимые процедуры и функции, триггеры” №1
Описание задания: Создайте хранимую функцию hello(), которая будет возвращать приветствие, в зависимости от текущего времени суток. С 6:00 до 12:00 функция должна возвращать фразу "Доброе утро", с 12:00 до 18:00 функция должна возвращать фразу "Добрый день", с 18:00 до 00:00 — "Добрый вечер", с 00:00 до 6:00 — "Доброй ночи".
*/

-- создание таблиц
-- не требуется

-- наполнение нужными данными
-- не требуется

-- скрипт самого задания
delimiter //
drop function if exists hello//
create function hello ()
returns varchar(255)
deterministic
begin
	declare hour tinyint unsigned default hour(now());
    declare greeting varchar(255);
    
    if (hour <= 5) then set greeting = 'Доброй ночи';
    elseif (hour >= 6 and hour <= 11) then set greeting = 'Доброе утро';
    elseif (hour >= 12 and hour <= 17) then set greeting = 'Добрый день';
    elseif (hour >= 18) then set greeting = 'Добрый вечер';
    end if;
    
    return greeting;
end//

delimiter ;
select hello();

/* Практическое задание по теме “Хранимые процедуры и функции, триггеры” №2
Описание задания: В таблице products есть два текстовых поля: name с названием товара и description с его описанием. Допустимо присутствие обоих полей или одно из них. Ситуация, когда оба поля принимают неопределенное значение NULL неприемлема. Используя триггеры, добейтесь того, чтобы одно из этих полей или оба поля были заполнены. При попытке присвоить полям NULL-значение необходимо отменить операцию.
*/

-- создание таблиц
drop table if exists products;
create table products (
	id serial primary key,
    name varchar(255),
    description varchar(1023)
);

-- наполнение нужными данными
-- не требуется

-- скрипт самого задания
delimiter //
create trigger not_null
	before insert
    on products for each row
begin
	if new.name is null and new.description is null
    then signal sqlstate '45000' set message_text = 'Both name and desc can\'t be null';
    end if;
end//

delimiter ;
insert into products (name, description)
values ('prod1', 'desc1');
insert into products (name, description)
values ('prod2', null);
insert into products (name, description)
values (null, 'desc3');
insert into products (name, description)
values (null, null); -- throws an error as expected