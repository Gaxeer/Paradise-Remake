/datum/game_mode/raginmages
	name = "ragin' mages"
	config_tag = "raginmages"
	required_players = 20
	required_enemies = 1
	recommended_enemies = 1

	/// List of candidates for first wizard role
	var/list/pre_wizards = list()
	/// Number of mages made by this game mode. Admin spawned ones don't count
	var/mages_made = 0
	/// The max number of mages that could be spawned by this gamemode
	var/mages_cap = 0
	/// When this time comes - mode will spawn new wizard each `delay_per_mage`, ignoring the presence of alive wizards
	var/time_till_chaos = 30 MINUTES
	/// If the chaos has started. Set to `TRUE` after `time_till_chaos`. Check `time_till_chaos` for detailed info
	var/chaos_started = FALSE
	/// If currently we are in process of making another mage, which takes some time for polling ghosts
	var/making_mage = FALSE
	/// Amount of players required per each wizard. The `mages_cap` is calculated based on this value and is rounded up
	var/players_per_mage = 10
	/// The time between each attempt to spawn new wizard
	var/delay_per_mage = 7 MINUTES
	/// If the ghost poll for new wizard has failed, we will try again after this time
	var/wizard_poll_failed_retry_time = 30 SECONDS

/datum/game_mode/raginmages/announce()
	to_chat(world, "<B>The current game mode is - Ragin' Mages!</B>")
	to_chat(world, "<B>The <font color='red'>Space Wizard Federation</font> is pissed, crew must help defeat all the Space Wizards invading the station!</B>")

/datum/game_mode/raginmages/declare_completion()
	SSticker.mode_result = "raging wizard loss - wizard killed"
	to_chat(world, "<span class='warning'><font size = 3><b>The crew has managed to hold off the Wizard attack! The Space Wizard Federation has been taught a lesson they will not soon forget!</b></font></span>")
	..()
	return TRUE

/datum/game_mode/raginmages/can_start()
	if(!length(GLOB.wizardstart))
		error("No wizard start locations were prepared. Please report this bug.")
		return FALSE

	return ..()

/datum/game_mode/raginmages/pre_setup()
	pre_wizards = get_players_for_role(ROLE_WIZARD)
	return length(pre_wizards)

/datum/game_mode/post_setup()
	mages_cap = calculate_mages_cap()
	fill_magivends()
	make_first_mage()
	. = ..()

/datum/game_mode/raginmages/check_finished()
	return ..() || (!length(count_alive_wizards()) && mages_cap <= mages_made)

/datum/game_mode/raginmages/proc/make_first_mage()
	if(length(pre_wizards))
		var/datum/mind/first_wizard = pick(pre_wizards)
		first_wizard.add_antag_datum(/datum/antagonist/wizard)
		mages_made++

	if(mages_cap <= mages_made)
		try_make_another_mage_in(delay_per_mage)

/datum/game_mode/raginmages/proc/calculate_mages_cap()
	return CEILING((count_humans_with_client() / players_per_mage), 1)

/datum/game_mode/raginmages/proc/fill_magivends()
	for(var/obj/machinery/economy/vending/magivend/magic in GLOB.machines)
		for(var/product_path in magic.products)
			magic.products[product_path] = 20 // and so, there was prosperity for ragin mages everywhere
		magic.product_records.Cut()
		magic.build_inventory(magic.products, magic.product_records)

/datum/game_mode/raginmages/proc/squabble_helper(datum/mind/wizard)
	var/area/wizard_station/wizard_area = get_area(wizard.current)
	if(!istype(wizard_area))
		return FALSE

	// We don't want people camping other wizards
	to_chat(wizard.current, "<span class='warning'>If there aren't any admins on and another wizard is camping you in the wizard lair, report them on the forums.</span>")
	message_admins("[wizard.current] died in the wizard lair, another wizard is likely camping")
	end_squabble(wizard_area)
	return TRUE

