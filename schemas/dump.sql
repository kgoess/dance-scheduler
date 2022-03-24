-- MySQL dump 10.14  Distrib 5.5.68-MariaDB, for Linux (x86_64)
--
-- Host: localhost    Database: schedule
-- ------------------------------------------------------
-- Server version	5.5.68-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `band_membership`
--

DROP TABLE IF EXISTS `band_membership`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `band_membership` (
  `band_id` int(11) NOT NULL,
  `talent_id` int(11) NOT NULL,
  UNIQUE KEY `band_membership_idx` (`band_id`,`talent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `band_membership`
--

LOCK TABLES `band_membership` WRITE;
/*!40000 ALTER TABLE `band_membership` DISABLE KEYS */;
/*!40000 ALTER TABLE `band_membership` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `bands`
--

DROP TABLE IF EXISTS `bands`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bands` (
  `band_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(256) NOT NULL,
  `created_ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `modified_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`band_id`),
  UNIQUE KEY `band_name_idx` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `bands`
--

LOCK TABLES `bands` WRITE;
/*!40000 ALTER TABLE `bands` DISABLE KEYS */;
/*!40000 ALTER TABLE `bands` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `callers`
--

DROP TABLE IF EXISTS `callers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `callers` (
  `caller_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(256) NOT NULL,
  `created_ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `modified_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`caller_id`),
  UNIQUE KEY `caller_id_idx` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `callers`
--

LOCK TABLES `callers` WRITE;
/*!40000 ALTER TABLE `callers` DISABLE KEYS */;
/*!40000 ALTER TABLE `callers` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `event_band_map`
--

DROP TABLE IF EXISTS `event_band_map`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `event_band_map` (
  `event_id` int(11) NOT NULL,
  `band_id` int(11) NOT NULL,
  `ordering` int(11) NOT NULL,
  UNIQUE KEY `event_id` (`event_id`,`band_id`),
  UNIQUE KEY `event_id_2` (`event_id`,`ordering`),
  KEY `band_id` (`band_id`),
  CONSTRAINT `event_band_map_ibfk_1` FOREIGN KEY (`event_id`) REFERENCES `events` (`event_id`),
  CONSTRAINT `event_band_map_ibfk_2` FOREIGN KEY (`band_id`) REFERENCES `bands` (`band_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `event_band_map`
--

LOCK TABLES `event_band_map` WRITE;
/*!40000 ALTER TABLE `event_band_map` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_band_map` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `event_callers_map`
--

DROP TABLE IF EXISTS `event_callers_map`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `event_callers_map` (
  `event_id` int(11) NOT NULL,
  `caller_id` int(11) NOT NULL,
  `ordering` int(11) NOT NULL,
  UNIQUE KEY `event_id` (`event_id`,`caller_id`),
  UNIQUE KEY `event_id_2` (`event_id`,`ordering`),
  KEY `caller_id` (`caller_id`),
  CONSTRAINT `event_callers_map_ibfk_1` FOREIGN KEY (`event_id`) REFERENCES `events` (`event_id`),
  CONSTRAINT `event_callers_map_ibfk_2` FOREIGN KEY (`caller_id`) REFERENCES `callers` (`caller_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `event_callers_map`
--

LOCK TABLES `event_callers_map` WRITE;
/*!40000 ALTER TABLE `event_callers_map` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_callers_map` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `event_styles_map`
--

DROP TABLE IF EXISTS `event_styles_map`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `event_styles_map` (
  `event_id` int(11) NOT NULL,
  `style_id` int(11) NOT NULL,
  `ordering` int(11) NOT NULL,
  UNIQUE KEY `event_id` (`event_id`,`style_id`),
  UNIQUE KEY `event_id_2` (`event_id`,`ordering`),
  KEY `style_id` (`style_id`),
  CONSTRAINT `event_styles_map_ibfk_1` FOREIGN KEY (`event_id`) REFERENCES `events` (`event_id`),
  CONSTRAINT `event_styles_map_ibfk_2` FOREIGN KEY (`style_id`) REFERENCES `styles` (`style_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `event_styles_map`
--

LOCK TABLES `event_styles_map` WRITE;
/*!40000 ALTER TABLE `event_styles_map` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_styles_map` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `event_talent_map`
--

DROP TABLE IF EXISTS `event_talent_map`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `event_talent_map` (
  `event_id` int(11) NOT NULL,
  `talent_id` int(11) NOT NULL,
  `ordering` int(11) NOT NULL,
  UNIQUE KEY `event_id` (`event_id`,`talent_id`),
  UNIQUE KEY `event_id_2` (`event_id`,`ordering`),
  KEY `talent_id` (`talent_id`),
  CONSTRAINT `event_talent_map_ibfk_1` FOREIGN KEY (`event_id`) REFERENCES `events` (`event_id`),
  CONSTRAINT `event_talent_map_ibfk_2` FOREIGN KEY (`talent_id`) REFERENCES `talent` (`talent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `event_talent_map`
--

LOCK TABLES `event_talent_map` WRITE;
/*!40000 ALTER TABLE `event_talent_map` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_talent_map` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `event_venues_map`
--

DROP TABLE IF EXISTS `event_venues_map`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `event_venues_map` (
  `event_id` int(11) NOT NULL,
  `venue_id` int(11) NOT NULL,
  `ordering` int(11) NOT NULL,
  UNIQUE KEY `event_id` (`event_id`,`venue_id`),
  UNIQUE KEY `event_id_2` (`event_id`,`ordering`),
  KEY `venue_id` (`venue_id`),
  CONSTRAINT `event_venues_map_ibfk_1` FOREIGN KEY (`event_id`) REFERENCES `events` (`event_id`),
  CONSTRAINT `event_venues_map_ibfk_2` FOREIGN KEY (`venue_id`) REFERENCES `venues` (`venue_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `event_venues_map`
--

LOCK TABLES `event_venues_map` WRITE;
/*!40000 ALTER TABLE `event_venues_map` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_venues_map` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `events`
--

DROP TABLE IF EXISTS `events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `events` (
  `event_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(256) DEFAULT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime DEFAULT NULL,
  `is_camp` tinyint(1) DEFAULT NULL,
  `long_desc` varchar(32766) DEFAULT NULL,
  `short_desc` varchar(1024) DEFAULT NULL,
  `is_template` tinyint(1) DEFAULT NULL,
  `series_id` int(11) DEFAULT NULL,
  `event_type` enum('ONEDAY','MULTIDAY') DEFAULT NULL,
  `created_ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `modified_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`event_id`),
  UNIQUE KEY `series_id` (`series_id`,`is_template`),
  KEY `events_name_idx` (`name`),
  KEY `events_start_time_idx` (`start_time`),
  KEY `events_series_idx` (`series_id`),
  CONSTRAINT `events_ibfk_1` FOREIGN KEY (`series_id`) REFERENCES `series` (`series_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `events`
--

LOCK TABLES `events` WRITE;
/*!40000 ALTER TABLE `events` DISABLE KEYS */;
/*!40000 ALTER TABLE `events` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `series`
--

DROP TABLE IF EXISTS `series`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `series` (
  `series_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(256) DEFAULT NULL,
  `frequency` varchar(128) DEFAULT NULL,
  `created_ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `modified_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`series_id`),
  KEY `series_name_idx` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `series`
--

LOCK TABLES `series` WRITE;
/*!40000 ALTER TABLE `series` DISABLE KEYS */;
/*!40000 ALTER TABLE `series` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `styles`
--

DROP TABLE IF EXISTS `styles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `styles` (
  `style_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(256) NOT NULL,
  `created_ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `modified_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`style_id`),
  UNIQUE KEY `style_id_idx` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `styles`
--

LOCK TABLES `styles` WRITE;
/*!40000 ALTER TABLE `styles` DISABLE KEYS */;
/*!40000 ALTER TABLE `styles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `talent`
--

DROP TABLE IF EXISTS `talent`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `talent` (
  `talent_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(256) NOT NULL,
  `created_ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `modified_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`talent_id`),
  UNIQUE KEY `talent_name_idx` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `talent`
--

LOCK TABLES `talent` WRITE;
/*!40000 ALTER TABLE `talent` DISABLE KEYS */;
/*!40000 ALTER TABLE `talent` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `venues`
--

DROP TABLE IF EXISTS `venues`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `venues` (
  `venue_id` int(11) NOT NULL AUTO_INCREMENT,
  `vkey` char(10) NOT NULL,
  `hall_name` varchar(128) NOT NULL,
  `address` varchar(256) DEFAULT NULL,
  `city` varchar(64) DEFAULT NULL,
  `zip` char(10) DEFAULT NULL,
  `comment` varchar(32766) DEFAULT NULL,
  `created_ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `modified_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`venue_id`),
  UNIQUE KEY `vkey_idx` (`vkey`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `venues`
--

LOCK TABLES `venues` WRITE;
/*!40000 ALTER TABLE `venues` DISABLE KEYS */;
/*!40000 ALTER TABLE `venues` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2022-03-18 21:24:54
