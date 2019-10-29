/* Практическое задание по теме “Сложные запросы” №1
Описание задания: Составьте список пользователей users, которые осуществили хотя бы один заказ orders в интернет магазине.
*/

drop database if exists lesson_07;
create database lesson_07;
use lesson_07;

-- создание таблиц
create table users (
	id serial primary key,
    name varchar(50)
);

create table orders (
	id serial primary key,
    user_id bigint unsigned not null,
    created_at datetime default now(),
    foreign key (user_id) references users(id)
);

-- наполнение нужными данными
insert into users (name)
values
	('john'),
    ('jack'),
    ('jim');

insert into orders (user_id)
values
	(3),
    (3),
    (2);

-- скрипт самого задания
-- скрипт должен вывести пользователей jack и jim, так как только у них есть заказы
select * from users
where (select count(*) from orders where user_id = users.id) > 0;

/* Практическое задание по теме “Сложные запросы” №2
Описание задания: Выведите список товаров products и разделов catalogs, который соответствует товару.
*/

-- создание таблиц
create table categories (
	id serial primary key,
    name varchar(100)
);

create table products (
	id serial primary key,
    name varchar(100),
    price bigint,
    category_id bigint unsigned not null,
    foreign key (category_id) references categories(id)
);

-- наполнение нужными данными
insert into categories (name)
values
	('Beverages'),
    ('Snacks');

insert into products (name, price, category_id)
values
	('Fanta', 100, 1),
    ('Sprite', 120, 1),
    ('Sandwich', 50, 2);

-- скрипт самого задания
select p.name, p.price, c.name as category_name from products as p join categories as c on p.category_id = c.id;

/* Практическое задание по теме “Сложные запросы” №3
Описание задания: (по желанию) Пусть имеется таблица рейсов flights (id, from, to) и таблица городов cities (label, name). Поля from, to и label содержат английские названия городов, поле name — русское. Выведите список рейсов flights с русскими названиями городов.
*/

-- создание таблиц
create table cities (
	label varchar(100),
    name varchar(100),
    index cities_label_idx(label)
);

create table flights (
	id serial primary key,
    `from` varchar(100),
    `to` varchar(100),
    foreign key (`from`) references cities(label),
    foreign key (`to`) references cities(label)
);

-- наполнение нужными данными
insert into cities (label, name)
values
	('moscow', 'Москва'),
    ('irkutsk', 'Иркустк'),
    ('novgorod', 'Новгород'),
    ('kazan', 'Казань'),
    ('omsk', 'Омск');

insert into flights (id, `from`, `to`)
values
	(1, 'moscow', 'omsk'),
    (2, 'novgorod', 'kazan'),
    (3, 'irkutsk', 'moscow'),
    (4, 'omsk', 'irkutsk'),
    (5, 'moscow', 'kazan');

-- скрипт самого задания
select id, (select name from cities where label = `from`) as `from`, (select name from cities where label = `to`) as `to` from flights;