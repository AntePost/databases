/* Практическое задание по теме “Операторы, фильтрация, сортировка и ограничение. Агрегация данных” №1
Описание задания: Пусть задан некоторый пользователь. Из всех друзей этого пользователя найдите человека, который больше всех общался с нашим пользователем.
*/

-- создание таблиц
-- работаем с БД vk из урока

-- наполнение нужными данными
insert into users (id, firstname, lastname, email, phone)
values
	(1, 'John', 'Smith', 'example@site.com', 9011234567),
    (2, 'Jack', 'Black', 'example2@site.com', 9021234567),
    (3, 'Ann', 'White', 'example3@site.com', 9031234567);

insert into friend_requests (initiator_user_id, target_user_id, status)
values
	(1, 2, 'approved'),
    (3, 1, 'approved');

insert into messages (id, from_user_id, to_user_id, body)
values
	(1, 1, 2, 'Hello, I\'m John'),
    (2, 2, 1, 'Hi, I\'m Jack'),
    (3, 1, 2, 'How are you?'),
    (4, 2, 1, 'I\'m fine'),
    (5, 3, 1, 'Hello, I\'m Ann'),
    (6, 1, 3, 'Hi, I\'m John');

-- скрипт самого задания
-- скрипт должен возвращать пользователя с id 2, так как он отправил 2 сообщения пользователю с id 1 и является его другом
select * from users
where id in
	(select initiator_user_id from friend_requests where target_user_id = 1 and status = 'approved'
    union
    select target_user_id from friend_requests where initiator_user_id = 1 and status = 'approved')
and id =
	(select max(from_user_id) from messages group by from_user_id having from_user_id != 1 limit 1);

/* Практическое задание по теме “Операторы, фильтрация, сортировка и ограничение. Агрегация данных” №2
Описание задания: Подсчитать общее количество лайков, которые получили пользователи младше 10 лет.
*/

-- создание таблиц
-- работаем с БД vk из урока

-- наполнение нужными данными
insert into profiles (user_id, gender, birthday, hometown)
values
	(1, 'm', str_to_date('17/12/1990', '%d/%m/%Y'), 'moscow'),
    (2, 'm', str_to_date('17/12/1995', '%d/%m/%Y'), 'kazan'),
    (3, 'f', str_to_date('17/12/2017', '%d/%m/%Y'), 'omsk');

insert into media_types (id, name)
values
	(1, 'post'),
    (2, 'photo'),
    (3, 'video'),
    (4, 'audio');

insert into media (id, media_type_id, user_id, body, filename, size, metadata)
values
	(1, 1, 1, 'my first post', null, null, null),
    (2, 2, 2, 'my first photo', 'photo.jpg', 100, null),
    (3, 3, 3, 'my first video', 'video.mkv', 10000, null);

insert into likes (id, user_id, media_id)
values
	(1, 1, 2),
    (2, 1, 3),
    (3, 2, 1),
    (4, 2, 3),
    (5, 3, 1),
    (6, 3, 2),
    (7, 3, 3);

-- скрипт самого задания
-- скрипт возвращает 3 - число лайков, к постам пользователя с id 3, которому меньше 10 лет
select count(*) as n_of_likes_below_10 from likes
where media_id in
	(select id from media
	where user_id in (
		select user_id from profiles
		where timestampdiff(year, birthday, now()) < 10));

/* Практическое задание по теме “Операторы, фильтрация, сортировка и ограничение. Агрегация данных” №3
Описание задания: Определить кто больше поставил лайков (всего) - мужчины или женщины?
*/

-- создание таблиц
-- работаем с БД vk из урока

-- наполнение нужными данными
-- данные вставлены выше

-- скрипт самого задания
select p.gender, count(p.gender) as count from likes as l
join profiles as p
on l.user_id = p.user_id
group by p.gender;