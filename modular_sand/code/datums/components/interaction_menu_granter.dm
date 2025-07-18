/// Attempts to open the tgui menu
/mob/verb/interact_with()
	set name = "Interact With"
	set desc = "Perform an interaction with someone."
	set category = "IC"
	set src in view(usr.client)

	var/datum/component/interaction_menu_granter/menu = usr.GetComponent(/datum/component/interaction_menu_granter)
	if(!menu)
		to_chat(usr, span_warning("You must have done something really bad to not have an interaction component."))
		return

	if(!src)
		to_chat(usr, span_warning("Your interaction target is gone!"))
		return
	menu.open_menu(usr, src)

#define INTERACTION_NORMAL 0
#define INTERACTION_LEWD 1
#define INTERACTION_EXTREME 2

/// The menu itself, only var is target which is the mob you are interacting with
/datum/component/interaction_menu_granter
	var/mob/living/target

/datum/component/interaction_menu_granter/Initialize(...)
	if(!ismob(parent))
		return COMPONENT_INCOMPATIBLE
	var/mob/parent_mob = parent
	if(!parent_mob.client)
		return COMPONENT_INCOMPATIBLE
	. = ..()

/datum/component/interaction_menu_granter/RegisterWithParent()
	. = ..()
	RegisterSignal(parent, COMSIG_MOB_CTRLSHIFTCLICKON, .proc/open_menu)

/datum/component/interaction_menu_granter/Destroy(force, ...)
	target = null
	. = ..()

/datum/component/interaction_menu_granter/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_MOB_CTRLSHIFTCLICKON)
	. = ..()

/// The one interacting is clicker, the interacted is clicked.
/datum/component/interaction_menu_granter/proc/open_menu(mob/clicker, mob/clicked)
	// COMSIG_MOB_CTRLSHIFTCLICKON accepts `atom`s, prevent it
	if(!istype(clicked))
		return FALSE
	// Don't cancel admin quick spawn
	if(isobserver(clicked) && check_rights_for(clicker.client, R_SPAWN))
		return FALSE
	target = clicked
	ui_interact(clicker)
	return COMSIG_MOB_CANCEL_CLICKON

/datum/component/interaction_menu_granter/ui_state(mob/user)
	// Funny admin, don't you dare be the extra funny now.
	if(user.client.holder && !user.client.holder.deadmined)
		return GLOB.always_state
	if(user == parent)
		return GLOB.conscious_state
	return GLOB.never_state

/datum/component/interaction_menu_granter/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "MobInteraction", "Interactions")
		ui.open()

/proc/pref_to_num(pref)
	switch(pref)
		if("Yes")
			return 1
		if("Ask")
			return 2
		else
			return 0

