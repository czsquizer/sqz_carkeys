ALTER TABLE `owned_vehicles`
	ADD COLUMN `peopleWithKeys` LONGTEXT NULL DEFAULT '[]';

	-- IF you got errors while executing the query above, use the one bellow
ALTER TABLE `owned_vehicles`
	ADD COLUMN `peopleWithKeys` LONGTEXT NULL;