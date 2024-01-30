#define CELL_NONE "None"

///////////////////////////////////////////////////////////////////////////////////////////////
// Brig Door control displays.
//  Description: This is a controls the timer for the brig doors, displays the timer on itself and
//               has a popup window when used, allowing to set the timer.
//  Code Notes: Combination of old brigdoor.dm code from rev4407 and the status_display.dm code
//  Date: 01/September/2010
//  Programmer: Veryinky
/////////////////////////////////////////////////////////////////////////////////////////////////
/obj/machinery/door_timer
	name = "door timer"
	icon = 'icons/obj/status_display.dmi'
	icon_state = "frame"
	desc = "A remote control for a door."
	req_access = list(ACCESS_BRIG)
	anchored = TRUE    		// can't pick it up
	density = FALSE       		// can walk through it.
	layer = WALL_OBJ_LAYER
	var/id = null     		// id of door it controls.
	var/releasetime = 0		// when world.timeofday reaches it - release the prisoner
	var/timing = FALSE    	// boolean, true/1 timer is on, false/0 means it's not timing
	var/picture_state		// icon_state of alert picture, if not displaying text/numbers
	var/list/obj/machinery/targets = list()
	var/timetoset = 0		// Used to set releasetime upon starting the timer
	var/obj/item/radio/Radio
	var/printed = 0
	var/datum/data/record/prisoner
	maptext_height = 26
	maptext_width = 32
	maptext_y = -1
	var/occupant = CELL_NONE
	var/crimes = CELL_NONE
	var/time = 0
	var/officer = CELL_NONE
	var/prisoner_name
	var/prisoner_charge
	var/prisoner_time
	var/prisoner_hasrecord = FALSE

/obj/machinery/door_timer/Destroy()
	targets.Cut()
	prisoner = null
	qdel(Radio)
	return ..()

