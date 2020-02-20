-- MySQL dump 10.13  Distrib 5.1.47, for redhat-linux-gnu (x86_64)
--
-- Host: localhost    Database: sds
-- ------------------------------------------------------
-- Server version	5.1.47-log
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Dumping data for table `admin`
--

INSERT INTO `admin` VALUES (1,'admin','5f4dcc3b5aa765d61d8327deb882cf99','c23cb23e-542b-46eb-b811-a7f7ea04c4e9','2011-02-09 05:06:45',1,1,NULL,NULL);

--
-- Dumping data for table `admin_group`
--

INSERT INTO `admin_group` VALUES (1,'best-admin');
INSERT INTO `admin_group` VALUES (2,'accounting');
INSERT INTO `admin_group` VALUES (3,'cs');
INSERT INTO `admin_group` VALUES (4,'branch-office');

--
-- Dumping data for table `config`
--

INSERT INTO `config` VALUES (2,'max topup amount',500000);
INSERT INTO `config` VALUES (3,'dompul discount for server',4);
INSERT INTO `config` VALUES (4,'dompul discount for retailer',3);
INSERT INTO `config` VALUES (5,'repeated sms interval',4);
INSERT INTO `config` VALUES (6,'trx brake interval',30);

--
-- Dumping data for table `member`
--

INSERT INTO `member` VALUES (1,NULL,'system owner',0.000,1,'Active','CVS',0.000,NULL);

--
-- Dumping data for table `mutation`
--


--
-- Dumping data for table `outlet`
--

--
-- Dumping data for table `outlet_type`
--

INSERT INTO `outlet_type` VALUES (1,'cash',0);

--
-- Dumping data for table `page`
--

