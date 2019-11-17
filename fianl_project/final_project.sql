-- Курсовой проект по курсу "Базы данных"

/*
Настоящий проект представляет собой архитектуру базы данных для видеохостингового сайта наподобие YouTube.
В БД хранятся данные о пользователях ресурса (в двух таблицах с основной и дополнительной информацией), каналах, созданных пользователями (в отличие от YouTube сущности пользователь и канал разделены).
Также хранятся данные собственно о видеороликах, лайках, дизлайках (лайки и дизлайки хранятся в рамках одной таблицы и отличаются битовым значением).
Также хранятся данные о комментариях к видео и лайках и дизлайках к комментариям.
Также хранятся данные о подписках пользователей на каналы (подписки являются однонаправленными).

В файле есть функция создания полного имени пользователя в зависимости от предоставленных им данных.
Также есть процедура добавления новой записи в таблицу лайков с обновление счетчика лайков видео.

БД заполнена mock-данными.

В конце файла приводятся представления и характерные выборки.
*/

-- Создание базы данных и таблиц (DDL)
DROP DATABASE IF EXISTS youtubeplus;
CREATE DATABASE youtubeplus;
USE youtubeplus;

-- Таблица пользователей
DROP TABLE IF EXISTS users;
CREATE TABLE users (
	id SERIAL PRIMARY KEY,
    firstname VARCHAR(200),
    lastname VARCHAR(200),
    username VARCHAR(200) NOT NULL COMMENT 'User nickname',
    email VARCHAR(200) NOT NULL UNIQUE,
    password_hash VARCHAR(200) NOT NULL,
    created_at DATETIME DEFAULT NOW(),
    updated_at DATETIME DEFAULT NULL ON UPDATE NOW(),
    is_deleted BOOL DEFAULT FALSE,
    INDEX users_email_idx(email)
);