/obj/machinery/door_timer/proc/print_report()
	if(occupant == CELL_NONE || crimes == CELL_NONE)
		return 0

	time = timetoset
	officer = usr.name

	for(var/obj/machinery/computer/prisoner/C as anything in SSmachines.get_machinery_of_type(/obj/machinery/computer/prisoner))
		var/obj/item/paper/P = new /obj/item/paper(C.loc)
		P.name = "[id] log - [occupant] [station_time_timestamp()]"
		P.info =  "<center><b>[id] - Brig record</b></center><br><hr><br>"
		P.info += {"<center>[station_name()] - Security Department</center><br>
						<center><small><b>Admission data:</b></small></center><br>
						<small><b>Log generated at:</b>		[station_time_timestamp()]<br>
						<b>Detainee:</b>		[occupant]<br>
						<b>Duration:</b>		[seconds_to_time(timetoset / 10)]<br>
						<b>Charge(s):</b>	[crimes]<br>
						<b>Arresting Officer:</b>		[usr.name]<br><hr><br>
						<small>This log file was generated automatically upon activation of a cell timer.</small>"}

		playsound(C.loc, "sound/goonstation/machines/printer_dotmatrix.ogg", 50, 1)
		GLOB.cell_logs += P

	var/datum/data/record/G = find_record("name", occupant, GLOB.data_core.general)
	var/prisoner_drank = "unknown"
	var/prisoner_trank = "unknown"
	if(G)
		if(G.fields["rank"])
			prisoner_drank = G.fields["rank"]
		if(G.fields["real_rank"]) // Ignore alt job titles - necessary for lookups
			prisoner_trank = G.fields["real_rank"]

	var/datum/data/record/R = find_security_record("name", occupant)

	var/timetext = seconds_to_time(timetoset / 10)
	var/announcetext = "Задержанный [occupant] ([prisoner_drank]) был помещен в камеру заключения на [timetext], за преступление: '[crimes]'. \
	Ответственный офицер: [usr.name].[R ? "" : " Запись о задержанном не найдена, требуется обновление записи вручную."]"
	Radio.autosay(announcetext, name, "Security")

	// Notify the actual criminal being brigged. This is a QOL thing to ensure they always know the charges against them.
	// Announcing it on radio isn't enough, as they're unlikely to have sec radio.
	notify_prisoner("Вы были заключены в камеру заключения на [timetext], за преступление: '[crimes]'.")

	if(prisoner_trank != "unknown" && prisoner_trank != "Assistant")
		SSjobs.notify_dept_head(prisoner_trank, announcetext)

	if(R)
		prisoner = R
		R.fields["criminal"] = SEC_RECORD_STATUS_INCARCERATED
		var/mob/living/carbon/human/M = usr
		var/rank = "UNKNOWN RANK"
		if(istype(M))
			var/obj/item/card/id/I = M.get_id_card()
			if(I)
				rank = I.assignment
		if(!R.fields["comments"] || !islist(R.fields["comments"])) //copied from security computer code because apparently these need to be initialized
			R.fields["comments"] = list()
		R.fields["comments"] += "Autogenerated by [name] on [GLOB.current_date_string] [station_time_timestamp()]<BR>Sentenced to [timetoset/10] seconds for the charges of \"[crimes]\" by [rank] [usr.name]."
		update_all_mob_security_hud()
	return 1

/obj/machinery/door_timer/proc/notify_prisoner(notifytext)
	for(var/mob/living/carbon/human/H in range(4, get_turf(src)))
		if(occupant == H.name)
			to_chat(H, "[src] beeps, \"[notifytext]\"")
			return
	atom_say("[src] beeps, \"[occupant]: [notifytext]\"")

/obj/machinery/door_timer/Initialize(mapload)
	..()

	Radio = new /obj/item/radio(src)
	Radio.listening = FALSE
	Radio.config(list("Security" = 0))
	Radio.follow_target = src
	return INITIALIZE_HINT_LATELOAD

/obj/machinery/door_timer/LateInitialize()
	..()
	for(var/obj/machinery/door/window/brigdoor/M as anything in SSmachines.get_machinery_of_type(/obj/machinery/door/window/brigdoor))
		if(M.id == id)
			targets += M
			RegisterSignal(M, COMSIG_PARENT_QDELETING, PROC_REF(on_target_qdel))

	for(var/obj/machinery/flasher/F as anything in SSmachines.get_machinery_of_type(/obj/machinery/flasher))
		if(F.id == id)
			targets += F
			RegisterSignal(F, COMSIG_PARENT_QDELETING, PROC_REF(on_target_qdel))

	for(var/obj/structure/closet/secure_closet/brig/C in world)
		if(C.id == id)
			targets += C
			RegisterSignal(C, COMSIG_PARENT_QDELETING, PROC_REF(on_target_qdel))

	for(var/obj/machinery/treadmill_monitor/T as anything in SSmachines.get_machinery_of_type(/obj/machinery/treadmill_monitor))
		if(T.id == id)
			targets += T
			RegisterSignal(T, COMSIG_PARENT_QDELETING, PROC_REF(on_target_qdel))

	if(!length(targets))
		stat |= BROKEN
	update_icon(UPDATE_ICON_STATE)

/obj/machinery/door_timer/Destroy()
	QDEL_NULL(Radio)
	targets.Cut()
	prisoner = null
	return ..()

/obj/machinery/door_timer/proc/on_target_qdel(atom/target)
	targets -= target

//Main door timer loop, if it's timing and time is >0 reduce time by 1.
// if it's less than 0, open door, reset timer
// update the door_timer window and the icon
/obj/machinery/door_timer/process()
	if(stat & (NOPOWER|BROKEN))
		return
	if(timing)
		if(timeleft() <= 0)
			Radio.autosay("Время заключения истекло. Освобождение заключенного.", name, "Security", list(z))
			occupant = CELL_NONE
			timer_end() // open doors, reset timer, clear status screen
			timing = FALSE
			. = PROCESS_KILL
		update_icon(UPDATE_ICON_STATE)
	else
		timer_end()
		return PROCESS_KILL

// has the door power situation changed, if so update icon.
/obj/machinery/door_timer/power_change()
	if(!..())
		return
	update_icon(UPDATE_ICON_STATE)


// open/closedoor checks if door_timer has power, if so it checks if the
// linked door is open/closed (by density) then opens it/closes it.

// Closes and locks doors, power check
/obj/machinery/door_timer/proc/timer_start()

	if(stat & (NOPOWER|BROKEN))
		return 0

	if(!printed)
		if(!print_report())
			timing = FALSE
			return FALSE

	// Set releasetime
	releasetime = world.timeofday + timetoset
	START_PROCESSING(SSmachines, src)

	for(var/obj/machinery/door/window/brigdoor/door in targets)
		if(door.density)
			continue
		spawn(0)
			door.close()

	for(var/obj/structure/closet/secure_closet/brig/C in targets)
		if(C.broken)
			continue
		if(C.opened && !C.close())
			continue
		C.locked = TRUE
		C.close()
		C.update_icon()

	for(var/obj/machinery/treadmill_monitor/T in targets)
		T.total_joules = 0
		T.on = TRUE

	return TRUE


// Opens and unlocks doors, power check
/obj/machinery/door_timer/proc/timer_end()
	if(stat & (NOPOWER|BROKEN))
		return 0

	// Reset vars
	occupant = CELL_NONE
	crimes = CELL_NONE
	time = 0
	timetoset = 0
	officer = CELL_NONE
	releasetime = 0
	printed = 0
	if(prisoner)
		prisoner.fields["criminal"] = SEC_RECORD_STATUS_RELEASED
		update_all_mob_security_hud()
		prisoner = null

	for(var/obj/machinery/door/window/brigdoor/door in targets)
		if(!door.density)
			continue
		INVOKE_ASYNC(door, TYPE_PROC_REF(/obj/machinery/door/window/brigdoor, open))

	for(var/obj/structure/closet/secure_closet/brig/C in targets)
		if(C.broken)
			continue
		if(C.opened)
			continue
		C.locked = FALSE
		C.update_icon()

	for(var/obj/machinery/treadmill_monitor/T in targets)
		if(!T.stat)
			T.redeem()
		T.on = FALSE

	return TRUE


// Check for releasetime timeleft
/obj/machinery/door_timer/proc/timeleft()
	var/time = releasetime - world.timeofday
	if(time > MIDNIGHT_ROLLOVER / 2)
		time -= MIDNIGHT_ROLLOVER
	if(time < 0)
		return 0
	return time / 10

// Set timetoset
/obj/machinery/door_timer/proc/timeset(seconds)
	timetoset = seconds * 10

	if(timetoset <= 0)
		timetoset = 0

	return

/obj/machinery/door_timer/attack_ai(mob/user)
	ui_interact(user)

/obj/machinery/door_timer/attack_ghost(mob/user)
	ui_interact(user)

//Allows humans to use door_timer
//Opens dialog window when someone clicks on door timer
// Allows altering timer and the timing boolean.
// Flasher activation limited to 150 seconds
/obj/machinery/door_timer/attack_hand(mob/user)
	if(..())
		return
	ui_interact(user)

/obj/machinery/door_timer/ui_state(mob/user)
	return GLOB.default_state

/obj/machinery/door_timer/ui_interact(mob/user, datum/tgui/ui = null)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "BrigTimer",  name)
		ui.open()