INSERT INTO `page` VALUES (1,'/view/admin/add_admin','add admin for member');
INSERT INTO `page` VALUES (2,'/view/admin/edit_admin','edit admin for member');
INSERT INTO `page` VALUES (3,'/view/admin/list','list admin of member');
INSERT INTO `page` VALUES (4,'/view/general/setting',NULL);
INSERT INTO `page` VALUES (5,'/view/transaction/new_deposit','deposit for canvaser');
INSERT INTO `page` VALUES (6,'/modify/transaction/deposit','deposit for canvaser');
INSERT INTO `page` VALUES (7,'/modify/transaction/inject','isi chip stock rs number');
INSERT INTO `page` VALUES (8,'/view/transaction/new_topup','isi chip stock rs number');
INSERT INTO `page` VALUES (9,'/view/transaction/list','topup list');
INSERT INTO `page` VALUES (10,'/view/transaction/double_list','topup list dg keyword double');
INSERT INTO `page` VALUES (11,'/view/transaction/dep_list','member deposit list');
INSERT INTO `page` VALUES (12,'/view/transaction/topup_report','report mutasi per keyword');
INSERT INTO `page` VALUES (13,'/view/topup/topup_upload','topup dari file.csv');
INSERT INTO `page` VALUES (14,'/view/topup/edit_topup','edit topup request dari upload file.csv');
INSERT INTO `page` VALUES (15,'/modify/topup/edit_topup_request','edit topup request dari upload file.csv');
INSERT INTO `page` VALUES (16,'/modify/topup/inject_topup_request','edit topup request dari upload file.csv,inject');
INSERT INTO `page` VALUES (17,'/modify/topup/inject_all_topup_request','edit topup request dari upload file.csv,inject all');
INSERT INTO `page` VALUES (18,'/modify/topup/topup_upload','topup dari file.csv');
INSERT INTO `page` VALUES (19,'/view/transaction/lock_totalan','lock total super user');
INSERT INTO `page` VALUES (20,'/modify/transaction/lock_totalan','lock total super user');
INSERT INTO `page` VALUES (21,'/view/member/list','list member');
INSERT INTO `page` VALUES (22,'/modify/member/set_status','list member active/non active all');
INSERT INTO `page` VALUES (23,'/modify/member/change_status_member','list member active/non active per member');
INSERT INTO `page` VALUES (24,'/modify/member/delete','delete list member');
INSERT INTO `page` VALUES (25,'/view/member/add_member','add member');
INSERT INTO `page` VALUES (26,'/modify/member/add_member','add member');
INSERT INTO `page` VALUES (27,'/view/member/edit_member','edit member');
INSERT INTO `page` VALUES (28,'/modify/member/edit_member','edit member');
INSERT INTO `page` VALUES (29,'/view/member/mutation','member balance mutation');
INSERT INTO `page` VALUES (30,'/view/member/detail_member','detail member');
INSERT INTO `page` VALUES (31,'/modify/member/delete_username','detail member (delete username)');
INSERT INTO `page` VALUES (32,'/modify/member/ubah_status','detail member (ubah status username)');
INSERT INTO `page` VALUES (33,'/modify/member/add_username','detail member (add username)');
INSERT INTO `page` VALUES (34,'/modify/rs_chip/delete_member_id','detail member (delete rs_chip id)');
INSERT INTO `page` VALUES (35,'/modify/rs_chip/add_member_id','detail member (add rs_chip id)');
INSERT INTO `page` VALUES (36,'/modify/admin/delete','delete admin for member');
INSERT INTO `page` VALUES (37,'/modify/admin/edit_admin','edit admin for member');
INSERT INTO `page` VALUES (38,'/modify/admin/add_admin','add admin for member');
INSERT INTO `page` VALUES (39,'/view/outlet/list','list outlet');
INSERT INTO `page` VALUES (40,'/modify/outlet/delete','delete outlet');
INSERT INTO `page` VALUES (41,'/view/outlet/view_outlet','info outlet');
INSERT INTO `page` VALUES (42,'/view/outlet/add_outlet','add outlet');
INSERT INTO `page` VALUES (43,'/modify/outlet/add_outlet','add outlet');
INSERT INTO `page` VALUES (44,'/view/outlet/edit_outlet','edit outlet');
INSERT INTO `page` VALUES (45,'/modify/outlet/edit_outlet','edit outlet');
INSERT INTO `page` VALUES (46,'/view/stock/list','list sub master for owner');
INSERT INTO `page` VALUES (47,'/modify/stock/delete','delete list sub master for owner');
INSERT INTO `page` VALUES (48,'/view/stock/add_stock_sd_chip','add sub master for owner (stock_sd_chip)');
INSERT INTO `page` VALUES (49,'/modify/stock/add_stock_sd_chip','add sub master for owner (stock_sd_chip)');
INSERT INTO `page` VALUES (50,'/view/stock/edit_stock_sd_chip','edit sub master for owner (stock_sd_chip)');
INSERT INTO `page` VALUES (51,'/modify/stock/edit_stock_sd_chip','edit sub master for owner (stock_sd_chip)');
INSERT INTO `page` VALUES (52,'/view/stock/detail_stock_sd_chip','stock detail from sub master');
INSERT INTO `page` VALUES (53,'/modify/stock/add_sd_stock','add stock from sub master (sd_stock)');
INSERT INTO `page` VALUES (54,'/modify/stock/delete_sd_stock','delete stock from sub master (sd_stock)');
INSERT INTO `page` VALUES (55,'/view/stock/edit_sd_stock','edit stock from sub master (sd_stock)');
INSERT INTO `page` VALUES (56,'/modify/stock/edit_sd_stock','edit stock from sub master (sd_stock)');
INSERT INTO `page` VALUES (57,'/modify/stock/change_status_rs','ubah status RO/RS from sub master');
INSERT INTO `page` VALUES (58,'/modify/stock/delete_rs_chip','delete RO/RS from sub master');
INSERT INTO `page` VALUES (59,'/modify/stock/add_rs_chip','add RO/RS from sub master');
INSERT INTO `page` VALUES (60,'/view/stock/edit_rs_chip','edit RO/RS from sub master');
INSERT INTO `page` VALUES (61,'/modify/stock/edit_rs_chip','edit RO/RS from sub master');
INSERT INTO `page` VALUES (62,'/view/stock/stock_mutation','list stock mutation');
INSERT INTO `page` VALUES (63,'/view/stock/edit_price','list pricing');
INSERT INTO `page` VALUES (64,'/view/stock/edit_for_approve','edit pricing');
INSERT INTO `page` VALUES (65,'/modify/stock/edit_for_approve','edit pricing');
INSERT INTO `page` VALUES (66,'/view/stock/approve_price','pricing approval');
INSERT INTO `page` VALUES (67,'/modify/stock/approve_price','pricing approval');
INSERT INTO `page` VALUES (68,'/view/stock/price_type','list type price');
INSERT INTO `page` VALUES (69,'/modify/stock/delete_price_type','delete list type price');
INSERT INTO `page` VALUES (70,'/view/stock/add_price_type','add list type price');
INSERT INTO `page` VALUES (71,'/modify/stock/add_price_type','add list type price');
INSERT INTO `page` VALUES (72,'/view/stock/edit_price_type','edit list type price');
INSERT INTO `page` VALUES (73,'/modify/stock/edit_price_type','edit list type price');
INSERT INTO `page` VALUES (74,'/view/stock/list_site','site list');
INSERT INTO `page` VALUES (75,'/view/stock/edit_site','edit site list');
INSERT INTO `page` VALUES (76,'/modify/stock/edit_site','edit site list');
INSERT INTO `page` VALUES (77,'/modify/stock/delete_site','delete site list');
INSERT INTO `page` VALUES (78,'/view/stock/list_stock_ref','list product');
INSERT INTO `page` VALUES (79,'/modify/stock/delete_stock_ref','delete list product');
INSERT INTO `page` VALUES (80,'/view/stock/add_stock_ref','add list product');
INSERT INTO `page` VALUES (81,'/modify/stock/add_stock_ref','add list product');
INSERT INTO `page` VALUES (82,'/view/stock/edit_stock_ref','edit list product');
INSERT INTO `page` VALUES (83,'/modify/stock/edit_stock_ref','edit list product');
INSERT INTO `page` VALUES (84,'/view/stock/list_package','list package');
INSERT INTO `page` VALUES (85,'/modify/stock/delete_list_package','delete list package');
INSERT INTO `page` VALUES (86,'/view/stock/add_pkg','add list package');
INSERT INTO `page` VALUES (87,'/modify/stock/add_pkg','add list package');
INSERT INTO `page` VALUES (88,'/view/stock/edit_list_package','edit list package');
INSERT INTO `page` VALUES (89,'/modify/stock/edit_list_package','edit list package');
INSERT INTO `page` VALUES (90,'/view/stock/dtl_pkg','detail list package');
INSERT INTO `page` VALUES (91,'/modify/stock/delete_detail_package','delete detail list package');
INSERT INTO `page` VALUES (92,'/modify/stock/add_dtl_pkg','add detail list package');
INSERT INTO `page` VALUES (93,'/view/stock/edit_detail_package','edit detail list package (edit detail product)');
INSERT INTO `page` VALUES (94,'/modify/stock/edit_detail_package','edit detail list package (edit detail product)');
INSERT INTO `page` VALUES (95,'/view/sms/list','list sms');
INSERT INTO `page` VALUES (96,'/view/smsc/list','list smsc');
INSERT INTO `page` VALUES (97,'/modify/smsc/delete','delete list smsc');
INSERT INTO `page` VALUES (98,'/view/smsc/add_smsc','add list smsc');
INSERT INTO `page` VALUES (99,'/modify/smsc/add_smsc','add list smsc');
INSERT INTO `page` VALUES (100,'/view/smsc/edit_smsc','edit list smsc');
INSERT INTO `page` VALUES (101,'/modify/smsc/edit_smsc','edit list smsc');
INSERT INTO `page` VALUES (102,'/view/sms_rs/list','list sms rs');
INSERT INTO `page` VALUES (103,'/view/admin/edit_admin_page','edit group admin for limited page');
INSERT INTO `page` VALUES (104,'/modify/admin/edit_admin_page','edit group admin for limited page');
INSERT INTO `page` VALUES (105,'/view/admin/edit_password','edit password');
INSERT INTO `page` VALUES (106,'/modify/admin/edit_password','edit password');
INSERT INTO `page` VALUES (107,'/view/sms/detail_report','reply sms manual');
INSERT INTO `page` VALUES (108,'/modify/sms/send_answer','reply sms manual');
INSERT INTO `page` VALUES (109,'/view/transaction/detail','transaction detail');
INSERT INTO `page` VALUES (110,'/modify/transaction/reversal','transaction list (reversal)');
INSERT INTO `page` VALUES (111,'/modify/transaction/reversal_uniq','transaction list (reversal_uniq)');
INSERT INTO `page` VALUES (112,'/modify/transaction/lock_reversal','transaction list (reversal approve)');
INSERT INTO `page` VALUES (113,'/view/aktivasi/list','list aktivasi');
INSERT INTO `page` VALUES (114,'/view/aktivasi/form','form untuk aktivasi calon rs');
INSERT INTO `page` VALUES (115,'/modify/smsc/change_status','change status smsc');
INSERT INTO `page` VALUES (116,'/modify/transaction/approve','approve transaction');
INSERT INTO `page` VALUES (117,'/modify/stock/edit_price','edit price');
INSERT INTO `page` VALUES (118,'/view/outlet/outlet_type','outlet type price');
INSERT INTO `page` VALUES (119,'/modify/outlet/outlet_type','action outlet type price');
INSERT INTO `page` VALUES (120,'/view/outlet/edit_outlet_type','edit outlet type');
INSERT INTO `page` VALUES (121,'/modify/outlet/edit_outlet_type','action edit outlet type');
INSERT INTO `page` VALUES (122,'/view/transaction/new_transfer','add transfer');
INSERT INTO `page` VALUES (123,'/modify/transaction/transfer','action add transfer');
INSERT INTO `page` VALUES (124,'/view/stock/approve_stock','approve stock');
INSERT INTO `page` VALUES (125,'/modify/stock/approve_stock','action approve stock');
INSERT INTO `page` VALUES (126,'/view/stock/total_stock','total stock');
INSERT INTO `page` VALUES (127,'/modify/stock/approve_manager','add stock for approve manager');
INSERT INTO `page` VALUES (128,'/modify/stock/add_quota','add quota stock');
INSERT INTO `page` VALUES (129,'/view/outlet/mutation','outlet mutation');
INSERT INTO `page` VALUES (130,'/view/invoice/list','list invoice');
INSERT INTO `page` VALUES (131,'/view/invoice/invoice_due','invoice due');
INSERT INTO `page` VALUES (132,'/view/invoice/print','invoice print');
INSERT INTO `page` VALUES (133,'/modify/invoice/paid','action for paid');
INSERT INTO `page` VALUES (134,'/view/invoice/invoice_payment','payment of invoice');
INSERT INTO `page` VALUES (135,'/view/invoice/invoice_report','total invoice');
INSERT INTO `page` VALUES (136,'/view/invoice/cash_receipt','cash receipt');
INSERT INTO `page` VALUES (137,'/view/invoice/bank_receipt','bank receipt');
INSERT INTO `page` VALUES (138,'/view/invoice/financial_report','financial report');
INSERT INTO `page` VALUES (139,'/modify/topup/delete_upload','delete upload');
INSERT INTO `page` VALUES (140,'/modify/invoice/change_payment','change payment type');
INSERT INTO `page` VALUES (141,'/view/invoice/note_payment','note invoice payment');
INSERT INTO `page` VALUES (142,'/modify/invoice/note_payment','action note invoice payment');
INSERT INTO `page` VALUES (143,'/view/outlet/detail_rs','quota rs');
INSERT INTO `page` VALUES (144,'/modify/outlet/add_quota_outlet','action: add quota outlet');
INSERT INTO `page` VALUES (145,'/modify/outlet/add_quota_rs','action: add quota rs chip');
INSERT INTO `page` VALUES (146,'/modify/outlet/serial','action to id serial');
INSERT INTO `page` VALUES (148,'/view/topup/perdana_upload','upload perdana');
INSERT INTO `page` VALUES (149,'/modify/topup/perdana_upload','modify upload perdana');
INSERT INTO `page` VALUES (150,'/view/setting/admin_log','Admin Log');
INSERT INTO `page` VALUES (151,'/view/setting/reg_list','list perdana');
INSERT INTO `page` VALUES (152,'/view/setting/reg_command','setting command reg');
INSERT INTO `page` VALUES (153,'/modify/setting/reg_command','modify reg command');
INSERT INTO `page` VALUES (154,'/modify/setting/modem','modify status modem');
INSERT INTO `page` VALUES (155,'/modify/member/upload_target','upload target canvasser');
INSERT INTO `page` VALUES (156,'/view/topup/topup_rank','topup rangking');
INSERT INTO `page` VALUES (157,'/view/member/detail_target','list target member');
INSERT INTO `page` VALUES (158,'/view/member/additional_list','list additional user');
INSERT INTO `page` VALUES (159,'/modify/member/edit_status_additional','edit status additional user');
INSERT INTO `page` VALUES (160,'/modify/member/update_additional_user','add additional user');
INSERT INTO `page` VALUES (161,'/view/member/set_target_period','set target epriod');
INSERT INTO `page` VALUES (162,'/modify/member/set_target_period','action :set target period');
INSERT INTO `page` VALUES (163,'/view/transaction/voucher_list','voucher dompul list');
INSERT INTO `page` VALUES (164,'/modify/smsc/change_type','change smsc type');

