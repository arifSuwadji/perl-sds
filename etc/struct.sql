-- MySQL dump 10.13  Distrib 5.5.23, for Linux (i686)
--
-- Host: localhost    Database: sds
-- ------------------------------------------------------
-- Server version	5.5.23

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
-- Table structure for table `additional_user`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `additional_user` (
  `add_user_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `member_id` smallint(5) unsigned DEFAULT NULL,
  `username` varchar(15) NOT NULL,
  `pin` varchar(8) NOT NULL,
  `status` enum('Active','non-Active') DEFAULT NULL,
  PRIMARY KEY (`add_user_id`),
  UNIQUE KEY `username` (`username`),
  KEY `user_ibfk_1` (`member_id`),
  CONSTRAINT `additional_user_ibfk_1` FOREIGN KEY (`member_id`) REFERENCES `member` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `admin`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin` (
  `admin_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `admin_name` varchar(30) NOT NULL,
  `admin_password` varchar(40) NOT NULL,
  `session_id` varchar(40) DEFAULT NULL,
  `last_access` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `adm_gid` tinyint(3) unsigned DEFAULT NULL,
  `member_id` smallint(5) unsigned DEFAULT NULL,
  `site_id` tinyint(3) unsigned DEFAULT NULL,
  `ref_type_id` tinyint(3) unsigned DEFAULT NULL,
  PRIMARY KEY (`admin_id`),
  UNIQUE KEY `admin_name` (`admin_name`),
  UNIQUE KEY `session_id` (`session_id`),
  KEY `adm_gid` (`adm_gid`),
  KEY `member_id` (`member_id`),
  KEY `ref_type_id` (`ref_type_id`),
  KEY `site_id` (`site_id`),
  CONSTRAINT `admin_ibfk_1` FOREIGN KEY (`adm_gid`) REFERENCES `admin_group` (`adm_gid`),
  CONSTRAINT `admin_ibfk_2` FOREIGN KEY (`member_id`) REFERENCES `member` (`member_id`),
  CONSTRAINT `admin_ibfk_3` FOREIGN KEY (`site_id`) REFERENCES `site` (`site_id`),
  CONSTRAINT `admin_ibfk_4` FOREIGN KEY (`ref_type_id`) REFERENCES `stock_ref_type` (`ref_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `admin_group`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin_group` (
  `adm_gid` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `adm_group_name` varchar(15) NOT NULL,
  PRIMARY KEY (`adm_gid`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `admin_log`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin_log` (
  `admin_log_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `admin_id` tinyint(3) unsigned NOT NULL,
  `page_id` tinyint(3) unsigned NOT NULL,
  `admin_log_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `args` varchar(200) DEFAULT NULL,
  `ip` int(10) unsigned NOT NULL,
  PRIMARY KEY (`admin_log_id`),
  UNIQUE KEY `admin_log_ts` (`admin_log_ts`,`admin_id`,`page_id`),
  KEY `admin_id` (`admin_id`),
  KEY `page_id` (`page_id`),
  CONSTRAINT `admin_log_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `admin` (`admin_id`),
  CONSTRAINT `admin_log_ibfk_2` FOREIGN KEY (`page_id`) REFERENCES `page` (`page_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `config`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `config` (
  `config_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `config_name` varchar(30) NOT NULL,
  `config_value` int(11) NOT NULL,
  PRIMARY KEY (`config_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `deposit_web`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `deposit_web` (
  `admin_log_id` mediumint(8) unsigned NOT NULL,
  `trans_id` int(10) unsigned DEFAULT NULL,
  `dep_status` enum('','D','A') NOT NULL DEFAULT '',
  `dep_amount` int(11) NOT NULL,
  `user_id` smallint(5) unsigned NOT NULL,
  `need_reply` tinyint(3) unsigned NOT NULL,
  `out_ts` timestamp NULL DEFAULT NULL,
  UNIQUE KEY `admin_log_id` (`admin_log_id`),
  KEY `trans_id` (`trans_id`),
  KEY `user_id` (`user_id`,`out_ts`),
  KEY `dep_status` (`dep_status`),
  CONSTRAINT `deposit_web_ibfk_2` FOREIGN KEY (`admin_log_id`) REFERENCES `admin_log` (`admin_log_id`),
  CONSTRAINT `deposit_web_ibfk_3` FOREIGN KEY (`trans_id`) REFERENCES `transaction` (`trans_id`),
  CONSTRAINT `deposit_web_ibfk_4` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`),
  CONSTRAINT `deposit_web_ibfk_5` FOREIGN KEY (`user_id`, `out_ts`) REFERENCES `sms_outbox` (`user_id`, `out_ts`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='need_reply: already need reply message composition';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dompul_sale`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dompul_sale` (
  `sale_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `sale_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `member_id` smallint(5) unsigned NOT NULL,
  `ref_type_id` tinyint(3) unsigned NOT NULL,
  `qty_sale` mediumint(8) unsigned DEFAULT NULL,
  `rs_id` smallint(5) unsigned NOT NULL,
  `sms_id` mediumint(8) unsigned NOT NULL,
  PRIMARY KEY (`sale_id`),
  KEY `member_id` (`member_id`),
  KEY `ref_type_id` (`ref_type_id`),
  KEY `rs_id` (`rs_id`),
  KEY `sms_id` (`sms_id`),
  CONSTRAINT `dompul_sale_ibfk_1` FOREIGN KEY (`rs_id`) REFERENCES `rs_chip` (`rs_id`),
  CONSTRAINT `dompul_sale_ibfk_2` FOREIGN KEY (`member_id`) REFERENCES `member` (`member_id`),
  CONSTRAINT `dompul_sale_ibfk_3` FOREIGN KEY (`ref_type_id`) REFERENCES `stock_ref_type` (`ref_type_id`),
  CONSTRAINT `dompul_sale_ibfk_4` FOREIGN KEY (`sms_id`) REFERENCES `sms` (`sms_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `dompul_target`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dompul_target` (
  `dt_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `member_id` smallint(5) unsigned NOT NULL,
  `ref_type_id` tinyint(3) unsigned NOT NULL,
  `qty_target` mediumint(8) unsigned DEFAULT NULL,
  `day` enum('','Mon','Tue','Wed','Thu','Fri','Sat') NOT NULL DEFAULT '',
  `outlet_id` smallint(5) unsigned NOT NULL,
  `nominal_target` decimal(13,3) unsigned DEFAULT '0.000',
  PRIMARY KEY (`dt_id`),
  UNIQUE KEY `member_outlet_day` (`member_id`,`day`,`outlet_id`),
  KEY `member_id` (`member_id`),
  KEY `ref_type_id` (`ref_type_id`),
  KEY `outlet_id` (`outlet_id`),
  CONSTRAINT `dompul_target_ibfk_1` FOREIGN KEY (`member_id`) REFERENCES `member` (`member_id`),
  CONSTRAINT `dompul_target_ibfk_2` FOREIGN KEY (`ref_type_id`) REFERENCES `stock_ref_type` (`ref_type_id`),
  CONSTRAINT `dompul_target_ibfk_3` FOREIGN KEY (`outlet_id`) REFERENCES `outlet` (`outlet_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `invoice`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `invoice` (
  `inv_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `inv_date` date DEFAULT '0000-00-00',
  `outlet_id` smallint(5) unsigned NOT NULL,
  `member_id` smallint(5) unsigned NOT NULL,
  `status` enum('Unpaid','Paid') DEFAULT 'Unpaid',
  `debt` tinyint(3) unsigned NOT NULL,
  `due_date` date DEFAULT '0000-00-00',
  `trans_id` int(10) unsigned DEFAULT NULL,
  `amount` int(10) unsigned DEFAULT NULL,
  `note_bank` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`inv_id`),
  UNIQUE KEY `inv_date` (`inv_date`,`outlet_id`),
  KEY `outlet_id` (`outlet_id`),
  KEY `trans_id` (`trans_id`),
  CONSTRAINT `invoice_ibfk_1` FOREIGN KEY (`outlet_id`) REFERENCES `outlet` (`outlet_id`),
  CONSTRAINT `invoice_ibfk_2` FOREIGN KEY (`trans_id`) REFERENCES `transaction` (`trans_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `member`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `member` (
  `member_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` smallint(5) unsigned DEFAULT NULL,
  `member_name` varchar(30) NOT NULL,
  `member_balance` decimal(13,3) unsigned NOT NULL,
  `site_id` tinyint(3) unsigned DEFAULT NULL,
  `status` enum('Active','non-Active') NOT NULL,
  `member_type` enum('CVS','SPV','BM') DEFAULT 'CVS',
  `member_target` decimal(13,3) unsigned DEFAULT '0.000',
  `target_qty` mediumint(8) unsigned DEFAULT NULL,
  PRIMARY KEY (`member_id`),
  KEY `site_id` (`site_id`),
  CONSTRAINT `member_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `site` (`site_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `modem`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `modem` (
  `modem_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `modem_name` varchar(30) DEFAULT NULL,
  `pin` varchar(8) DEFAULT NULL,
  `status` enum('Active','non-Active') DEFAULT 'Active',
  PRIMARY KEY (`modem_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `msisdn_perdana`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `msisdn_perdana` (
  `perdana_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `perdana_number` varchar(15) NOT NULL,
  `status` enum('Active','non-Active','Approve') DEFAULT 'Active',
  `note` varchar(200) NOT NULL,
  PRIMARY KEY (`perdana_id`),
  UNIQUE KEY `perdana_number` (`perdana_number`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `mutation`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mutation` (
  `trans_id` int(10) unsigned NOT NULL,
  `member_id` smallint(5) unsigned NOT NULL,
  `amount` decimal(13,3) NOT NULL,
  `balance` decimal(13,3) unsigned NOT NULL,
  PRIMARY KEY (`trans_id`),
  KEY `member_id` (`member_id`),
  CONSTRAINT `mutation_ibfk_1` FOREIGN KEY (`trans_id`) REFERENCES `transaction` (`trans_id`),
  CONSTRAINT `mutation_ibfk_2` FOREIGN KEY (`member_id`) REFERENCES `member` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `outlet`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `outlet` (
  `outlet_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `outlet_name` varchar(50) DEFAULT NULL,
  `address` varchar(100) DEFAULT NULL,
  `district` varchar(20) DEFAULT NULL,
  `sub_district` varchar(20) DEFAULT NULL,
  `pos_code` varchar(10) DEFAULT NULL,
  `owner` varchar(20) DEFAULT NULL,
  `mobile_phone` varchar(20) DEFAULT NULL,
  `outlet_type_id` tinyint(3) unsigned NOT NULL,
  `plafond` decimal(13,0) unsigned DEFAULT '0',
  `balance` decimal(13,0) DEFAULT '0',
  `nominal_quota` decimal(13,0) unsigned DEFAULT '0',
  `balance_nominal` decimal(13,0) DEFAULT '0',
  `qty_quota` int(10) unsigned DEFAULT '0',
  `balance_qty` int(10) unsigned DEFAULT '0',
  `status` enum('Active','non-Active') DEFAULT 'Active',
  `birth_date` date DEFAULT '0000-00-00',
  PRIMARY KEY (`outlet_id`),
  KEY `outlet_type_id` (`outlet_type_id`),
  CONSTRAINT `outlet_ibfk_1` FOREIGN KEY (`outlet_type_id`) REFERENCES `outlet_type` (`outlet_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `outlet_mutation`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `outlet_mutation` (
  `outlet_id` smallint(5) unsigned NOT NULL,
  `trans_id` int(10) unsigned NOT NULL,
  `balance` mediumint(9) DEFAULT NULL,
  `mutation` mediumint(9) DEFAULT NULL,
  PRIMARY KEY (`outlet_id`,`trans_id`),
  KEY `trans_id` (`trans_id`),
  CONSTRAINT `outlet_mutation_ibfk_1` FOREIGN KEY (`outlet_id`) REFERENCES `outlet` (`outlet_id`),
  CONSTRAINT `outlet_mutation_ibfk_2` FOREIGN KEY (`trans_id`) REFERENCES `transaction` (`trans_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `outlet_pricing`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `outlet_pricing` (
  `stock_ref_id` tinyint(3) unsigned NOT NULL,
  `price` decimal(13,3) unsigned NOT NULL,
  `outlet_type_id` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY (`stock_ref_id`,`outlet_type_id`),
  KEY `outlet_type_id` (`outlet_type_id`),
  CONSTRAINT `outlet_pricing_ibfk_1` FOREIGN KEY (`stock_ref_id`) REFERENCES `stock_ref` (`stock_ref_id`),
  CONSTRAINT `outlet_pricing_ibfk_2` FOREIGN KEY (`outlet_type_id`) REFERENCES `outlet_type` (`outlet_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `outlet_quota`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `outlet_quota` (
  `outlet_quota_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `outlet_id` smallint(5) unsigned NOT NULL,
  `stock_ref_id` tinyint(3) unsigned NOT NULL,
  `quota` int(10) unsigned DEFAULT '0',
  PRIMARY KEY (`outlet_quota_id`),
  KEY `outlet_id` (`outlet_id`),
  KEY `stock_ref_id` (`stock_ref_id`),
  CONSTRAINT `outlet_quota_ibfk_1` FOREIGN KEY (`outlet_id`) REFERENCES `outlet` (`outlet_id`),
  CONSTRAINT `outlet_quota_ibfk_2` FOREIGN KEY (`stock_ref_id`) REFERENCES `stock_ref` (`stock_ref_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `outlet_type`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `outlet_type` (
  `outlet_type_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `type_name` varchar(10) DEFAULT NULL,
  `period` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY (`outlet_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `package`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `package` (
  `pkg_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `pkg_name` varchar(15) NOT NULL,
  PRIMARY KEY (`pkg_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `package_detail`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `package_detail` (
  `pkg_id` smallint(5) unsigned NOT NULL,
  `stock_ref_id` tinyint(3) unsigned NOT NULL,
  `pkg_qty` tinyint(3) unsigned DEFAULT NULL,
  PRIMARY KEY (`pkg_id`,`stock_ref_id`),
  UNIQUE KEY `pkg_id` (`pkg_id`,`stock_ref_id`),
  KEY `stock_ref_id` (`stock_ref_id`),
  CONSTRAINT `package_detail_ibfk_1` FOREIGN KEY (`pkg_id`) REFERENCES `package` (`pkg_id`),
  CONSTRAINT `package_detail_ibfk_2` FOREIGN KEY (`stock_ref_id`) REFERENCES `stock_ref` (`stock_ref_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `page`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `page` (
  `page_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `path` varchar(50) NOT NULL,
  `path_title` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`page_id`),
  UNIQUE KEY `path` (`path`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `page_map`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `page_map` (
  `adm_gid` tinyint(3) unsigned NOT NULL,
  `page_id` tinyint(3) unsigned NOT NULL,
  KEY `adm_gid` (`adm_gid`),
  KEY `page_id` (`page_id`),
  CONSTRAINT `page_map_ibfk_1` FOREIGN KEY (`adm_gid`) REFERENCES `admin_group` (`adm_gid`),
  CONSTRAINT `page_map_ibfk_2` FOREIGN KEY (`page_id`) REFERENCES `page` (`page_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `perdana_cmd`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `perdana_cmd` (
  `cmd_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `cmd_name` varchar(30) DEFAULT NULL,
  `type` enum('sms','ussd') DEFAULT NULL,
  `command` varchar(100) DEFAULT NULL,
  `receiver` varchar(12) DEFAULT NULL,
  PRIMARY KEY (`cmd_id`),
  UNIQUE KEY `cmd_name` (`cmd_name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pricing`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `pricing` (
  `stock_ref_id` tinyint(3) unsigned NOT NULL,
  `rs_type_id` tinyint(3) unsigned NOT NULL,
  `price` decimal(13,3) unsigned NOT NULL,
  `price_type` enum('OLD','NEW') NOT NULL DEFAULT 'OLD',
  `old_price` decimal(13,3) unsigned DEFAULT NULL,
  PRIMARY KEY (`stock_ref_id`,`rs_type_id`),
  KEY `pricing_ibfk_2` (`rs_type_id`),
  CONSTRAINT `pricing_ibfk_1` FOREIGN KEY (`stock_ref_id`) REFERENCES `stock_ref` (`stock_ref_id`),
  CONSTRAINT `pricing_ibfk_2` FOREIGN KEY (`rs_type_id`) REFERENCES `rs_type` (`rs_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pricing_temporary`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `pricing_temporary` (
  `stock_ref_id` tinyint(3) unsigned NOT NULL,
  `rs_type_id` tinyint(3) unsigned NOT NULL,
  `save_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `price` decimal(13,3) unsigned NOT NULL,
  `price_type` enum('OLD','NEW') NOT NULL DEFAULT 'NEW',
  PRIMARY KEY (`stock_ref_id`,`rs_type_id`),
  KEY `rs_type_id` (`rs_type_id`),
  CONSTRAINT `pricing_temporary_ibfk_1` FOREIGN KEY (`stock_ref_id`) REFERENCES `stock_ref` (`stock_ref_id`),
  CONSTRAINT `pricing_temporary_ibfk_2` FOREIGN KEY (`rs_type_id`) REFERENCES `rs_type` (`rs_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rs_chip`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rs_chip` (
  `rs_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `sd_id` smallint(5) unsigned NOT NULL,
  `rs_number` varchar(15) NOT NULL,
  `member_id` smallint(5) unsigned DEFAULT NULL,
  `rs_type_id` tinyint(3) unsigned DEFAULT NULL,
  `outlet_id` smallint(5) unsigned NOT NULL,
  `rs_chip_type` enum('dompul','mkios','esia') DEFAULT NULL,
  `rs_nominal_quota` decimal(13,0) unsigned DEFAULT '0',
  `rs_balance_nominal` decimal(13,0) DEFAULT '0',
  `rs_qty_quota` int(10) unsigned DEFAULT '0',
  `rs_balance_qty` int(10) unsigned DEFAULT '0',
  `status` enum('Active','non-Active') NOT NULL DEFAULT 'Active',
  `rs_outlet_id` varchar(30) NOT NULL,
  PRIMARY KEY (`rs_id`),
  UNIQUE KEY `rs_number` (`rs_number`),
  KEY `sd_id` (`sd_id`),
  KEY `member_id` (`member_id`),
  KEY `rs_type_id` (`rs_type_id`),
  KEY `outlet_id` (`outlet_id`),
  CONSTRAINT `rs_chip_ibfk_1` FOREIGN KEY (`sd_id`) REFERENCES `sd_chip` (`sd_id`),
  CONSTRAINT `rs_chip_ibfk_2` FOREIGN KEY (`member_id`) REFERENCES `member` (`member_id`),
  CONSTRAINT `rs_chip_ibfk_3` FOREIGN KEY (`rs_type_id`) REFERENCES `rs_type` (`rs_type_id`),
  CONSTRAINT `rs_chip_ibfk_4` FOREIGN KEY (`outlet_id`) REFERENCES `outlet` (`outlet_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rs_request`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rs_request` (
  `rs_req_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `rs_req_number` varchar(15) NOT NULL,
  `rs_req_response` varchar(180) DEFAULT NULL,
  `rs_req_status` enum('W','P','F','S') NOT NULL DEFAULT 'W',
  `rs_req_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `sd_id` smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`rs_req_id`),
  KEY `sd_id` (`sd_id`),
  CONSTRAINT `rs_request_ibfk_1` FOREIGN KEY (`sd_id`) REFERENCES `sd_chip` (`sd_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rs_stock`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rs_stock` (
  `rs_stock_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `rs_id` smallint(5) unsigned NOT NULL,
  `stock_ref_id` tinyint(3) unsigned NOT NULL,
  `request` smallint(6) NOT NULL,
  `approve` smallint(6) NOT NULL,
  `quota` int(10) unsigned DEFAULT '0',
  PRIMARY KEY (`rs_stock_id`),
  KEY `stock_ref_id` (`stock_ref_id`),
  KEY `rs_id` (`rs_id`),
  CONSTRAINT `rs_stock_ibfk_1` FOREIGN KEY (`rs_id`) REFERENCES `rs_chip` (`rs_id`),
  CONSTRAINT `rs_stock_ibfk_2` FOREIGN KEY (`stock_ref_id`) REFERENCES `stock_ref` (`stock_ref_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rs_type`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rs_type` (
  `rs_type_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `type_name` varchar(15) NOT NULL,
  PRIMARY KEY (`rs_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sd_chip`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sd_chip` (
  `sd_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `sd_name` varchar(25) DEFAULT NULL,
  `sd_number` varchar(15) NOT NULL,
  `ref_type_id` tinyint(3) unsigned NOT NULL,
  `site_id` tinyint(3) unsigned NOT NULL,
  `modem` varchar(20) NOT NULL,
  `pin` varchar(8) DEFAULT NULL,
  `last_topup` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`sd_id`),
  KEY `sd_chip_ibfk2` (`site_id`),
  KEY `modem_id` (`modem`),
  KEY `ref_type_id` (`ref_type_id`),
  CONSTRAINT `sd_chip_ibfk2` FOREIGN KEY (`site_id`) REFERENCES `site` (`site_id`),
  CONSTRAINT `sd_chip_ibfk_5` FOREIGN KEY (`ref_type_id`) REFERENCES `stock_ref_type` (`ref_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sd_log`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sd_log` (
  `log_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `sd_id` smallint(5) unsigned NOT NULL,
  `local_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `orig_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `log_msg` varchar(255) NOT NULL,
  PRIMARY KEY (`log_id`),
  UNIQUE KEY `sd_id` (`sd_id`,`orig_ts`),
  CONSTRAINT `sd_log_ibfk_1` FOREIGN KEY (`sd_id`) REFERENCES `sd_chip` (`sd_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='menangkap report trx(atau non trx) dari chip sd : misalnya dari inbox sms';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sd_stock`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sd_stock` (
  `sd_stock_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `sd_id` smallint(5) unsigned NOT NULL,
  `stock_ref_id` tinyint(3) unsigned NOT NULL,
  `qty` int(10) unsigned NOT NULL,
  `quota` int(10) unsigned DEFAULT '0',
  `qty_tmp` int(10) unsigned DEFAULT '0',
  `admin_id` tinyint(3) unsigned NOT NULL,
  `sd_stock_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`sd_stock_id`),
  UNIQUE KEY `sd_id` (`sd_id`,`stock_ref_id`),
  KEY `stock_ref_id` (`stock_ref_id`),
  KEY `admin_id` (`admin_id`),
  CONSTRAINT `sd_stock_ibfk_1` FOREIGN KEY (`sd_id`) REFERENCES `sd_chip` (`sd_id`),
  CONSTRAINT `sd_stock_ibfk_2` FOREIGN KEY (`stock_ref_id`) REFERENCES `stock_ref` (`stock_ref_id`),
  CONSTRAINT `sd_stock_ibfk_3` FOREIGN KEY (`admin_id`) REFERENCES `admin` (`admin_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `site`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `site` (
  `site_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `site_name` varchar(30) NOT NULL,
  `site_url` varchar(40) DEFAULT NULL,
  PRIMARY KEY (`site_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sms`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sms` (
  `sms_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `sms_int` varchar(100) DEFAULT NULL,
  `user_id` smallint(5) unsigned NOT NULL,
  `sms_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `sms_localtime` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `smsc_id` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY (`sms_id`),
  UNIQUE KEY `user_id` (`user_id`,`sms_time`),
  KEY `smsc_id` (`smsc_id`),
  CONSTRAINT `sms_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`),
  CONSTRAINT `sms_ibfk_2` FOREIGN KEY (`smsc_id`) REFERENCES `smsc` (`smsc_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sms_outbox`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sms_outbox` (
  `sms_id` mediumint(8) unsigned DEFAULT NULL,
  `user_id` smallint(5) unsigned NOT NULL,
  `out_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `smsc_id` tinyint(3) unsigned DEFAULT NULL,
  `out_status` enum('','W','P','S','F') NOT NULL,
  `out_msg` varchar(160) NOT NULL,
  UNIQUE KEY `out_ts` (`out_ts`,`user_id`),
  KEY `sms_id` (`sms_id`),
  KEY `user_id` (`user_id`),
  KEY `smsc_id` (`smsc_id`),
  CONSTRAINT `sms_outbox_ibfk_1` FOREIGN KEY (`sms_id`) REFERENCES `sms` (`sms_id`),
  CONSTRAINT `sms_outbox_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`),
  CONSTRAINT `sms_outbox_ibfk_3` FOREIGN KEY (`smsc_id`) REFERENCES `smsc` (`smsc_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='sms message only! doesnt handle other msg gtw type (web,h2h)';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sms_outbox_rs`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sms_outbox_rs` (
  `sms_id` mediumint(8) unsigned DEFAULT NULL,
  `rs_id` smallint(5) unsigned NOT NULL,
  `out_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `smsc_id` tinyint(3) unsigned DEFAULT NULL,
  `out_status` enum('','W','P','S','F') NOT NULL,
  `out_msg` varchar(160) NOT NULL,
  UNIQUE KEY `out_ts` (`out_ts`,`rs_id`),
  KEY `sms_id` (`sms_id`),
  KEY `rs_id` (`rs_id`),
  KEY `smsc_id` (`smsc_id`),
  CONSTRAINT `sms_outbox_rs_ibfk_1` FOREIGN KEY (`sms_id`) REFERENCES `sms` (`sms_id`),
  CONSTRAINT `sms_outbox_rs_ibfk_2` FOREIGN KEY (`rs_id`) REFERENCES `rs_chip` (`rs_id`),
  CONSTRAINT `sms_outbox_rs_ibfk_3` FOREIGN KEY (`smsc_id`) REFERENCES `smsc` (`smsc_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='untuk mengirim pesan ke rs';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sms_rs`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sms_rs` (
  `sms_rs_id` mediumint(8) unsigned NOT NULL AUTO_INCREMENT,
  `sms_int` varchar(100) DEFAULT NULL,
  `rs_id` smallint(5) unsigned NOT NULL,
  `sms_out` varchar(100) DEFAULT NULL,
  `sms_time` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `sms_localtime` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `out_status` enum('','W','P','F','S') NOT NULL DEFAULT '',
  `in_smsc_id` tinyint(3) unsigned NOT NULL,
  `out_smsc_id` tinyint(3) unsigned DEFAULT NULL,
  PRIMARY KEY (`sms_rs_id`),
  UNIQUE KEY `rs_id` (`rs_id`,`sms_time`),
  KEY `in_smsc_id` (`in_smsc_id`),
  KEY `out_smsc_id` (`out_smsc_id`),
  CONSTRAINT `sms_rs_ibfk_1` FOREIGN KEY (`rs_id`) REFERENCES `rs_chip` (`rs_id`),
  CONSTRAINT `sms_rs_ibfk_2` FOREIGN KEY (`in_smsc_id`) REFERENCES `smsc` (`smsc_id`),
  CONSTRAINT `sms_rs_ibfk_3` FOREIGN KEY (`out_smsc_id`) REFERENCES `smsc` (`smsc_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `smsc`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `smsc` (
  `smsc_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `smsc_name` varchar(20) DEFAULT NULL,
  `smsc_type` enum('sender','center') DEFAULT 'sender',
  `smsc_status` enum('active','non-active') DEFAULT 'active',
  `site_id` tinyint(3) unsigned DEFAULT NULL,
  PRIMARY KEY (`smsc_id`),
  KEY `site_id` (`site_id`),
  CONSTRAINT `smsc_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `site` (`site_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `stock_denom`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stock_denom` (
  `trans_id` int(10) unsigned NOT NULL,
  `stock_ref_id` tinyint(3) unsigned NOT NULL,
  `last_balance` mediumint(9) DEFAULT '0',
  UNIQUE KEY `trans_id` (`trans_id`,`stock_ref_id`),
  KEY `stock_ref_id` (`stock_ref_id`),
  CONSTRAINT `stock_denom_ibfk_1` FOREIGN KEY (`trans_id`) REFERENCES `transaction` (`trans_id`),
  CONSTRAINT `stock_denom_ibfk_2` FOREIGN KEY (`stock_ref_id`) REFERENCES `stock_ref` (`stock_ref_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

--
-- Table structure for table `stock_mutation`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stock_mutation` (
  `sm_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `sm_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `trans_id` int(10) unsigned DEFAULT NULL,
  `sd_stock_id` smallint(5) unsigned NOT NULL,
  `trx_qty` int(11) NOT NULL,
  `stock_qty` int(10) unsigned NOT NULL,
  PRIMARY KEY (`sm_id`),
  KEY `sd_stock_id` (`sd_stock_id`),
  KEY `trans_id` (`trans_id`),
  CONSTRAINT `stock_mutation_ibfk_1` FOREIGN KEY (`sd_stock_id`) REFERENCES `sd_stock` (`sd_stock_id`),
  CONSTRAINT `stock_mutation_ibfk_2` FOREIGN KEY (`trans_id`) REFERENCES `transaction` (`trans_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='related to "top","rev", or NO trx (trans_id NULLable)';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `stock_ref`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stock_ref` (
  `stock_ref_id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
  `stock_ref_name` varchar(20) NOT NULL,
  `keyword` varchar(10) NOT NULL,
  `ref_type_id` tinyint(3) unsigned NOT NULL,
  `mapping` tinyint(3) unsigned DEFAULT NULL,
  `max_qty` mediumint(9) unsigned NOT NULL,
  `nominal` mediumint(9) NOT NULL,
  `id_serial` tinyint(4) DEFAULT '0',
  PRIMARY KEY (`stock_ref_id`),
  KEY `ref_type_id` (`ref_type_id`),
  CONSTRAINT `stock_ref_ibfk_1` FOREIGN KEY (`ref_type_id`) REFERENCES `stock_ref_type` (`ref_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `stock_ref_type`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `stock_ref_type` (
  `ref_type_id` tinyint(3) unsigned NOT NULL,
  `ref_type_name` varchar(10) NOT NULL,
  PRIMARY KEY (`ref_type_id`),
  UNIQUE KEY `ref_type_name` (`ref_type_name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `summary_sale`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `summary_sale` (
  `summary_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `period_id` smallint(5) unsigned NOT NULL,
  `member_id` smallint(5) unsigned NOT NULL,
  `topup_summary` decimal(13,3) NOT NULL,
  `perdana_summary` decimal(13,3) NOT NULL,
  PRIMARY KEY (`summary_id`),
  UNIQUE KEY `member_period_id` (`period_id`,`member_id`),
  CONSTRAINT `summary_sale_ibfk_1` FOREIGN KEY (`period_id`) REFERENCES `target_period` (`period_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `target_period`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `target_period` (
  `period_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `from_date` date DEFAULT '0000-00-00',
  `until_date` date DEFAULT '0000-00-00',
  `period_status` enum('close','open') DEFAULT 'open',
  PRIMARY KEY (`period_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `topup`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `topup` (
  `topup_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `topup_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `trans_id` int(10) unsigned DEFAULT NULL,
  `credit` tinyint(3) unsigned NOT NULL,
  `payment_gateway` tinyint(3) unsigned NOT NULL,
  `token_sgo` varchar(35) DEFAULT NULL,
  `rs_id` smallint(5) unsigned DEFAULT NULL,
  `member_id` smallint(5) unsigned NOT NULL,
  `stock_ref_id` tinyint(3) unsigned DEFAULT NULL,
  `topup_qty` int(11) DEFAULT NULL,
  `topup_status` enum('','WA','WT','CT','D','W','P','S','F','R') NOT NULL DEFAULT '',
  `inv_id` mediumint(8) unsigned DEFAULT NULL,
  `error_msg` varchar(50) NOT NULL,
  `exec_ts` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `need_reply` tinyint(3) unsigned NOT NULL,
  `log_id` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`topup_id`),
  UNIQUE KEY `trans_id_2` (`trans_id`),
  KEY `rs_id` (`rs_id`),
  KEY `stock_ref_id` (`stock_ref_id`),
  KEY `need_reply` (`need_reply`),
  KEY `member_id` (`member_id`),
  KEY `topup_ts` (`topup_ts`),
  KEY `log_id` (`log_id`),
  KEY `inv_id` (`inv_id`),
  CONSTRAINT `topup_ibfk_1` FOREIGN KEY (`rs_id`) REFERENCES `rs_chip` (`rs_id`),
  CONSTRAINT `topup_ibfk_2` FOREIGN KEY (`stock_ref_id`) REFERENCES `stock_ref` (`stock_ref_id`),
  CONSTRAINT `topup_ibfk_3` FOREIGN KEY (`trans_id`) REFERENCES `transaction` (`trans_id`),
  CONSTRAINT `topup_ibfk_4` FOREIGN KEY (`member_id`) REFERENCES `member` (`member_id`),
  CONSTRAINT `topup_ibfk_5` FOREIGN KEY (`log_id`) REFERENCES `sd_log` (`log_id`),
  CONSTRAINT `topup_ibfk_6` FOREIGN KEY (`inv_id`) REFERENCES `invoice` (`inv_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='seperti approval queue: jk diapprove akan masuk ke trx';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `topup_request`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `topup_request` (
  `stock_ref_id` tinyint(3) unsigned NOT NULL,
  `rs_id` smallint(5) unsigned NOT NULL,
  `qty` mediumint(8) unsigned NOT NULL,
  `admin_id` tinyint(3) unsigned DEFAULT NULL,
  PRIMARY KEY (`stock_ref_id`,`rs_id`),
  KEY `topup_request_ibfk_2` (`rs_id`),
  KEY `admin_id` (`admin_id`),
  CONSTRAINT `topup_request_ibfk_1` FOREIGN KEY (`stock_ref_id`) REFERENCES `stock_ref` (`stock_ref_id`),
  CONSTRAINT `topup_request_ibfk_2` FOREIGN KEY (`rs_id`) REFERENCES `rs_chip` (`rs_id`),
  CONSTRAINT `topup_request_ibfk_3` FOREIGN KEY (`admin_id`) REFERENCES `admin` (`admin_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `topup_sms`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `topup_sms` (
  `topup_id` int(10) unsigned NOT NULL,
  `sms_id` mediumint(8) unsigned NOT NULL,
  `sequence` tinyint(3) unsigned NOT NULL DEFAULT '1',
  `dest_msisdn` varchar(15) NOT NULL,
  PRIMARY KEY (`topup_id`),
  KEY `sms_id` (`sms_id`),
  CONSTRAINT `topup_sms_ibfk_2` FOREIGN KEY (`sms_id`) REFERENCES `sms` (`sms_id`),
  CONSTRAINT `topup_sms_ibfk_3` FOREIGN KEY (`topup_id`) REFERENCES `topup` (`topup_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='topup via sms';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `topup_web`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `topup_web` (
  `topup_id` int(10) unsigned NOT NULL,
  `admin_log_id` mediumint(8) unsigned NOT NULL,
  PRIMARY KEY (`topup_id`),
  KEY `admin_log_id` (`admin_log_id`),
  CONSTRAINT `topup_web_ibfk_1` FOREIGN KEY (`admin_log_id`) REFERENCES `admin_log` (`admin_log_id`),
  CONSTRAINT `topup_web_ibfk_2` FOREIGN KEY (`topup_id`) REFERENCES `topup` (`topup_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `transaction`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `transaction` (
  `trans_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `trans_type` enum('dep','top','rev','tran','paid_cash','paid_bank') NOT NULL,
  `trans_date` date NOT NULL,
  `trans_time` time NOT NULL,
  `admin_id` tinyint(3) unsigned DEFAULT NULL,
  `trans_ref` int(10) unsigned DEFAULT NULL,
  `reversal_approve` enum('LOCK','LOCK_BEST','LOCK_TOTAL','NEED_APPROVE','APPROVE','') NOT NULL DEFAULT '',
  PRIMARY KEY (`trans_id`),
  KEY `admin_id` (`admin_id`),
  KEY `trans_ref` (`trans_ref`),
  KEY `trans_date` (`trans_date`,`trans_time`),
  KEY `trans_type` (`trans_type`),
  CONSTRAINT `transaction_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `admin` (`admin_id`),
  CONSTRAINT `transaction_ibfk_2` FOREIGN KEY (`trans_ref`) REFERENCES `transaction` (`trans_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `user`
--

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user` (
  `user_id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `member_id` smallint(5) unsigned DEFAULT NULL,
  `outlet_id` smallint(5) unsigned DEFAULT NULL,
  `username` varchar(15) NOT NULL,
  `pin` varchar(8) NOT NULL,
  `status` enum('Active','non-Active') DEFAULT NULL,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `username` (`username`),
  KEY `user_ibfk_1` (`member_id`),
  KEY `outlet_id` (`outlet_id`),
  CONSTRAINT `user_ibfk_1` FOREIGN KEY (`member_id`) REFERENCES `member` (`member_id`),
  CONSTRAINT `user_ibfk_2` FOREIGN KEY (`outlet_id`) REFERENCES `outlet` (`outlet_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2015-01-30 17:21:14