/obj/machinery/door_timer/ui_static_data(mob/user)
	var/list/data = list()
	data["spns"] = list()
	for(var/mob/living/carbon/human/H in range(4, get_turf(src)))
		if(H.handcuffed)
			data["spns"] += H.name
	return data

/obj/machinery/door_timer/ui_data(mob/user)
	var/list/data = list()
	data["cell_id"] = name
	data["occupant"] = occupant
	data["crimes"] = crimes
	data["brigged_by"] = officer
	data["time_set"] = seconds_to_clock(timetoset / 10)
	data["time_left"] = seconds_to_clock(timeleft())
	data["timing"] = timing
	data["isAllowed"] = allowed(user)
	data["prisoner_name"] = prisoner_name
	data["prisoner_charge"] = prisoner_charge
	data["prisoner_time"] = prisoner_time
	data["prisoner_hasrec"] = prisoner_hasrecord
	return data

/obj/machinery/door_timer/allowed(mob/user)
	if(user.can_admin_interact())
		return TRUE
	return ..()

/obj/machinery/door_timer/ui_act(action, params)
	if(..())
		return
	if(!allowed(usr))
		to_chat(usr, "<span class='warning'>Access denied.</span>")
		return
	. = TRUE
	switch(action)
		if("prisoner_name")
			if(params["prisoner_name"])
				prisoner_name = params["prisoner_name"]
			else
				prisoner_name = input("Prisoner Name:", name, prisoner_name) as text|null
			if(prisoner_name)
				var/datum/data/record/R = find_security_record("name", prisoner_name)
				if(istype(R))
					prisoner_hasrecord = TRUE
				else
					prisoner_hasrecord = FALSE
		if("prisoner_charge")
			prisoner_charge = input("Prisoner Charge:", name, prisoner_charge) as text|null
		if("prisoner_time")
			prisoner_time = input("Prisoner Time (in minutes):", name, prisoner_time) as num|null
			prisoner_time = min(max(round(prisoner_time), 0), 60)
		if("start")
			if(!prisoner_name || !prisoner_charge || !prisoner_time)
				return FALSE
			timeset(prisoner_time * 60)
			occupant = prisoner_name
			crimes = prisoner_charge
			prisoner_name = null
			prisoner_charge = null
			prisoner_time = null
			timing = TRUE
			timer_start()
			update_icon(UPDATE_ICON_STATE)
		if("restart_timer")
			if(timing)
				var/reset_reason = sanitize(copytext_char(input(usr, "Reason for resetting timer:", name, "") as text|null, 1, MAX_MESSAGE_LEN))	// SS220 EDIT - ORIGINAL: copytext
				if(!reset_reason)
					to_chat(usr, "<span class='warning'>Cancelled reset: reason field is required.</span>")
					return FALSE
				releasetime = world.timeofday + timetoset
				var/resettext = isobserver(usr) ? "по причине: '[reset_reason]'" : "офицером [usr.name], по причине: '[reset_reason]'"
				Radio.autosay("Таймер заключенного [occupant] был сброшен [resettext].", name, "Security", list(z))
				notify_prisoner("Ваш таймер был сброшен по причине: '[reset_reason]'.")
				var/datum/data/record/R = find_security_record("name", occupant)
				if(istype(R))
					R.fields["comments"] += "Autogenerated by [name] on [GLOB.current_date_string] [station_time_timestamp()]<BR>Timer reset [resettext]"
			else
				. = FALSE
		if("stop")
			if(timing)
				timer_end()
				var/stoptext = isobserver(usr) ? "консолью управления камерами." : "офицером [usr.name]."
				Radio.autosay("Таймер остановлен вручную [stoptext]", name, "Security", list(z))
			else
				. = FALSE
		if("flash")
			for(var/obj/machinery/flasher/F in targets)
				if(F.last_flash && (F.last_flash + 150) > world.time)
					to_chat(usr, "<span class='warning'>Flash still charging.</span>")
				else
					F.flash()
		else
			. = FALSE