/datum/component/interaction_menu_granter/ui_data(mob/user)
	. = ..()
	//Getting player
	var/mob/living/self = parent
	//Getting info
	.["isTargetSelf"] = target == self
	.["interactingWith"] = target != self ? "взаимодействие с [target]..." : "взаимодействие с собой..."
	.["selfAttributes"] = self.list_interaction_attributes(self)
	.["lust"] = self.get_lust()
	.["maxLust"] = self.get_lust_tolerance() * 3
	if(target != self)
		.["theirAttributes"] = target.list_interaction_attributes(self)
		if(HAS_TRAIT(user, TRAIT_ESTROUS_DETECT))
			.["theirLust"] = target.get_lust()
			.["theirMaxLust"] = target.get_lust_tolerance() * 3

	//Getting interactions
	var/list/sent_interactions = list()
	for(var/interaction_key in SSinteractions.interactions)
		var/datum/interaction/I = SSinteractions.interactions[interaction_key]
		if(I.evaluate_user(self, action_check = FALSE) && I.evaluate_target(self, target))
			if(I.user_is_target && target != self)
				continue
			var/list/interaction = list()
			interaction["key"] = I.type
			var/description = replacetext(I.description, "%COCK%", self.has_penis() ? "член" : "страпон")
			interaction["desc"] = description
			if(istype(I, /datum/interaction/lewd))
				var/datum/interaction/lewd/O = I
				if(O.extreme)
					interaction["type"] = INTERACTION_EXTREME
				else
					interaction["type"] = INTERACTION_LEWD
			else
				interaction["type"] = INTERACTION_NORMAL
			sent_interactions += list(interaction)
	.["interactions"] = sent_interactions

	//Get their genitals
	var/list/genitals = list()
	var/mob/living/carbon/get_genitals = self
	if(istype(get_genitals))
		for(var/obj/item/organ/genital/genital in get_genitals.internal_organs)	//Only get the genitals
			if(CHECK_BITFIELD(genital.genital_flags, GENITAL_INTERNAL))			//Not those though
				continue
			var/list/genital_entry = list()
			genital_entry["name"] = "[genital.name]" //Prevents code from adding a prefix
			genital_entry["key"] = REF(genital) //The key is the reference to the object
			var/visibility = "Invalid"
			if(CHECK_BITFIELD(genital.genital_flags, GENITAL_THROUGH_CLOTHES))
				visibility = "Всегда видно"
			else if(CHECK_BITFIELD(genital.genital_flags, GENITAL_UNDIES_HIDDEN))
				visibility = "Спрятано под нижним бельем"
			else if(CHECK_BITFIELD(genital.genital_flags, GENITAL_HIDDEN))
				visibility = "Всегда спрятано"
			else
				visibility = "спрятано под одеждой"

			var/extras = "None"
			if(CHECK_BITFIELD(genital.genital_flags, GENITAL_CAN_STUFF))
				extras = "Заполнение яйцами"

			genital_entry["extras"] = extras
			genital_entry["visibility"] = visibility
			genital_entry["possible_choices"] = GLOB.genitals_visibility_toggles
			genital_entry["extra_choices"] = list(GEN_ALLOW_EGG_STUFFING)
			genitals += list(genital_entry)
	if(iscarbon(self) && !self.getorganslot(ORGAN_SLOT_ANUS))
		var/simulated_ass = list()
		simulated_ass["name"] = "anus"
		simulated_ass["key"] = "anus"
		var/visibility = "Invalid"
		switch(self.anus_exposed)
			if(1)
				visibility = "Всегда видно"
			if(0)
				visibility = "Спрятан под одеждой"
			else
				visibility = "Всегда спрятан"
		simulated_ass["visibility"] = visibility
		simulated_ass["possible_choices"] = GLOB.genitals_visibility_toggles - GEN_VISIBLE_NO_CLOTHES
		genitals += list(simulated_ass)
	.["genitals"] = genitals

	//Get their genitals
	var/list/genital_fluids = list()
	var/mob/living/carbon/target_genitals = target || self
	if(istype(target_genitals))
		for(var/obj/item/organ/genital/genital in target_genitals.internal_organs)
			if(!(CHECK_BITFIELD(genital.genital_flags, GENITAL_FUID_PRODUCTION)))
				continue
			var/fluids = (clamp(genital.fluid_rate * ((world.time - genital.last_orgasmed) / (10 SECONDS)) * genital.fluid_mult, 0, genital.fluid_max_volume) / genital.fluid_max_volume)
			var/list/genital_entry = list()
			genital_entry["name"] = "[genital.name]"
			genital_entry["key"] = REF(genital)
			genital_entry["fluid"] = fluids
			genital_fluids += list(genital_entry)
	.["genital_fluids"] = genital_fluids

	var/list/genital_interactibles = list()
	if(istype(target_genitals))
		for(var/obj/item/organ/genital/genital in target_genitals.internal_organs)
			if(!genital.is_exposed())
				continue
			var/list/equipment_names = list()
			for(var/obj/equipment in genital.contents)
				equipment_names += equipment.name
			var/list/genital_entry = list()
			genital_entry["name"] = "[genital.name]"
			genital_entry["key"] = REF(genital)
			genital_entry["possible_choices"] = GLOB.genitals_interactions
			genital_entry["equipments"] = equipment_names
			genital_interactibles += list(genital_entry)
	.["genital_interactibles"] = genital_interactibles

	var/datum/preferences/prefs = usr?.client.prefs
	if(prefs)
	//Getting char prefs
		.["erp_pref"] = 			pref_to_num(prefs.erppref)
		.["noncon_pref"] = 		pref_to_num(prefs.nonconpref)
		.["vore_pref"] = 		pref_to_num(prefs.vorepref)
		.["extreme_pref"] = 		pref_to_num(prefs.extremepref)
		.["extreme_harm"] = 		pref_to_num(prefs.extremeharm)
		.["unholy_pref"] =		pref_to_num(prefs.unholypref)

	//Getting preferences
		.["verb_consent"] = 		CHECK_BITFIELD(prefs.toggles, VERB_CONSENT)
		.["lewd_verb_sounds"] = 	!CHECK_BITFIELD(prefs.toggles, LEWD_VERB_SOUNDS)
		.["arousable"] = 		prefs.arousable
		.["genital_examine"] = 	CHECK_BITFIELD(prefs.cit_toggles, GENITAL_EXAMINE)
		.["vore_examine"] = 		CHECK_BITFIELD(prefs.cit_toggles, VORE_EXAMINE)
		.["medihound_sleeper"] = CHECK_BITFIELD(prefs.cit_toggles, MEDIHOUND_SLEEPER)
		.["eating_noises"] = 	CHECK_BITFIELD(prefs.cit_toggles, EATING_NOISES)
		.["digestion_noises"] =	CHECK_BITFIELD(prefs.cit_toggles, DIGESTION_NOISES)
		.["trash_forcefeed"] = 	CHECK_BITFIELD(prefs.cit_toggles, TRASH_FORCEFEED)
		.["forced_fem"] = 		CHECK_BITFIELD(prefs.cit_toggles, FORCED_FEM)
		.["forced_masc"] = 		CHECK_BITFIELD(prefs.cit_toggles, FORCED_MASC)
		.["hypno"] = 			CHECK_BITFIELD(prefs.cit_toggles, HYPNO)
		.["bimbofication"] = 	CHECK_BITFIELD(prefs.cit_toggles, BIMBOFICATION)
		.["breast_enlargement"] = CHECK_BITFIELD(prefs.cit_toggles, BREAST_ENLARGEMENT)
		.["penis_enlargement"] = CHECK_BITFIELD(prefs.cit_toggles, PENIS_ENLARGEMENT)
		.["butt_enlargement"] =	CHECK_BITFIELD(prefs.cit_toggles, BUTT_ENLARGEMENT)
		.["belly_inflation"] = CHECK_BITFIELD(prefs.cit_toggles, BELLY_INFLATION)
		.["never_hypno"] = 		!CHECK_BITFIELD(prefs.cit_toggles, NEVER_HYPNO)
		.["no_aphro"] = 			!CHECK_BITFIELD(prefs.cit_toggles, NO_APHRO)
		.["no_ass_slap"] = 		!CHECK_BITFIELD(prefs.cit_toggles, NO_ASS_SLAP)
		.["no_auto_wag"] = 		!CHECK_BITFIELD(prefs.cit_toggles, NO_AUTO_WAG)

