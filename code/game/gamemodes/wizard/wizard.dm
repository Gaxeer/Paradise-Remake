/datum/game_mode
	var/list/datum/mind/wizards = list()
	var/list/datum/mind/apprentices = list()

/datum/game_mode/wizard
	name = "wizard"
	config_tag = "wizard"
	tdm_gamemode = TRUE
	required_players = 20
	required_enemies = 1
	recommended_enemies = 1
	var/list/datum/mind/pre_wizards = list()

/datum/game_mode/wizard/announce()
	to_chat(world, "<B>The current game mode is - Wizard!</B>")
	to_chat(world, "<B>There is a <font color='red'>SPACE WIZARD</font> on the station. You can't let him achieve his objective!</B>")

/datum/game_mode/wizard/can_start()
	if(!length(GLOB.wizardstart))
		error("No wizard start locations were prepared. Please report this bug.")
		return FALSE

	return ..()

/datum/game_mode/wizard/pre_setup()
	pre_wizards = get_players_for_role(ROLE_WIZARD)
	if(!length(pre_wizards))
		return FALSE

	return TRUE

/datum/game_mode/wizard/post_setup()
	if(length(pre_wizards))
		var/datum/mind/our_wizard = pick(pre_wizards)
		our_wizard.add_antag_datum(/datum/antagonist/wizard)
	. = ..()

// Checks if the game should end due to all wizards and apprentices being dead, or MMI'd/Borged
/datum/game_mode/wizard/check_finished()
	. = ..()
	if(.)
		return TRUE

	return count_alive_wizards() || count_alive_apprentices()

/datum/game_mode/wizard/declare_completion()
	if(finished)
		SSticker.mode_result = "wizard loss - wizard killed"
		to_chat(world, "<span class='warning'><FONT size = 3><B> The wizard[(length(wizards))  "s" : ""] has been killed by the crew! The Space Wizards Federation has been taught a lesson they will not soon forget!</B></FONT></span>")
	..()
	return TRUE

/datum/game_mode/wizard/proc/count_alive_wizards()
	var/wizards_alive = 0
	for(var/datum/mind/wizard in wizards)
		if(!iscarbon(apprentice.current))
			continue
		if(apprentice.current.stat == DEAD)
			continue
		if(istype(apprentice.current, /obj/item/mmi))
			continue
		wizards_alive++

	return wizards_alive

/datum/game_mode/wizard/proc/count_alive_apprentices()
	var/apprentices_alive = 0
	for(var/datum/mind/apprentice in apprentices)
		if(!iscarbon(apprentice.current))
			continue
		if(apprentice.current.stat == DEAD)
			continue
		if(istype(apprentice.current, /obj/item/mmi))
			continue
		apprentices_alive++

	return apprentices_alive

//OTHER PROCS

//To batch-remove wizard spells. Linked to mind.dm
/mob/proc/spellremove()
	if(!mind)
		return
	for(var/obj/effect/proc_holder/spell/spell_to_remove in mind.spell_list)
		qdel(spell_to_remove)
		mind.spell_list -= spell_to_remove

//To batch-remove mob spells.
/mob/proc/mobspellremove()
	for(var/obj/effect/proc_holder/spell/spell_to_remove in mob_spell_list)
		qdel(spell_to_remove)
		mob_spell_list -= spell_to_remove

/proc/iswizard(mob/possible_wizard)
	return possible_wizard?.mind?.has_antag_datum(/datum/antagonist/wizard)