//icon update function
// if NOPOWER, display blank
// if BROKEN, display blue screen of death icon AI uses
// if timing=true, run update display function
/obj/machinery/door_timer/update_icon_state()
	if(stat & (NOPOWER))
		icon_state = "frame"
		return
	if(stat & (BROKEN))
		set_picture("ai_bsod")
		return
	if(timing)
		var/disp1 = id
		var/timeleft = timeleft()
		var/disp2 = "[add_zero(num2text((timeleft / 60) % 60),2)]:[add_zero(num2text(timeleft % 60), 2)]"
		if(length(disp2) > DISPLAY_CHARS_PER_LINE)
			disp2 = "Error"
		update_display(disp1, disp2)
	else
		if(maptext)	maptext = ""


// Adds an icon in case the screen is broken/off, stolen from status_display.dm
/obj/machinery/door_timer/proc/set_picture(state)
	picture_state = state
	overlays.Cut()
	overlays += image('icons/obj/status_display.dmi', icon_state=picture_state)

/obj/machinery/door_timer/proc/return_time_input()
	var/mins = input(usr, "Minutes", "Enter number of minutes", 0) as num
	var/seconds = input(usr, "Seconds", "Enter number of seconds", 0) as num
	var/totaltime = (seconds + (mins * 60))
	return totaltime

//Checks to see if there's 1 line or 2, adds text-icons-numbers/letters over display
// Stolen from status_display
/obj/machinery/door_timer/proc/update_display(line1, line2)
	line1 = uppertext(line1)
	line2 = uppertext(line2)
	var/new_text = {"<div style="font-size:[DISPLAY_FONT_SIZE];color:[DISPLAY_FONT_COLOR];font:'[DISPLAY_FONT_STYLE]';text-align:center;" valign="top">[line1]<br>[line2]</div>"}
	if(maptext != new_text)
		maptext = new_text


//Actual string input to icon display for loop, with 5 pixel x offsets for each letter.
//Stolen from status_display
/obj/machinery/door_timer/proc/texticon(tn, px = 0, py = 0)
	var/image/I = image('icons/obj/status_display.dmi', "blank")
	var/len = length(tn)

	for(var/d = 1 to len)
		var/char = copytext(tn, len-d+1, len-d+2)
		if(char == " ")
			continue
		var/image/ID = image('icons/obj/status_display.dmi', icon_state=char)
		ID.pixel_x = -(d-1)*5 + px
		ID.pixel_y = py
		I.overlays += ID
	return I

/obj/machinery/door_timer/cell_1
	name = "Cell 1"
	id = "Cell 1"

/obj/machinery/door_timer/cell_2
	name = "Cell 2"
	id = "Cell 2"

/obj/machinery/door_timer/cell_3
	name = "Cell 3"
	id = "Cell 3"

/obj/machinery/door_timer/cell_4
	name = "Cell 4"
	id = "Cell 4"

/obj/machinery/door_timer/cell_5
	name = "Cell 5"
	id = "Cell 5"

/obj/machinery/door_timer/cell_6
	name = "Cell 6"
	id = "Cell 6"

/obj/machinery/door_timer/cell_7
	name = "Cell 7"
	id = "Cell 7"

/obj/machinery/door_timer/cell_8
	name = "Cell 8"
	id = "Cell 8"

#undef CELL_NONE