-- Таблица дополнительных данных пользователей
DROP TABLE IF EXISTS user_data;
CREATE TABLE user_data (
	user_id SERIAL PRIMARY KEY,
    gender CHAR(1),
    birthday DATE,
    country VARCHAR(200),
    hometown VARCHAR(200),
    bio VARCHAR(1000),
    created_at DATETIME DEFAULT NOW(),
    updated_at DATETIME DEFAULT NULL ON UPDATE NOW(),
    FOREIGN KEY (user_id) REFERENCES users(id)
		ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- Таблица каналов
DROP TABLE IF EXISTS channels;
CREATE TABLE channels (
	id SERIAL PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    channel_name VARCHAR(200) NOT NULL UNIQUE,
    descpription VARCHAR(1000),
    primary_language VARCHAR(50),
    created_at DATETIME DEFAULT NOW(),
    updated_at DATETIME DEFAULT NULL ON UPDATE NOW(),
    is_deleted BOOL DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES users(id)
		ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- Таблица видео
DROP TABLE IF EXISTS videos;
CREATE TABLE videos (
	id SERIAL PRIMARY KEY,
    channel_id BIGINT UNSIGNED NOT NULL,
    video_name VARCHAR(200) NOT NULL,
    descpription VARCHAR(1000),
    uniq_id VARCHAR(20) NOT NULL COMMENT 'unique id of a video to be used to reference videofile and in URL',
    viewcount BIGINT UNSIGNED NOT NULL,
    video_length MEDIUMINT UNSIGNED NOT NULL,
    likes_count BIGINT DEFAULT 0 COMMENT 'aggregated column, calculated by procedure with each added like',
    metadata JSON,
    created_at DATETIME DEFAULT NOW(),
    updated_at DATETIME DEFAULT NULL ON UPDATE NOW(),
    is_deleted BOOL DEFAULT FALSE,
	FOREIGN KEY (channel_id) REFERENCES channels(id)
		ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- Таблица лайков к видео
DROP TABLE IF EXISTS video_likes;
CREATE TABLE video_likes (
    user_id BIGINT UNSIGNED NOT NULL,
    video_id BIGINT UNSIGNED NOT NULL,
    is_dislike BOOL DEFAULT FALSE,
    PRIMARY KEY (user_id, video_id),
    FOREIGN KEY (user_id) REFERENCES users(id)
		ON UPDATE CASCADE
        ON DELETE CASCADE,
	FOREIGN KEY (video_id) REFERENCES videos(id)
		ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- Таблица комментариев к видео
DROP TABLE IF EXISTS video_comments;
CREATE TABLE video_comments (
	id SERIAL PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    video_id BIGINT UNSIGNED NOT NULL,
    comment_text VARCHAR(1000),
    parent_comment BIGINT UNSIGNED COMMENT 'Link to parent comment. If NULL, then it\'s a top comment',
    created_at DATETIME DEFAULT NOW(),
    updated_at DATETIME DEFAULT NULL ON UPDATE NOW(),
    is_deleted BOOL DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES users(id)
		ON UPDATE CASCADE
        ON DELETE CASCADE,
	FOREIGN KEY (video_id) REFERENCES videos(id)
		ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- Таблица подписок на каналы
DROP TABLE IF EXISTS channel_subscriptions;
CREATE TABLE channel_subscriptions (
	user_id BIGINT UNSIGNED NOT NULL,
    channel_id BIGINT UNSIGNED NOT NULL,
    created_at DATETIME DEFAULT NOW(),
    is_unsubbed BOOL DEFAULT FALSE COMMENT 'Set to TRUE if user unsubscribed from channel',
    unsubbed_at DATETIME DEFAULT NULL,
    PRIMARY KEY (user_id, channel_id),
    FOREIGN KEY (user_id) REFERENCES users(id)
		ON UPDATE CASCADE
        ON DELETE CASCADE,
	FOREIGN KEY (channel_id) REFERENCES channels(id)
		ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- Таблица лайков и дизлайков к комменариям
DROP TABLE IF EXISTS comment_likes;
CREATE TABLE comment_likes (
    user_id BIGINT UNSIGNED NOT NULL,
    comment_id BIGINT UNSIGNED NOT NULL,
    is_dislike BOOL DEFAULT FALSE,
    PRIMARY KEY (user_id, comment_id),
    FOREIGN KEY (user_id) REFERENCES users(id)
		ON UPDATE CASCADE
        ON DELETE CASCADE,
	FOREIGN KEY (comment_id) REFERENCES video_comments(id)
		ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- Таблица категорий видео
DROP TABLE IF EXISTS video_categories;
CREATE TABLE video_categories (
	id SERIAL PRIMARY KEY,
    category_name VARCHAR(200),
    created_at DATETIME DEFAULT NOW(),
    updated_at DATETIME DEFAULT NULL ON UPDATE NOW(),
    is_deleted BOOL DEFAULT FALSE
);

-- Таблица связей между видео и категориями (many-to-many)
DROP TABLE IF EXISTS video_categories_relations;
CREATE TABLE video_categories_relations (
	video_id BIGINT UNSIGNED NOT NULL,
    category_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (video_id, category_id),
    FOREIGN KEY (video_id) REFERENCES videos(id)
		ON UPDATE CASCADE
        ON DELETE CASCADE,
	FOREIGN KEY (category_id) REFERENCES video_categories(id)
		ON UPDATE CASCADE
        ON DELETE CASCADE
);

-- Процедуры
-- Процедура для вставки данных о лайках к видео и обновлению данных о лайках у самих видео
DROP PROCEDURE IF EXISTS sp_add_like;
DELIMITER //
CREATE PROCEDURE sp_add_like (user_id BIGINT UNSIGNED, video_id BIGINT UNSIGNED, is_dislike BOOL, OUT tran_result VARCHAR(200))
BEGIN
	DECLARE _rollback BOOL DEFAULT 0;
    DECLARE error_code VARCHAR(100);
   	DECLARE error_string VARCHAR(100);
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
		SET _rollback = 1;
        GET stacked DIAGNOSTICS CONDITION 1
          error_code = RETURNED_SQLSTATE, error_string = MESSAGE_TEXT;
    	set tran_result := concat('Error occured. Code: ', error_code, '. Text: ', error_string);
    END;
    
    START TRANSACTION;
		INSERT INTO video_likes (user_id, video_id, is_dislike)
        VALUES (user_id, video_id, is_dislike);
        
        UPDATE videos
        SET likes_count = likes_count + 1
        WHERE id = user_id;
        
        IF _rollback THEN
			ROLLBACK;
		ELSE
			SET tran_result := 'ok';
            COMMIT;
		END IF;
END//
DELIMITER ;

-- Проверка процедуры sp_add_like
-- Проверка происходит ниже, в момент добавления данных

-- Наполнение данными
INSERT INTO users VALUES
	('1','Rossie','Mohr','lea.schoen','ernestine63@example.net','404b2e05d3111744d82e34a8a807ee6c28247c4b','1999-02-28 16:45:42','2002-09-02 22:21:38','0'),
	('2',NULL,'Dickinson','brown.gerhard','gbruen@example.net','0e4ca9f5dccca4f59051f3831e875a9a5e6d4c58','2007-03-23 22:16:16','1975-05-24 14:53:31','1'),
	('3','Raquel',NULL,'madyson.kuhn','shammes@example.com','c4acba074e8a39dd495d4e172140820e16b05582','1980-09-09 01:49:13','2007-11-02 21:13:12','1'),
	('4',NULL,'Murray','ana37','willard.mayer@example.com','d87a2173ce3c70d1ebd0b9d0e9b2922e21e28464','1980-12-21 03:30:00','1989-07-21 03:52:59','1'),
	('5','Audie','Kiehn','ottilie.padberg','jovani37@example.com','a863e55971d4f25ff9b045529a8b0de7de12f435','1976-12-01 00:24:26','1975-05-22 09:48:06','1'),
	('6','Elinor','Gulgowski','kylie33','isidro57@example.com','780ee7a56fc74b4fd28f895b06f66d76b14333f7','1985-12-18 17:13:07','1983-04-18 23:23:58','0'),
	('7','Judson','Satterfield','granville.glover','juvenal.towne@example.com','1d94ea4e2777421dd5d5c9188ab2185a32393f99','2010-05-26 03:29:38','1972-11-26 18:30:21','1'),
	('8','Danika','Maggio','lenora20','cbraun@example.net','7662e24b00958f1584561d4ece47be0e9f24fe3f','2013-05-22 08:22:33','2006-05-09 15:32:22','0'),
	('9','Jamil','Rippin','gideon70','willa.hilll@example.com','667381e33947bd30345226e1b0fcf81dc7abd103','2019-07-05 16:05:45','1988-03-09 12:51:08','1'),
	('10','Berneice','Steuber','mschmeler','hessel.earl@example.org','bd84fd93d6eeef78ec4cbccaee7a09cf1077acb9','1976-01-21 14:57:22','1996-07-11 07:17:06','1'); 

INSERT INTO user_data VALUES
	('1','m','2003-07-18','Rwanda','East Eugeniaport','Velit ut vitae similique quod est consequatur ad. Modi eius et sit amet aut. Iste laboriosam et dolore autem ipsum.','1982-10-21 02:08:28','1991-02-23 02:21:48'),
	('2','m','2014-08-19','United Kingdom','Shirleybury','Occaecati ipsa excepturi reiciendis magnam ut quos quis. Vero voluptates ipsa fugiat est nihil repudiandae. Ut suscipit quo eveniet et aut.','1971-01-06 02:28:46','1988-12-14 13:54:08'),
	('3','f','1990-04-03','Puerto Rico','West Jerelside','Voluptatum est minima veniam et placeat maxime. Reiciendis voluptatem voluptatem ea rerum ex officiis. Repudiandae repudiandae velit porro ducimus qui. Ut dolores excepturi fugiat sit non est nemo.','1990-06-19 23:35:21','2002-06-11 21:46:18'),
	('4','m','2018-01-06','Montenegro','East Vivianeland','Voluptate eius molestias dolorem ipsam quia eius reiciendis voluptatem. Tempore ratione expedita quibusdam tenetur voluptatem voluptatum quo. Aut excepturi qui eligendi non voluptatem aut.','2005-04-23 13:19:17','2011-08-08 14:02:59'),
	('5','m','2004-03-01','Central African Republic','North Justine','In tempora earum commodi eos ut doloribus error. Qui non libero ipsum officia. Quas itaque quisquam omnis atque. Sapiente reiciendis omnis dolorem non doloribus voluptates voluptatibus consequatur.','2013-07-09 05:44:49','1998-10-24 13:27:58'),
	('6','f','1976-11-24','Benin','Donnellyshire','Rerum explicabo occaecati rerum sed. Tenetur amet perspiciatis magni minus aperiam quidem nisi. Numquam aspernatur numquam voluptatem iste aut.','1979-11-07 21:30:50','1988-12-28 20:29:19'),
	('7','f','1997-11-07','Chile','Langworthview','Ad voluptas qui necessitatibus et. Enim id ipsam voluptatibus sint a. Laborum id illum quia eius.','1998-05-03 11:08:00','1970-07-26 18:50:00'),
	('8','f','1975-06-07','Saint Pierre and Miquelon','Port Creola','Et animi quisquam beatae aliquam vitae. Beatae exercitationem vel nulla non. Rerum enim distinctio neque.','1975-05-22 21:25:14','2018-05-26 14:37:13'),
	('9','f','2012-03-22','Malawi','Orionfort','Nihil voluptatem earum illo nisi. Magnam voluptas omnis suscipit quas ut labore. Et quae sit quaerat cumque est.','2015-04-16 03:56:18','1995-07-11 09:09:00'),
	('10','f','2003-07-07','Iceland','Erickaport','Fugit rerum alias eum aliquam inventore consequatur. Quasi harum sunt debitis non ut. Adipisci animi voluptatem ea enim vel. In ut iusto fugiat facilis et sequi.','1986-12-12 13:36:29','1990-03-01 11:25:48'); 

INSERT INTO channels VALUES
	('1','1','in','Est sed fugiat rerum ut ipsum consequuntur. Dolorem eos quae numquam tenetur quos ex. Deleniti laboriosam aut voluptas et est omnis.','ru','2015-05-12 20:53:31','2006-11-11 22:09:55','1'),
	('2','2','aut','Nulla deserunt vero officia provident et. Et quibusdam sunt sapiente et. Asperiores quas voluptas et et.','cn','1990-02-25 17:33:22','2001-01-10 01:32:30','0'),
	('3','3','voluptas','Omnis consectetur est id vero quae similique natus. Quam atque rerum recusandae consequuntur asperiores. Voluptate culpa ducimus porro. Est fugiat rem nobis repudiandae sunt. Nihil aliquid et perferendis reprehenderit.','es','2003-10-16 05:16:43','1990-04-10 13:25:28','0'),
	('4','4','porro','Tempore dolorem et aut itaque sit officia. Necessitatibus eum et et neque vel necessitatibus. Ut harum fugit itaque sit vel. Quos provident architecto sit qui.','cn','1991-01-12 02:42:31','2010-05-12 21:40:35','1'),
	('5','5','quidem','Rem culpa dignissimos at totam explicabo tempore ut. Quia non est et ad occaecati ad ut ut. Non accusamus sint veniam rem aliquam ut id.','pt','1970-07-14 18:02:34','2017-04-29 02:28:29','1'),
	('6','6','consectetur','Earum quia quia cumque quos iusto exercitationem. Similique dolor non et et voluptas nihil nisi. Explicabo officia corporis nobis nam saepe est id.','fr','1985-04-04 14:53:08','2009-10-06 06:15:10','1'),
	('7','7','nostrum','Quia voluptas voluptatum vel fuga ut non aut. Earum dicta inventore voluptatem sit error. Ipsum sed ipsa sit eos aliquid. Et possimus nisi autem dolore.','cn','2010-11-08 09:45:57','2011-01-29 03:07:15','1'),
	('8','8','optio','Adipisci neque rerum debitis maiores. Amet occaecati velit voluptatem. Animi nesciunt et eum vitae.','de','2000-10-22 01:48:35','2016-03-30 13:18:05','0'),
	('9','9','libero','Suscipit iure velit et sit. Quod nemo enim est eos. Quos alias nihil illum.','es','2017-09-15 12:42:23','1975-09-10 22:36:18','1'),
	('10','10','voluptates','Repudiandae distinctio quis recusandae ut unde voluptatem commodi quis. Placeat accusamus voluptatem architecto aut omnis. Qui rerum incidunt amet est ipsum tempore mollitia. Eos dolorem ut velit veritatis animi.','de','1984-07-29 14:18:00','1970-04-22 16:37:18','1'); 

INSERT INTO videos VALUES
	('1','1','vel','Nulla alias fugiat aperiam aut dolorum odio.','1dddacb635a365b6e177','1','1015588','0',NULL,'2009-11-07 08:11:16','1998-08-26 11:02:21','1'),
	('2','2','aperiam','Et voluptates earum earum placeat similique ut occaecati aut.','2a2dec44893a8271a9ec','0','0','0',NULL,'1980-08-31 07:30:10','1978-05-29 12:37:30','1'),
	('3','3','perspiciatis','Provident voluptate quisquam deleniti nihil error.','58a000a8c681d3197693','62467','49','0',NULL,'1988-05-14 05:06:48','1983-04-22 17:23:23','1'),
	('4','4','occaecati','Voluptas sit optio quo asperiores.','df752514b601d9eeb135','579863539','8','0',NULL,'2010-04-24 01:47:29','1990-11-24 01:33:40','0'),
	('5','5','sit','Recusandae molestiae excepturi eos id minima.','cd668feaaebc66149b82','756185','1087224','0',NULL,'2019-07-31 11:52:02','1987-07-31 05:32:55','1'),
	('6','6','quod','Rerum harum tempore voluptas.','30dad9b9f827d10bef9c','65','2','0',NULL,'1971-11-04 11:29:32','1971-03-23 14:53:00','1'),
	('7','7','vero','Quis quibusdam aliquid quis veritatis ad facere a.','f73070e34aa93b9a9701','215064','7963255','0',NULL,'1999-05-25 18:46:28','1985-08-11 09:28:51','0'),
	('8','8','et','Et incidunt quis dignissimos iusto.','a969b8394c47bc0cd5d5','7005','1','0',NULL,'1998-06-29 05:17:20','2013-02-06 08:48:17','1'),
	('9','9','magnam','Iure voluptas deleniti ab deleniti.','48ec471dc7922c3f9e7d','952372757','16777215','0',NULL,'1977-02-22 10:33:10','1995-11-25 06:23:14','1'),
	('10','10','est','Aut repellat in alias.','56284f78fbeb362811de','92348751','647095','0',NULL,'1978-07-01 02:48:20','1994-10-20 14:26:28','0'),
	('11','1','quo','Nam sit atque incidunt est.','be7f67d1bde2a49ab516','8','58597','0',NULL,'1983-04-06 23:08:03','1978-10-15 22:49:45','0'),
	('12','2','omnis','Inventore hic omnis voluptatem.','e1e643ac4c3ef34f10e7','2437','16777215','0',NULL,'1992-11-12 02:12:43','1972-03-29 13:12:50','0'),
	('13','3','dolorem','Explicabo saepe est et et dolorem dolore.','05ce33e3b6f6d539b00a','7237','47068','0',NULL,'2015-09-18 13:58:58','2002-10-18 06:12:38','0'),
	('14','4','velit','Porro laboriosam architecto sed possimus.','651f5fba3e804fc7e9ee','69712','8','0',NULL,'2016-06-23 19:57:45','1995-06-29 17:20:35','1'),
	('15','5','aut','Qui cum ea omnis laboriosam.','9329d508da7b91248bdf','289314629','111','0',NULL,'1978-09-02 17:10:52','1975-12-09 06:56:43','0'),
	('16','6','molestias','Distinctio illum possimus non qui.','a12c81abb7c8853f7e91','21606161','6733','0',NULL,'2003-11-16 03:34:51','1979-11-04 00:09:34','0'),
	('17','7','ut','Doloribus harum ullam ipsam excepturi consequatur.','4d989829db948dd89d6a','63094','28466','0',NULL,'1988-08-17 04:10:43','1992-10-03 18:36:29','1'),
	('18','8','aut','Alias accusamus natus porro enim facere.','39e4ad301d8c4c1c5d7b','7835','7195','0',NULL,'2018-03-19 22:47:35','1980-11-11 16:55:37','0'),
	('19','9','pariatur','Ut maxime omnis in assumenda.','b1d34edeaa056dc93ca4','6941','2','0',NULL,'1975-03-06 00:40:45','1978-03-16 03:12:23','1'),
	('20','10','veniam','Est tempore hic quis recusandae.','aceaa132476f6ec36635','636','16777215','0',NULL,'2012-11-20 05:35:14','1995-03-01 17:15:20','1'),
	('21','1','atque','Assumenda cum quia minima incidunt soluta eius velit quo.','be31716c925e87b7ccc5','0','811','0',NULL,'1984-01-03 14:34:02','2013-08-28 01:26:04','0'),
	('22','2','suscipit','Dolores quibusdam vitae sit qui.','d697eddb1cd909b753eb','0','0','0',NULL,'2011-11-05 23:34:22','2003-08-27 13:06:21','1'),
	('23','3','aspernatur','Consequatur repellendus ut soluta non atque.','e817ad70cbee34e091f3','6','16777215','0',NULL,'1996-03-25 20:27:09','1971-01-03 17:32:16','0'),
	('24','4','odit','Nisi voluptas molestiae inventore qui voluptatem impedit.','52bfd4d88d6c6a0c170f','4302813','72','0',NULL,'2002-07-09 08:31:12','1987-12-14 07:53:29','0'),
	('25','5','accusantium','Aspernatur incidunt nihil possimus doloribus.','16a5e09f38025f24491b','0','0','0',NULL,'2006-04-11 22:41:53','1970-03-15 05:28:41','1'),
	('26','6','quasi','Harum sunt voluptatem dolor voluptatem impedit quas.','57304568c55c56e14f31','10822466','0','0',NULL,'1990-05-02 19:35:06','1976-05-03 23:05:51','1'),
	('27','7','commodi','Voluptates aut eligendi alias debitis in quas eos quo.','845091d3a2c4be0c02d2','98640','3630','0',NULL,'1978-07-07 16:31:53','1998-07-22 22:50:25','0'),
	('28','8','consequatur','Fugit dolorem sint quae et eos.','d7b29f2f016f5182195e','460586438','1508740','0',NULL,'2005-11-22 02:00:02','2013-06-02 08:42:12','1'),
	('29','9','sed','Ducimus est est culpa nisi.','8ca1e8f00a95c639cf52','74235','5','0',NULL,'1998-05-19 05:23:36','2019-06-24 03:24:50','0'),
	('30','10','nisi','Omnis illo quisquam nulla et.','ff22224791fabc5a9fa8','4843','267','0',NULL,'1985-11-16 07:03:05','1992-02-29 22:43:08','1'),
	('31','1','maiores','Et dolore est suscipit dolorem eligendi.','643bd2e777f8c1ffd1bd','1088374','44339','0',NULL,'1980-05-23 10:45:05','1997-08-28 10:51:52','0'),
	('32','2','ut','Iure hic laudantium aut aut quas incidunt.','3c9ebe2f9ca1dad70088','3163','1184215','0',NULL,'1993-06-15 07:20:36','1999-11-21 11:13:59','0'),
	('33','3','vel','Dignissimos odio veritatis laudantium necessitatibus.','8d9bc593397167df8494','44364','972771','0',NULL,'2019-06-14 07:06:39','2013-02-11 05:08:16','1'),
	('34','4','vitae','Dolore labore ab in iste numquam et.','6b382bd15b0412d4ed2b','1649174','16777215','0',NULL,'1996-06-05 09:06:56','2001-06-02 03:45:37','1'),
	('35','5','adipisci','Quod magnam ipsa non dolorem est sequi ea ut.','18a478b05e3f3966fbcf','46906148','0','0',NULL,'1990-07-17 17:19:20','2015-01-25 20:37:42','0'),
	('36','6','vitae','Ipsam quia voluptatum debitis sequi commodi accusamus ipsum et.','6b46ff509c5130905b6a','4','5275','0',NULL,'1996-01-16 07:51:56','2014-10-10 03:36:29','1'),
	('37','7','eveniet','Nam architecto error repellendus veritatis.','f5306179908082f861cf','58939083','1','0',NULL,'2009-11-22 09:52:22','2006-04-17 08:36:45','1'),
	('38','8','porro','Et ut nemo veniam possimus doloribus.','22f8286bb5f97abd2179','85104066','4','0',NULL,'2001-07-11 20:00:11','1988-10-31 10:59:46','0'),
	('39','9','dignissimos','Dolorum officiis aut dicta perspiciatis rerum eum.','6f7f20253703b4a4495a','9','62','0',NULL,'1990-11-26 21:40:26','1994-01-17 12:21:33','0'),
	('40','10','ullam','Consequuntur nisi non ea consequuntur aspernatur atque excepturi.','6644efcd0bd3120ba033','3636','50','0',NULL,'1995-12-13 20:39:38','2004-04-29 21:44:47','0'),
	('41','1','nihil','Consequatur quas quae cumque impedit.','bec6312129cecd6dec5c','16','16777215','0',NULL,'2005-01-05 08:01:07','1980-09-16 12:40:33','0'),
	('42','2','quia','Sapiente beatae ullam maxime voluptas aut animi.','f402b64db3e0cc5f0381','7','25542','0',NULL,'1981-10-24 00:17:32','1973-02-14 07:41:16','0'),
	('43','3','distinctio','Incidunt dolorum similique architecto omnis odit non.','65b820e44cd64a0129e3','6','9880','0',NULL,'1978-10-10 09:13:45','1979-01-24 11:32:33','0'),
	('44','4','nihil','Ut quos officia tenetur velit pariatur esse sed.','0506ceb94aa6cd0d9d19','64407','4152','0',NULL,'1977-06-11 20:12:07','2003-03-11 21:20:23','0'),
	('45','5','rem','Quia iure voluptas inventore dolor rerum.','d9ac2a567c3e4ce13132','57','9721298','0',NULL,'1972-07-10 09:50:22','1992-07-24 05:41:16','1'),
	('46','6','repellendus','Tenetur ipsam neque vero est dicta beatae consequuntur.','0f7a4fec6b513389a7bd','566','16777215','0',NULL,'1995-06-24 07:37:41','2019-09-11 19:54:38','1'),
	('47','7','nostrum','Voluptas possimus voluptates voluptas aut et sed a.','682a9093650b70275fc8','0','0','0',NULL,'2018-01-10 04:30:30','1980-05-18 08:27:43','0'),
	('48','8','est','Aut et dolores et sit.','998c93c7c1c84945c939','846115381','771287','0',NULL,'2012-09-10 23:12:23','1970-05-02 22:57:36','1'),
	('49','9','et','Sit omnis saepe dolores suscipit repellendus.','ad17ae6608caa63e2b0d','21','16777215','0',NULL,'1979-01-23 09:45:57','2012-04-16 03:58:37','0'),
	('50','10','dolorum','Assumenda voluptatem impedit dignissimos mollitia rerum.','25b6a2b36c665fb0ad70','3','76544','0',NULL,'1998-07-04 19:24:06','1976-01-06 08:12:24','1'); 

-- Проверка процедуры sp_add_like
CALL sp_add_like('1', '1', '0', @tran_result);
SELECT @tran_result;
CALL sp_add_like('1','11','0', @tran_result);
CALL sp_add_like('1','21','1', @tran_result);
CALL sp_add_like('1','31','1', @tran_result);
CALL sp_add_like('1','41','0', @tran_result);
CALL sp_add_like('2','2','1', @tran_result);
CALL sp_add_like('2','12','0', @tran_result);
CALL sp_add_like('2','22','0', @tran_result);
CALL sp_add_like('2','32','1', @tran_result);
CALL sp_add_like('2','42','1', @tran_result);
CALL sp_add_like('3','3','0', @tran_result);
CALL sp_add_like('3','13','1', @tran_result);
CALL sp_add_like('3','23','1', @tran_result);
CALL sp_add_like('3','33','1', @tran_result);
CALL sp_add_like('3','43','1', @tran_result);
CALL sp_add_like('4','4','0', @tran_result);
CALL sp_add_like('4','14','1', @tran_result);
CALL sp_add_like('4','24','1', @tran_result);
CALL sp_add_like('4','34','0', @tran_result);
CALL sp_add_like('4','44','0', @tran_result);
CALL sp_add_like('5','5','1', @tran_result);
CALL sp_add_like('5','15','1', @tran_result);
CALL sp_add_like('5','25','0', @tran_result);
CALL sp_add_like('5','35','0', @tran_result);
CALL sp_add_like('5','45','0', @tran_result);
CALL sp_add_like('6','6','1', @tran_result);
CALL sp_add_like('6','16','1', @tran_result);
CALL sp_add_like('6','26','0', @tran_result);
CALL sp_add_like('6','36','1', @tran_result);
CALL sp_add_like('6','46','0', @tran_result);
CALL sp_add_like('7','7','0', @tran_result);
CALL sp_add_like('7','17','0', @tran_result);
CALL sp_add_like('7','27','0', @tran_result);
CALL sp_add_like('7','37','0', @tran_result);
CALL sp_add_like('7','47','0', @tran_result);
CALL sp_add_like('8','8','1', @tran_result);
CALL sp_add_like('8','18','0', @tran_result);
CALL sp_add_like('8','28','0', @tran_result);
CALL sp_add_like('8','38','0', @tran_result);
CALL sp_add_like('8','48','0', @tran_result);
CALL sp_add_like('9','9','1', @tran_result);
CALL sp_add_like('9','19','1', @tran_result);
CALL sp_add_like('9','29','0', @tran_result);
CALL sp_add_like('9','39','0', @tran_result);
CALL sp_add_like('9','49','1', @tran_result);
CALL sp_add_like('10','10','0', @tran_result);
CALL sp_add_like('10','20','1', @tran_result);
CALL sp_add_like('10','30','0', @tran_result);
CALL sp_add_like('10','40','0', @tran_result);
CALL sp_add_like('10','50','0', @tran_result); 

INSERT INTO video_comments VALUES
	('1','1','1','Et sit enim possimus ut.','6','2000-03-09 15:50:48','1985-05-26 21:08:02','0'),
	('2','2','2','Quas aut aut qui tempora.','9','2000-02-16 09:08:49','2017-09-11 02:34:48','1'),
	('3','3','3','Facere expedita fuga rerum voluptatem velit dolorum esse.','0','1991-02-17 04:49:00','1970-12-04 05:17:24','0'),
	('4','4','4','Beatae amet et pariatur in fuga.','2','2011-08-31 07:00:23','1985-05-15 23:41:58','0'),
	('5','5','5','Tempore sit quisquam quia velit.','9','1985-07-12 09:16:31','1997-10-17 03:17:39','1'),
	('6','6','6','Labore quod nostrum eum aut.','0','1994-11-10 22:20:50','1971-08-03 21:33:31','0'),
	('7','7','7','Voluptatum alias ullam quo reiciendis qui voluptas.','1','2014-02-22 18:26:34','1975-04-21 12:07:34','1'),
	('8','8','8','Et molestiae consequuntur minus.','1','2011-06-10 13:38:16','1980-01-13 06:19:27','1'),
	('9','9','9','Qui sit sit porro voluptatem minima aliquid nemo rerum.','7','2015-01-12 11:33:34','2018-06-13 03:28:24','0'),
	('10','10','10','Fugiat officiis numquam fuga error est ea tenetur.','7','2004-06-15 03:13:41','1985-07-27 14:05:17','0'),
	('11','1','11','Similique asperiores sed minus repellendus.','8','2002-10-05 14:46:02','1991-10-24 02:54:56','1'),
	('12','2','12','Ut voluptas accusamus maiores alias.','4','2018-05-25 10:48:22','1997-09-09 08:50:17','1'),
	('13','3','13','Quos quia quo nisi facere.','1','1992-08-20 22:28:14','2005-02-23 21:41:05','1'),
	('14','4','14','Reiciendis aut quasi hic ducimus sint velit id.','8','1983-09-25 19:23:02','1970-02-14 11:35:29','0'),
	('15','5','15','Architecto praesentium aut quia voluptas et commodi.','1','2016-08-30 10:05:10','1999-04-23 00:06:27','1'),
	('16','6','16','Et omnis deserunt est veniam.','8','2002-06-29 13:33:31','1977-02-12 11:21:45','1'),
	('17','7','17','Voluptates quis ducimus magni architecto.','3','1996-03-03 20:34:41','1997-10-17 08:49:01','0'),
	('18','8','18','Unde deserunt placeat aut.','6','1977-06-14 06:28:40','2012-06-26 02:06:45','1'),
	('19','9','19','Temporibus voluptatem eaque deserunt eum.','6','1985-08-04 04:50:03','1972-12-20 11:15:21','1'),
	('20','10','20','Est et ipsum accusamus quibusdam id officiis perspiciatis.','4','1983-02-18 11:31:02','1996-03-16 03:18:59','1'),
	('21','1','21','Omnis non dolor dicta ad recusandae.','6','1991-08-16 03:55:57','2013-03-28 22:57:29','1'),
	('22','2','22','Amet quis voluptates ad corporis autem harum possimus.','6','1989-10-10 10:04:22','2005-02-17 05:17:18','1'),
	('23','3','23','Rem est ut et exercitationem dolores et qui quis.','4','2014-01-25 20:52:18','1976-07-20 14:43:13','0'),
	('24','4','24','Facilis tempora earum sint labore similique at totam.','1','1985-05-06 13:22:50','2012-02-28 02:00:25','1'),
	('25','5','25','Dolorem aut impedit ea occaecati tenetur nobis.','0','1978-05-25 13:29:21','2016-01-26 19:13:13','1'),
	('26','6','26','Dolores adipisci reiciendis nulla nobis.','0','2017-12-24 12:34:05','2001-12-10 11:06:55','0'),
	('27','7','27','Nostrum aut veritatis et qui illum rerum id.','1','1991-10-31 20:24:04','1980-08-13 19:21:40','1'),
	('28','8','28','Fuga dolore adipisci dolores.','1','1985-08-24 23:03:13','1998-01-19 21:44:54','0'),
	('29','9','29','Porro odit voluptatem dolor animi ea reiciendis a est.','5','1992-12-17 05:33:18','1973-03-24 02:07:54','0'),
	('30','10','30','Et consequatur tenetur consequuntur dolores alias voluptatum.','3','1997-01-18 11:29:35','1993-05-23 08:57:17','1'),
	('31','1','31','Et est error ipsam quaerat amet cum.','4','1978-10-18 03:34:05','2004-01-28 23:09:24','0'),
	('32','2','32','Itaque sunt et enim et.','8','1991-08-11 06:19:27','1998-08-07 02:34:37','1'),
	('33','3','33','Unde voluptatem ratione velit doloribus.','8','1986-04-21 04:50:02','2003-05-20 14:06:45','0'),
	('34','4','34','Quidem et eum fugit doloribus.','7','1993-12-10 16:05:15','1996-12-16 16:27:54','0'),
	('35','5','35','Suscipit labore tempore accusamus culpa deleniti.','4','1988-10-24 18:35:32','1984-08-18 17:35:11','0'),
	('36','6','36','Sunt veniam cupiditate id et.','2','1992-03-19 18:11:08','1992-07-11 18:03:28','0'),
	('37','7','37','Corporis dolor vel sunt molestiae dolores.','4','1984-10-31 22:47:44','1973-02-06 04:00:52','1'),
	('38','8','38','Voluptate neque ullam ea inventore at dolor.','5','2009-10-29 15:27:09','2016-11-30 14:34:58','0'),
	('39','9','39','Nihil aliquam accusantium maxime eveniet molestiae voluptatem.','3','1980-07-05 01:21:53','1982-02-08 00:05:06','1'),
	('40','10','40','Quos aut nisi vitae quasi distinctio possimus.','1','1987-10-21 19:27:50','1985-12-28 06:10:30','0'),
	('41','1','41','Et aliquid consequatur omnis ut qui.','1','1994-05-09 22:24:52','1991-04-06 08:58:23','1'),
	('42','2','42','Id possimus est ducimus quas officia corporis.','3','1998-09-29 06:24:07','1996-04-10 07:35:01','1'),
	('43','3','43','Blanditiis quod aspernatur et fugiat aut.','9','1996-08-29 06:29:21','2000-03-25 04:13:16','0'),
	('44','4','44','Vitae nulla unde voluptas suscipit.','2','1989-02-16 15:47:38','1975-12-18 22:47:15','1'),
	('45','5','45','Harum voluptatem natus hic.','6','1976-03-28 12:02:32','1993-06-02 19:59:43','0'),
	('46','6','46','Molestiae sit molestiae quia nesciunt rerum.','1','1970-09-23 02:11:32','1999-01-15 23:34:14','0'),
	('47','7','47','Dolore est natus ab est cupiditate earum neque.','8','1997-06-05 01:10:16','1981-02-26 13:54:30','0'),
	('48','8','48','Eum fugit architecto exercitationem vero aperiam animi earum aut.','5','2014-01-10 13:05:00','2003-05-09 02:38:49','0'),
	('49','9','49','Quos vel laboriosam assumenda neque facere quam rem quia.','3','2000-12-04 23:12:10','2011-08-18 10:39:25','1'),
	('50','10','50','Culpa quos temporibus nam repellat assumenda et aut eligendi.','6','2015-09-01 10:08:03','1998-10-03 10:55:25','1'); 

INSERT INTO channel_subscriptions VALUES
	('1','1','1993-12-23 13:48:23','0','1995-03-01 03:13:45'),
	('2','2','1995-06-18 15:25:55','1','2008-12-02 06:12:58'),
	('3','3','1987-04-15 17:16:10','0','1991-05-30 17:40:31'),
	('4','4','1992-03-13 07:26:04','1','2010-03-06 10:10:45'),
	('5','5','1999-12-14 04:00:15','0','1983-01-18 14:54:19'),
	('6','6','1984-07-01 12:08:16','0','2004-11-29 05:33:06'),
	('7','7','2006-06-01 03:21:06','0','2000-03-25 12:04:29'),
	('8','8','2013-11-20 00:22:11','1','1994-06-19 10:43:20'),
	('9','9','2000-07-04 21:18:40','0','1977-02-10 06:14:17'),
	('10','10','1998-06-04 02:57:48','1','2007-07-10 14:51:54'),
	('1','2','2005-10-08 04:14:33','0','2018-07-04 01:44:42'),
	('2','3','2006-08-07 18:33:13','1','2012-06-06 09:36:04'),
	('3','4','2011-03-20 10:47:29','0','1998-09-22 10:31:59'),
	('4','5','1991-03-31 04:31:13','1','1979-06-07 22:49:26'),
	('5','6','2000-12-04 13:58:36','1','1975-09-02 15:58:56'),
	('6','7','2003-05-03 09:57:37','1','1973-08-19 06:42:32'),
	('7','8','2003-04-17 10:38:32','1','2013-10-19 13:41:55'),
	('8','9','1997-09-10 16:01:29','0','1972-04-24 13:21:05'),
	('9','10','1990-02-07 06:32:57','0','2015-05-17 08:30:18'),
	('10','1','1979-09-19 01:39:06','0','1979-09-14 05:07:50'); 

INSERT INTO comment_likes VALUES
	('1','1','0'),
	('1','11','1'),
	('1','21','1'),
	('1','31','1'),
	('1','41','1'),
	('2','2','0'),
	('2','12','0'),
	('2','22','1'),
	('2','32','0'),
	('2','42','1'),
	('3','3','1'),
	('3','13','1'),
	('3','23','1'),
	('3','33','0'),
	('3','43','0'),
	('4','4','1'),
	('4','14','0'),
	('4','24','0'),
	('4','34','1'),
	('4','44','0'),
	('5','5','0'),
	('5','15','1'),
	('5','25','0'),
	('5','35','0'),
	('5','45','1'),
	('6','6','0'),
	('6','16','0'),
	('6','26','0'),
	('6','36','0'),
	('6','46','0'),
	('7','7','1'),
	('7','17','0'),
	('7','27','0'),
	('7','37','0'),
	('7','47','0'),
	('8','8','1'),
	('8','18','1'),
	('8','28','0'),
	('8','38','1'),
	('8','48','1'),
	('9','9','1'),
	('9','19','1'),
	('9','29','1'),
	('9','39','0'),
	('9','49','1'),
	('10','10','0'),
	('10','20','0'),
	('10','30','0'),
	('10','40','1'),
	('10','50','1'); 

INSERT INTO video_categories VALUES
	('1','rerum','2012-10-29 14:31:40','2018-05-09 22:31:13','1'),
	('2','eum','1991-08-26 11:39:35','1996-02-10 23:02:12','0'),
	('3','iusto','1976-01-26 07:58:27','2017-06-26 18:36:53','0'),
	('4','dicta','1983-10-17 01:42:54','2009-10-30 00:37:31','1'),
	('5','sequi','1998-07-08 17:19:54','2012-03-28 09:39:45','0'),
	('6','sed','1999-05-21 06:27:41','1977-02-24 14:26:14','1'),
	('7','nesciunt','1973-05-21 03:21:15','1996-11-03 17:26:40','1'),
	('8','veniam','2000-02-11 01:49:26','2000-02-13 09:07:42','1'),
	('9','quo','1978-08-03 07:46:29','1971-03-27 14:21:33','1'),
	('10','dicta','1975-07-27 02:31:26','1977-09-17 23:22:16','1'); 

INSERT INTO video_categories_relations VALUES
	('1','1'),
	('2','2'),
	('3','3'),
	('4','4'),
	('5','5'),
	('6','6'),
	('7','7'),
	('8','8'),
	('9','9'),
	('10','10'),
	('11','1'),
	('12','2'),
	('13','3'),
	('14','4'),
	('15','5'),
	('16','6'),
	('17','7'),
	('18','8'),
	('19','9'),
	('20','10'),
	('21','1'),
	('22','2'),
	('23','3'),
	('24','4'),
	('25','5'),
	('26','6'),
	('27','7'),
	('28','8'),
	('29','9'),
	('30','10'),
	('31','1'),
	('32','2'),
	('33','3'),
	('34','4'),
	('35','5'),
	('36','6'),
	('37','7'),
	('38','8'),
	('39','9'),
	('40','10'),
	('41','1'),
	('42','2'),
	('43','3'),
	('44','4'),
	('45','5'),
	('46','6'),
	('47','7'),
	('48','8'),
	('49','9'),
	('50','10'); 

-- Функции
-- Функция возвращает полное имя пользователя
DROP FUNCTION IF EXISTS get_fullname;
DELIMITER //
CREATE FUNCTION get_fullname(user_id BIGINT UNSIGNED)
RETURNS VARCHAR(604) READS SQL DATA
BEGIN
    DECLARE firstname_var VARCHAR(200);
    DECLARE lastname_var VARCHAR(200);
    DECLARE username_var VARCHAR(200);
    DECLARE fullname VARCHAR(604);
    
    SET firstname_var = (SELECT firstname FROM users WHERE id = user_id);
    SET lastname_var = (SELECT lastname FROM users WHERE id = user_id);
    SET username_var = (SELECT username FROM users WHERE id = user_id);
    
    IF firstname_var IS NULL AND lastname_var IS NULL THEN
		SET fullname = CONCAT('"', username_var, '"');
	ELSEIF firstname_var IS NULL THEN
		SET fullname = CONCAT('"', username_var, '" ', lastname_var);
	ELSEIF lastname_var IS NULL THEN
		SET fullname = CONCAT(firstname_var, ' "', username_var, '"');
	ELSE SET fullname = CONCAT(firstname_var, ' "', username_var, '" ', lastname_var);
	END IF;
    
	RETURN fullname;
END//
DELIMITER ;

-- Проверка функции get_fullname
SELECT get_fullname(1), get_fullname(2), get_fullname(3), get_fullname(4);

-- Представления
-- Полная информация о пользователях
DROP VIEW IF EXISTS full_user_info;
CREATE VIEW full_user_info AS
SELECT get_fullname(u.id) AS 'fullname', u.email, ud.gender, ud.birthday, ud.country, ud.hometown, ud.bio, u.is_deleted
FROM users AS u
JOIN user_data AS ud
ON u.id = ud.user_id;

-- Проверка представления
SELECT * FROM full_user_info;

-- Число пользователей мужского и женского рода
DROP VIEW IF EXISTS gender_aggregate_info;
CREATE VIEW gender_aggregate_info AS
SELECT gender, COUNT(*) AS total
FROM user_data
GROUP BY gender;

-- Проверка представления
SELECT * FROM gender_aggregate_info;

-- Характерные выборки
-- Список роликов каналов, на которые подписан пользователь
SELECT v.video_name, c.channel_name, v.created_at
FROM videos AS v
JOIN channels AS c
ON v.channel_id = c.id
JOIN channel_subscriptions AS cs
ON c.id = cs.channel_id
WHERE cs.user_id = 1
AND cs.is_unsubbed = FALSE
ORDER BY v.created_at DESC;

-- Данные о видео
SELECT v.video_name, v.viewcount, v.likes_count, COUNT(vc.id) AS 'comment_count'
FROM videos AS v
JOIN video_comments AS vc
ON v.id = vc.video_id
WHERE v.id = 1
GROUP BY v.id;