// To silence all struggles within the wizard's lair
/datum/game_mode/raginmages/proc/end_squabble(area/wizard_station/wizard_station_area)
	if(!istype(wizard_station_area))
		return // You could probably do mean things with this otherwise

	var/list/marked_for_death = list()
	for(var/mob/living/L in wizard_station_area) // To hit non-wizard griefers
		if(L.mind || L.client)
			marked_for_death |= L

	for(var/datum/mind/M in wizards)
		if(istype(M.current) && istype(get_area(M.current), /area/wizard_station))
			mages_made -= 1
			wizards -= M // No, you don't get to occupy a slot
			marked_for_death |= M.current

	for(var/mob/living/to_kill in marked_for_death)
		if(to_kill.stat == CONSCIOUS) // Probably a troublemaker - I'd like to see YOU fight when unconscious
			to_chat(L, "<span class='userdanger'>STOP FIGHTING.</span>")

		to_kill.ghostize()

		if(isbrain(to_kill))
			// diediedie
			var/mob/living/carbon/brain/brain_to_kill = to_kill
			if(isitem(brain_to_kill.loc))
				qdel(brain_to_kill.loc)

			if(brain_to_kill?.container)
				qdel(brain_to_kill.container)

		if(to_kill)
			qdel(to_kill)

	for(var/obj/item/spellbook/spellbook_to_del in wizard_station_area)
		// No goodies for you
		qdel(spellbook_to_del)

/datum/game_mode/raginmages/proc/count_alive_wizards()
	var/wizards_alive = 0
	for(var/datum/mind/wizard in wizards)
		var/mob/living/checked_wizard = wizard.current
		if(!checked_wizard)
			continue

		if(checked_wizard.stat == DEAD || isbrain(checked_wizard) || !iscarbon(checked_wizard))
			squabble_helper(wizard)
			continue

		if(checked_wizard.stat == UNCONSCIOUS)
			if(checked_wizard.health < HEALTH_THRESHOLD_DEAD) //Lets make this not get funny rng crit involved
				if(!squabble_helper(wizard))
					to_chat(checked_wizard, "<span class='warning'><font size='4'>The Space Wizard Federation is upset with your performance and have terminated your employment.</font></span>")
					checked_wizard.dust() // *REAL* ACTION!! *REAL* DRAMA!! *REAL* BLOODSHED!!
			continue

		if(!checked_wizard.client)
			continue // Could just be a bad connection, so SSD wiz's shouldn't be gibbed over it, but they're not "alive" either
		if(checked_wizard.client.is_afk() > 10 MINUTES)
			to_chat(checked_wizard, "<span class='warning'><font size='4'>The Space Wizard Federation is upset with your performance and have terminated your employment.</font></span>")
			checked_wizard.dust() // Let's keep the round moving
			continue
		wizards_alive++

	return wizards_alive

/datum/game_mode/raginmages/proc/try_make_another_mage_in(var/try_in)
	addtimer(CALLBACK(src, make_another_mage), try_in)

/datum/game_mode/raginmages/proc/make_another_mage()
	if(mages_made >= mages_cap)
		return

	/// We won't retry to make another mage, because it's almost game end
	if(SSshuttle.emergency.mode >= SHUTTLE_ESCAPE)
		return

	if(making_mage || (length(count_alive_wizards()) && !chaos_started))
		try_make_another_mage_in(delay_per_mage)
		return

	making_mage = TRUE
	var/mob/dead/observer/harry = pick_wizard()
	if (!harry)
		try_make_another_mage_in(wizard_poll_failed_retry_time)
		return

	var/mob/living/carbon/human/new_character = make_body(harry)
	new_character.mind.add_antag_datum(/datum/antagonist/wizard)

	// The first wiznerd can get their mugwort from the wizard's den, new ones will also need mugwort!
	new_character.equip_to_slot_or_del(new /obj/item/reagent_containers/food/drinks/mugwort(harry), SLOT_HUD_IN_BACKPACK)
	mages_made++
	dust_if_respawnable(harry)

	message_admins("SWF is still pissed, sending another wizard - [mages_cap - mages_made] left.")
	making_mage = FALSE
	return TRUE

/datum/game_mode/raginmages/proc/pick_wizard()
	var/image/source = image('icons/obj/cardboard_cutout.dmi', "cutout_wizard")
	var/list/mob/dead/observer/candidates = SSghost_spawns.poll_candidates("Do you want to play as a raging Space Wizard?", ROLE_WIZARD, TRUE, poll_time = 20 SECONDS, source = source)
	if (!length(candidates))
		message_admins("No observers wanted to spawn as wizard.")
		return null

	return pick(candidates)

// ripped from -tg-'s wizcode, because whee lets make a very general proc for a very specific gamemode
// This probably wouldn't do half bad as a proc in __HELPERS
// Lemme know if this causes species to mess up spectacularly or anything
/datum/game_mode/raginmages/proc/make_body(mob/dead/observer/ghost_candidate)
	if(!ghost_candidate?.key)
		return

	var/mob/living/carbon/human/new_character = new(pick(GLOB.latejoin))
	ghost_candidate.client.prefs.active_character.copy_to(new_character)
	new_character.key = ghost_candidate.key
	return new_character