--
-- Dumping data for table `page_map`
--

INSERT INTO `page_map` VALUES (1,1);
INSERT INTO `page_map` VALUES (1,2);
INSERT INTO `page_map` VALUES (1,3);
INSERT INTO `page_map` VALUES (1,5);
INSERT INTO `page_map` VALUES (1,6);
INSERT INTO `page_map` VALUES (1,7);
INSERT INTO `page_map` VALUES (1,8);
INSERT INTO `page_map` VALUES (1,9);
INSERT INTO `page_map` VALUES (1,10);
INSERT INTO `page_map` VALUES (1,11);
INSERT INTO `page_map` VALUES (1,12);
INSERT INTO `page_map` VALUES (1,13);
INSERT INTO `page_map` VALUES (1,14);
INSERT INTO `page_map` VALUES (1,15);
INSERT INTO `page_map` VALUES (1,16);
INSERT INTO `page_map` VALUES (1,17);
INSERT INTO `page_map` VALUES (1,18);
INSERT INTO `page_map` VALUES (1,19);
INSERT INTO `page_map` VALUES (1,20);
INSERT INTO `page_map` VALUES (1,21);
INSERT INTO `page_map` VALUES (1,22);
INSERT INTO `page_map` VALUES (1,23);
INSERT INTO `page_map` VALUES (1,24);
INSERT INTO `page_map` VALUES (1,25);
INSERT INTO `page_map` VALUES (1,26);
INSERT INTO `page_map` VALUES (1,27);
INSERT INTO `page_map` VALUES (1,28);
INSERT INTO `page_map` VALUES (1,29);
INSERT INTO `page_map` VALUES (1,30);
INSERT INTO `page_map` VALUES (1,31);
INSERT INTO `page_map` VALUES (1,32);
INSERT INTO `page_map` VALUES (1,33);
INSERT INTO `page_map` VALUES (1,34);
INSERT INTO `page_map` VALUES (1,35);
INSERT INTO `page_map` VALUES (1,36);
INSERT INTO `page_map` VALUES (1,37);
INSERT INTO `page_map` VALUES (1,38);
INSERT INTO `page_map` VALUES (1,39);
INSERT INTO `page_map` VALUES (1,40);
INSERT INTO `page_map` VALUES (1,41);
INSERT INTO `page_map` VALUES (1,42);
INSERT INTO `page_map` VALUES (1,43);
INSERT INTO `page_map` VALUES (1,44);
INSERT INTO `page_map` VALUES (1,45);
INSERT INTO `page_map` VALUES (1,46);
INSERT INTO `page_map` VALUES (1,47);
INSERT INTO `page_map` VALUES (1,48);
INSERT INTO `page_map` VALUES (1,49);
INSERT INTO `page_map` VALUES (1,50);
INSERT INTO `page_map` VALUES (1,51);
INSERT INTO `page_map` VALUES (1,52);
INSERT INTO `page_map` VALUES (1,53);
INSERT INTO `page_map` VALUES (1,54);
INSERT INTO `page_map` VALUES (1,55);
INSERT INTO `page_map` VALUES (1,56);
INSERT INTO `page_map` VALUES (1,57);
INSERT INTO `page_map` VALUES (1,58);
INSERT INTO `page_map` VALUES (1,59);
INSERT INTO `page_map` VALUES (1,60);
INSERT INTO `page_map` VALUES (1,61);
INSERT INTO `page_map` VALUES (1,62);
INSERT INTO `page_map` VALUES (1,63);
INSERT INTO `page_map` VALUES (1,64);
INSERT INTO `page_map` VALUES (1,65);
INSERT INTO `page_map` VALUES (1,66);
INSERT INTO `page_map` VALUES (1,67);
INSERT INTO `page_map` VALUES (1,68);
INSERT INTO `page_map` VALUES (1,69);
INSERT INTO `page_map` VALUES (1,70);
INSERT INTO `page_map` VALUES (1,71);
INSERT INTO `page_map` VALUES (1,72);
INSERT INTO `page_map` VALUES (1,73);
INSERT INTO `page_map` VALUES (1,74);
INSERT INTO `page_map` VALUES (1,75);
INSERT INTO `page_map` VALUES (1,76);
INSERT INTO `page_map` VALUES (1,77);
INSERT INTO `page_map` VALUES (1,78);
INSERT INTO `page_map` VALUES (1,79);
INSERT INTO `page_map` VALUES (1,80);
INSERT INTO `page_map` VALUES (1,81);
INSERT INTO `page_map` VALUES (1,82);
INSERT INTO `page_map` VALUES (1,83);
INSERT INTO `page_map` VALUES (1,84);
INSERT INTO `page_map` VALUES (1,85);
INSERT INTO `page_map` VALUES (1,86);
INSERT INTO `page_map` VALUES (1,87);
INSERT INTO `page_map` VALUES (1,88);
INSERT INTO `page_map` VALUES (1,89);
INSERT INTO `page_map` VALUES (1,90);
INSERT INTO `page_map` VALUES (1,91);
INSERT INTO `page_map` VALUES (1,92);
INSERT INTO `page_map` VALUES (1,93);
INSERT INTO `page_map` VALUES (1,94);
INSERT INTO `page_map` VALUES (1,95);
INSERT INTO `page_map` VALUES (1,96);
INSERT INTO `page_map` VALUES (1,97);
INSERT INTO `page_map` VALUES (1,98);
INSERT INTO `page_map` VALUES (1,99);
INSERT INTO `page_map` VALUES (1,100);
INSERT INTO `page_map` VALUES (1,101);
INSERT INTO `page_map` VALUES (1,102);
INSERT INTO `page_map` VALUES (1,103);
INSERT INTO `page_map` VALUES (1,104);
INSERT INTO `page_map` VALUES (1,105);
INSERT INTO `page_map` VALUES (1,106);
INSERT INTO `page_map` VALUES (1,107);
INSERT INTO `page_map` VALUES (1,108);
INSERT INTO `page_map` VALUES (1,109);
INSERT INTO `page_map` VALUES (1,110);
INSERT INTO `page_map` VALUES (1,111);
INSERT INTO `page_map` VALUES (1,112);
INSERT INTO `page_map` VALUES (1,115);
INSERT INTO `page_map` VALUES (1,116);
INSERT INTO `page_map` VALUES (1,117);
INSERT INTO `page_map` VALUES (1,118);
INSERT INTO `page_map` VALUES (1,119);
INSERT INTO `page_map` VALUES (1,120);
INSERT INTO `page_map` VALUES (1,121);
INSERT INTO `page_map` VALUES (1,122);
INSERT INTO `page_map` VALUES (1,123);
INSERT INTO `page_map` VALUES (1,124);
INSERT INTO `page_map` VALUES (1,125);
INSERT INTO `page_map` VALUES (1,126);
INSERT INTO `page_map` VALUES (1,127);
INSERT INTO `page_map` VALUES (1,128);
INSERT INTO `page_map` VALUES (1,129);
INSERT INTO `page_map` VALUES (1,130);
INSERT INTO `page_map` VALUES (1,131);
INSERT INTO `page_map` VALUES (1,132);
INSERT INTO `page_map` VALUES (1,133);
INSERT INTO `page_map` VALUES (1,134);
INSERT INTO `page_map` VALUES (1,135);
INSERT INTO `page_map` VALUES (1,136);
INSERT INTO `page_map` VALUES (1,137);
INSERT INTO `page_map` VALUES (1,138);
INSERT INTO `page_map` VALUES (1,139);
INSERT INTO `page_map` VALUES (1,140);
INSERT INTO `page_map` VALUES (1,141);
INSERT INTO `page_map` VALUES (1,142);
INSERT INTO `page_map` VALUES (1,143);
INSERT INTO `page_map` VALUES (1,144);
INSERT INTO `page_map` VALUES (1,145);
INSERT INTO `page_map` VALUES (1,148);
INSERT INTO `page_map` VALUES (1,149);
INSERT INTO `page_map` VALUES (1,150);
INSERT INTO `page_map` VALUES (1,151);
INSERT INTO `page_map` VALUES (1,152);
INSERT INTO `page_map` VALUES (1,153);
INSERT INTO `page_map` VALUES (1,154);
INSERT INTO `page_map` VALUES (1,155);
INSERT INTO `page_map` VALUES (1,156);
INSERT INTO `page_map` VALUES (1,157);
INSERT INTO `page_map` VALUES (1,158);
INSERT INTO `page_map` VALUES (1,159);
INSERT INTO `page_map` VALUES (1,160);
INSERT INTO `page_map` VALUES (1,161);
INSERT INTO `page_map` VALUES (1,162);
INSERT INTO `page_map` VALUES (1,163);
INSERT INTO `page_map` VALUES (1,164);

