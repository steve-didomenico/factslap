DROP TABLE IF EXISTS `linkbynumber`;
DROP TABLE IF EXISTS `linkbyname`;

/* This first table contains the links that the user has chosen to let the sytsem create. */
/* We use a separate table because it helps keep track of the numbers */
CREATE TABLE `linkbynumber` (
  `lbn_id` int(11) NOT NULL auto_increment,
  `url` varchar(4096) default NULL,
  `modified_time` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `expires_time` datetime default NULL,
  `created_by` varchar(256) NOT NULL,
  `ip_address` varchar(256) NOT NULL,
  PRIMARY KEY  (`lbn_id`)
);

/* This second table contains links that the user has chosen the name for. */
/* We will also put the "number" links in this table to make sure the system */
/* only look at one table to provide redirection */
CREATE TABLE `linkbyname` (
  `shortname` varchar(250) NOT NULL,
  `url` varchar(4096) default NULL,
  `modified_time` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `expires_time` datetime default NULL,
  `created_by` varchar(256) NOT NULL,
  `is_active` int(1) NOT NULL default '1',
  `ip_address` varchar(256) NOT NULL,
  PRIMARY KEY  (`shortname`)
);


  