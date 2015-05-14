SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";

CREATE TABLE IF NOT EXISTS `bandwidth_save` (
  `option` varchar(16) NOT NULL,
  `value` varchar(16) NOT NULL,
  PRIMARY KEY (`option`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `bandwidth_usage` (
  `name` varchar(64) NOT NULL,
  `type` char(1) NOT NULL,
  `year` smallint(4) unsigned NOT NULL,
  `value2` smallint(4) unsigned NOT NULL,
  `bytes` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`name`,`type`,`year`,`value2`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