--
-- Dumping data for table `pricing`
--

INSERT INTO `pricing` VALUES (10,1,4000,'OLD',NULL);
INSERT INTO `pricing` VALUES (10,2,5000,'OLD',NULL);
INSERT INTO `pricing` VALUES (12,1,4900,'OLD',NULL);
INSERT INTO `pricing` VALUES (12,2,5000,'OLD',NULL);
INSERT INTO `pricing` VALUES (13,1,10000,'OLD',NULL);
INSERT INTO `pricing` VALUES (13,2,11000,'OLD',NULL);
INSERT INTO `pricing` VALUES (14,1,20000,'OLD',NULL);
INSERT INTO `pricing` VALUES (14,2,21000,'OLD',NULL);
INSERT INTO `pricing` VALUES (15,1,5000,'OLD',NULL);
INSERT INTO `pricing` VALUES (15,2,5100,'OLD',NULL);
INSERT INTO `pricing` VALUES (16,1,50000,'OLD',NULL);
INSERT INTO `pricing` VALUES (16,2,51000,'OLD',NULL);

--
-- Dumping data for table `rs_chip`
--


--
-- Dumping data for table `rs_stock`
--


--
-- Dumping data for table `rs_type`
--

INSERT INTO `rs_type` VALUES (1,'Server');
INSERT INTO `rs_type` VALUES (2,'Retailer');
INSERT INTO `rs_type` VALUES (4,'Retailer-1');
INSERT INTO `rs_type` VALUES (5,'Reseler');

