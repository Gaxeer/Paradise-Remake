/datum/mind/proc/clear_antag_datum(datum/antagonist/antag_datum_to_clear)
	if(!has_antag_datum(antag_datum_to_clear))
		return

	remove_antag_datum(antag_datum_to_clear)
	var/antag_name = initial(antag_datum_to_clear.name)
	log_admin("[key_name(usr)] has removed <b>[antag_name]</b> from [key_name(current)]")
	message_admins("[key_name_admin(usr)] has removed <b>[antag_name]</b> from [key_name_admin(current)]")


/datum/mind/Topic(href, href_list)
	if(!check_rights(R_ADMIN))
		return

	if(href_list["blood_brother"])
		switch(href_list["blood_brother"])
			if("clear")
				clear_antag_datum(/datum/antagonist/blood_brother)
			if("make")
				var/datum/antagonist/blood_brother/brother_antag_datum = new
				if(!brother_antag_datum.admin_add(usr, src))
					qdel(brother_antag_datum)

	. = ..()
