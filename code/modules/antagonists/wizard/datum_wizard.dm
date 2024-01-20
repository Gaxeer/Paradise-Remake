/datum/antagonist/wizard
	name = "Wizard"
	roundend_category = "wizard"
	job_rank = ROLE_WIZARD
	antag_memory = "<B>Remember:</B> do not forget to prepare your spells."
	greet_sound_path = 'sound/ambience/antag/ragesmages.ogg'
	special_role = SPECIAL_ROLE_WIZARD
	antag_hud_type = "hudwizard"
	antag_hud_name = ANTAG_HUD_WIZ
	wiki_page_name = "Wizard"
	offstation = TRUE
	strip = TRUE
	factions = list("wizard")
	default_outfit = /datum/outfit/wizard
	outfit_by_species = list(/datum/species/plasmaman = /datum/outfit/plasmaman/wizard)
	var/move_to_lair = TRUE

/datum/antagonist/wizard/Destroy(force, ...)
	owner?.current?.create_log(CONVERSION_LOG, "De-wizarded")
	. = ..()

/datum/antagonist/wizard/greet()
	. = ..()
	. += "You will find a list of available spells in your spell book. Choose your magic arsenal carefully."
	. += "The spellbook is bound to you, and others cannot use it."
	. += "In your pockets you will find a teleport scroll. Use it as needed."

/datum/antagonist/wizard/farewell()
	if(issilicon(owner.current))
		to_chat(wizard_mind.current, "<span class='userdanger'>You have been turned into a robot! You can feel your magical powers fading away...</span>")
	else
		to_chat(wizard_mind.current, "<span class='userdanger'>You have been brainwashed! You are no longer a wizard.</span>")

/datum/antagonist/wizard/on_gain()
	. = ..()
	if(owner?.current)
		owner.current.set_original_mob(wizard.current)
		owner.current.gene_stability += DEFAULT_GENE_STABILITY
	if(move_to_lair)
		send_to_lair()
	INVOKE_ASYNC(src, PROC_REF(name_wizard))

/datum/antagonist/wizard/add_owner_to_gamemode()
	SSticker.mode.wizards |= owner

/datum/antagonist/wizard/remove_owner_from_gamemode()
	SSticker.mode.wizards -= owner

/datum/antagonist/wizard/give_objectives()
	wizard.add_mind_objective(/datum/objective/wizchaos)

/datum/antagonist/wizard/apply_innate_effects(mob/living/mob_override)
	. = ..()

/datum/antagonist/wizard/remove_innate_effects(mob/living/mob_override)
	var/mob/living/mob_to_clear = ..()
	mob_to_clear.spellremove()

/datum/antagonist/wizard/equip()
	. = ..()
	if(wizard.dna.species.speciesbox)
		wizard.equip_to_slot_or_del(new wizard.dna.species.speciesbox(wizard), SLOT_HUD_IN_BACKPACK)
	else
		wizard.equip_to_slot_or_del(new /obj/item/storage/box/survival(wizard), SLOT_HUD_IN_BACKPACK)

/datum/antagonist/wizard/finalize_antag()
	. = ..()
	var/mob/living/carbon/human/our_wizard = owner?.current
	if (istype(our_wizard))
		owner.current.rejuvenate() //fix any damage taken by naked vox/plasmamen/etc while round setups
		wizard.update_icons()

/datum/antagonist/wizard/proc/send_to_lair()
	if(!owner?.current)
		return

	if(length(GLOB.wizardstart))
		owner.current.forceMove(pick(GLOB.wizardstart))
	else
		owner.current.forceMove(pick(GLOB.latejoin))
		to_chat(owner.current, "HOT INSERTION, GO GO GO")

/datum/antagonist/wizard/proc/name_wizard()
	var/mob/living/carbon/our_wizard = owner?.current
	if (!istype(our_wizard))
		return

	var/randomname = "[pick(GLOB.wizard_first)] [pick(GLOB.wizard_second)]"
	var/newname = copytext(sanitize(input(wizard_mob, "You are the Space Wizard. Would you like to change your name to something else?", "Name change", randomname) as null|text), 1, MAX_NAME_LEN)
	if(!newname)
		newname = randomname

	our_wizard.real_name = chosen_name
	our_wizard.name = chosen_name
	owner.name = chosen_name

/datum/outfit/wizard
	w_uniform = /obj/item/clothing/under/color/lightpurple
	head = /obj/item/clothing/head/wizard
	l_ear = /obj/item/radio/headset
	shoes = /obj/item/clothing/shoes/sandal
	wear_suit = /obj/item/clothing/suit/wizrobe
	back = /obj/item/storage/backpack/satchel
	r_store = /obj/item/teleportation_scroll
	l_hand =  /obj/item/spellbook
	box = /obj/item/storage/box/survival

/datum/outfit/plasmaman/wizard
	name = "Plasmaman Wizard"
	head = /obj/item/clothing/head/helmet/space/plasmaman/wizard
	uniform = /obj/item/clothing/under/plasmaman/wizard
	l_ear = /obj/item/radio/headset
	shoes = /obj/item/clothing/shoes/sandal
	wear_suit = /obj/item/clothing/suit/wizrobe
	back = /obj/item/storage/backpack/satchel
	r_store = /obj/item/teleportation_scroll
	l_hand =  /obj/item/spellbook