/proc/num_to_pref(num)
	switch(num)
		if(1)
			return "Да"
		if(2)
			return "Нужно спросить"
		else
			return "Нет"

/datum/component/interaction_menu_granter/ui_act(action, params)
	if(..())
		return
	var/mob/living/parent_mob = parent
	switch(action)
		if("interact")
			var/datum/interaction/o = SSinteractions.interactions[params["interaction"]]
			if(o)
				o.do_action(parent_mob, target)
				return TRUE
			return FALSE
		if("genital")
			var/mob/living/carbon/self = usr
			if(params["genital"] == "anus")
				self.anus_toggle_visibility(params["visibility"])
				return TRUE
			var/obj/item/organ/genital/genital = locate(params["genital"], self.internal_organs)
			if(genital && (genital in self.internal_organs))
				genital.toggle_visibility(params["visibility"])
				return TRUE
			else
				return FALSE
		if("genital_interaction")
			var/mob/living/carbon/actual_target = target || usr
			var/mob/user = usr
			var/obj/item/organ/genital/genital = locate(params["genital"], actual_target.internal_organs)
			if(!(genital && (genital in actual_target.internal_organs)))
				return FALSE
			switch(params["action"])
				if(GEN_INSERT_EQUIPMENT)
					var/obj/item/stuff = user.get_active_held_item()
					if(!istype(stuff))
						to_chat(user, span_warning("Чтобы засунуть туда предмет - его нужно взять в руку!"))
						return FALSE
					stuff.insert_item_organ(user, actual_target, genital)
				if(GEN_REMOVE_EQUIPMENT)
					var/obj/item/selected_item = input(user, "Выбери предмет, который хочешь вытащить", "Вытаскивание предмета") as null|anything in genital.contents
					if(selected_item)
						if(!do_mob(user, actual_target, 5 SECONDS))
							return FALSE
						if(!user.put_in_hands(selected_item))
							user.transferItemToLoc(get_turf(user))
						return TRUE
					return FALSE
		if("char_pref")
			var/datum/preferences/prefs = parent_mob.client.prefs
			var/value = num_to_pref(params["value"])
			switch(params["char_pref"])
				if("erp_pref")
					if(prefs.erppref == value)
						return FALSE
					else
						prefs.erppref = value
				if("noncon_pref")
					if(prefs.nonconpref == value)
						return FALSE
					else
						prefs.nonconpref = value
				if("vore_pref")
					if(prefs.vorepref == value)
						return FALSE
					else
						prefs.vorepref = value
				if("unholy_pref")
					if(prefs.unholypref == value)
						return FALSE
					else
						prefs.unholypref = value
				if("extreme_pref")
					if(prefs.extremepref == value)
						return FALSE
					else
						prefs.extremepref = value
						if(prefs.extremepref == "No")
							prefs.extremeharm = "No"
				if("extreme_harm")
					if(prefs.extremeharm == value)
						return FALSE
					else
						prefs.extremeharm = value
				else
					return FALSE
			prefs.save_character()
			return TRUE
		if("pref")
			var/datum/preferences/prefs = parent_mob.client.prefs
			switch(params["pref"])
				if("verb_consent")
					TOGGLE_BITFIELD(prefs.toggles, VERB_CONSENT)
				if("lewd_verb_sounds")
					TOGGLE_BITFIELD(prefs.toggles, LEWD_VERB_SOUNDS)
				if("arousable")
					prefs.arousable = !prefs.arousable
				if("genital_examine")
					TOGGLE_BITFIELD(prefs.cit_toggles, GENITAL_EXAMINE)
				if("vore_examine")
					TOGGLE_BITFIELD(prefs.cit_toggles, VORE_EXAMINE)
				if("medihound_sleeper")
					TOGGLE_BITFIELD(prefs.cit_toggles, MEDIHOUND_SLEEPER)
				if("eating_noises")
					TOGGLE_BITFIELD(prefs.cit_toggles, EATING_NOISES)
				if("digestion_noises")
					TOGGLE_BITFIELD(prefs.cit_toggles, DIGESTION_NOISES)
				if("trash_forcefeed")
					TOGGLE_BITFIELD(prefs.cit_toggles, TRASH_FORCEFEED)
				if("forced_fem")
					TOGGLE_BITFIELD(prefs.cit_toggles, FORCED_FEM)
				if("forced_masc")
					TOGGLE_BITFIELD(prefs.cit_toggles, FORCED_MASC)
				if("hypno")
					TOGGLE_BITFIELD(prefs.cit_toggles, HYPNO)
				if("bimbofication")
					TOGGLE_BITFIELD(prefs.cit_toggles, BIMBOFICATION)
				if("breast_enlargement")
					TOGGLE_BITFIELD(prefs.cit_toggles, BREAST_ENLARGEMENT)
				if("penis_enlargement")
					TOGGLE_BITFIELD(prefs.cit_toggles, PENIS_ENLARGEMENT)
				if("butt_enlargement")
					TOGGLE_BITFIELD(prefs.cit_toggles, BUTT_ENLARGEMENT)
				if("belly_inflation")
					TOGGLE_BITFIELD(prefs.cit_toggles, BELLY_INFLATION)
				if("never_hypno")
					TOGGLE_BITFIELD(prefs.cit_toggles, NEVER_HYPNO)
				if("no_aphro")
					TOGGLE_BITFIELD(prefs.cit_toggles, NO_APHRO)
				if("no_ass_slap")
					TOGGLE_BITFIELD(prefs.cit_toggles, NO_ASS_SLAP)
				if("no_auto_wag")
					TOGGLE_BITFIELD(prefs.cit_toggles, NO_AUTO_WAG)
				else
					return FALSE
			prefs.save_preferences()
			return TRUE

#undef INTERACTION_NORMAL
#undef INTERACTION_LEWD
#undef INTERACTION_EXTREME