--
-- Dumping data for table `sd_chip`
--


--
-- Dumping data for table `sd_stock`
--


--
-- Dumping data for table `site`
--

INSERT INTO `site` VALUES (1,'jakarta','http://127.0.0.1:59194/service');

--
-- Dumping data for table `sms`
--


--
-- Dumping data for table `smsc`
--

INSERT INTO `smsc` VALUES (1,'im3-center','center','active',1);
INSERT INTO `smsc` VALUES (2,'xl-center','sender','active',1);

--
-- Dumping data for table `stock_ref`
--

INSERT INTO `stock_ref` VALUES (1,'XL 1','X1',1,NULL,100,1000,0);
INSERT INTO `stock_ref` VALUES (2,'XL 5','X5',1,NULL,100,5000,0);
INSERT INTO `stock_ref` VALUES (3,'XL 10','X10',1,NULL,100,10000,0);
INSERT INTO `stock_ref` VALUES (4,'XL Nominal','XLN',1,NULL,100,0,0);
INSERT INTO `stock_ref` VALUES (11,'As 25000','A25',2,NULL,100,25000,0);
INSERT INTO `stock_ref` VALUES (12,'Simpati 5000','S5',2,NULL,100,5000,0);
INSERT INTO `stock_ref` VALUES (13,'Simpati 10000','S10',2,NULL,100,10000,0);
INSERT INTO `stock_ref` VALUES (14,'Simpati 20000','S20',2,NULL,100,20000,0);
INSERT INTO `stock_ref` VALUES (15,'As 5000','A5',2,NULL,100,5000,0);
INSERT INTO `stock_ref` VALUES (16,'Simpati 50000','S50',2,NULL,100,50000,0);
INSERT INTO `stock_ref` VALUES (17, 'THREE 2GB','T2',5,NULL,1000,75000,0);
INSERT INTO `stock_ref` VALUES (18, 'THREE 5GB','T5',5,NULL,1000,125000,0);
INSERT INTO `stock_ref` VALUES (19, 'THREE 500GB','T500',5,NULL,1000,35000,0);
INSERT INTO `stock_ref` VALUES (20, 'Saldo Three','THR',5,NULL,10000000,0,0);
INSERT INTO `stock_ref` VALUES (21, 'Evo Transfer','T',9,NULL,10000000,0,0);

--
-- Dumping data for table `stock_ref_type`
--

INSERT INTO `stock_ref_type` VALUES (1,'Dompul');
INSERT INTO `stock_ref_type` VALUES (2,'MKios');
INSERT INTO `stock_ref_type` VALUES (3,'SEV');
INSERT INTO `stock_ref_type` VALUES (4,'Esia');
INSERT INTO `stock_ref_type` VALUES (5,'Three');
INSERT INTO `stock_ref_type` VALUES (6,'Smart');
INSERT INTO `stock_ref_type` VALUES (7,'Flexi');
INSERT INTO `stock_ref_type` VALUES (8,'AXIS');
INSERT INTO `stock_ref_type` VALUES (9,'Evo Transfer');

--
-- Dumping data for table `topup`
--


--
-- Dumping data for table `transaction`
--


--
-- Dumping data for table `user`
--

INSERT INTO `user` VALUES (1,1,NULL,'5Y5T3M','Qx0rt@!m','Active');

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2011-03-04 16:39:25
