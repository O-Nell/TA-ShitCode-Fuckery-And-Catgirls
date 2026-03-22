/datum/looping_sound/instrument
	mid_length = 2400 // 4 minutes for some reason. better would be each song having a specific length
	volume = 100
	extra_range = 5
	persistent_loop = TRUE
	var/stress2give = /datum/stressevent/music
	sound_group = null

GLOBAL_LIST_EMPTY(instrument_band_lobbies)

/proc/instrument_band_member_id(mob/living/user)
	if(!user)
		return null
	if(user.mind)
		return "[REF(user.mind)]"
	return "[REF(user)]"

/datum/instrument_band_slot
	var/member_id
	var/member_name
	var/instrument_type
	var/instrument_name
	var/song_file
	var/datum/weakref/instrument_ref

/datum/instrument_band_lobby
	var/owner_id
	var/owner_name
	var/datum/weakref/owner_ref
	var/list/member_slots = list() // key: instrument instance ref text

/datum/instrument_band_lobby/proc/register_owner(mob/living/user, obj/item/rogue/instrument/instrument, song_file)
	owner_id = instrument_band_member_id(user)
	owner_name = user.real_name
	owner_ref = WEAKREF(user)
	add_or_replace_member(user, instrument, song_file)

/datum/instrument_band_lobby/proc/add_or_replace_member(mob/living/user, obj/item/rogue/instrument/instrument, song_file)
	var/member_id = instrument_band_member_id(user)
	if(!member_id || !instrument || !song_file)
		return FALSE
	var/slot_key = "[REF(instrument)]"
	var/datum/instrument_band_slot/slot = member_slots[slot_key]
	if(!slot)
		slot = new
		member_slots[slot_key] = slot
	var/old_member = slot.member_name
	slot.member_id = member_id
	slot.member_name = user.real_name
	slot.instrument_type = slot_key
	slot.instrument_name = instrument.name
	slot.song_file = song_file
	slot.instrument_ref = WEAKREF(instrument)

	if(owner_id && owner_id != member_id)
		var/mob/living/owner_mob = owner_ref?.resolve()
		if(owner_mob)
			if(old_member && old_member != user.real_name)
				to_chat(owner_mob, span_notice("[user.real_name] replaced [old_member] on [instrument.name] in your band lobby."))
			else
				to_chat(owner_mob, span_notice("[user.real_name] joined your band lobby with [instrument.name]."))
	return TRUE

/datum/instrument_band_lobby/proc/remove_member_by_id(member_id)
	for(var/slot_key in member_slots.Copy())
		var/datum/instrument_band_slot/slot = member_slots[slot_key]
		if(slot?.member_id == member_id)
			member_slots -= slot_key

/datum/instrument_band_lobby/proc/get_active_slots()
	var/list/active_slots = list()
	for(var/slot_key in member_slots.Copy())
		var/datum/instrument_band_slot/slot = member_slots[slot_key]
		if(!slot)
			member_slots -= slot_key
			continue
		var/obj/item/rogue/instrument/instrument = slot.instrument_ref?.resolve()
		if(!instrument || QDELETED(instrument))
			member_slots -= slot_key
			continue
		active_slots += slot
	return active_slots

/datum/instrument_band_lobby/proc/get_title()
	if(owner_name)
		return "[owner_name]'s Band"
	return "Unnamed Band"

/datum/instrument_band_lobby/proc/is_within_range(atom/reference, range = 10)
	if(!reference)
		return FALSE
	var/turf/reference_turf = get_turf(reference)
	if(!reference_turf)
		return FALSE
	for(var/datum/instrument_band_slot/slot in get_active_slots())
		var/obj/item/rogue/instrument/instrument = slot.instrument_ref?.resolve()
		if(!instrument)
			continue
		if(get_dist(reference_turf, instrument) <= range)
			return TRUE
	return FALSE

/datum/looping_sound/instrument/New(_parent, start_immediately=FALSE, _direct=FALSE, _channel = 0)
	. = ..(_parent, FALSE, _direct, _channel)
	// Instruments can be widespread on the map. Reserve channels only while actively playing.
	if(channel)
		SSsounds.free_datum_channels(src)
		channel = null
	if(start_immediately)
		start()

/datum/looping_sound/instrument/start(atom/on_behalf_of)
	if(!channel)
		channel = SSsounds.reserve_sound_channel(src)
		if(!channel)
			return
	..()

/datum/looping_sound/instrument/stop(null_parent)
	if(channel)
		for(var/client/C in GLOB.clients)
			if(!(src in C.played_loops))
				continue
			var/list/L = C.played_loops[src]
			var/sound/SD = L?["SOUND"]
			var/stop_channel = SD?.channel || channel
			if(C.mob)
				C.mob.stop_sound_channel(stop_channel)
			else
				SEND_SOUND(C, sound(null, repeat = 0, wait = 0, channel = stop_channel))
			C.played_loops -= src
		thingshearing = list()
	. = ..(null_parent)
	if(channel)
		SSsounds.free_datum_channels(src)
		channel = null

/obj/item/rogue/instrument
	name = ""
	desc = ""
	icon = 'icons/roguetown/items/music.dmi'
	icon_state = ""
	slot_flags = ITEM_SLOT_HIP|ITEM_SLOT_BACK_R|ITEM_SLOT_BACK_L
	can_parry = TRUE
	force = 23
	throwforce = 7
	throw_range = 4
	var/lastfilechange = 0
	var/curvol = 100
	var/datum/looping_sound/instrument/soundloop
	var/list/song_list = list()
	var/note_color = "#7f7f7f"
	var/groupplaying = FALSE
	var/curfile = ""
	var/playing = FALSE
	grid_height = 64
	grid_width = 32

/obj/item/rogue/instrument/equipped(mob/living/user, slot)
	. = ..()
	if(playing && user.get_active_held_item() != src)
		playing = FALSE
		groupplaying = FALSE
		soundloop.stop()
		user.remove_status_effect(/datum/status_effect/buff/playing_music)

/obj/item/rogue/instrument/getonmobprop(tag)
	. = ..()
	if(tag)
		switch(tag)
			if("gen")
				return list("shrink" = 0.4,"sx" = 0,"sy" = 2,"nx" = 1,"ny" = -4,"wx" = -1,"wy" = 2,"ex" = 7,"ey" = 1,"northabove" = 0,"southabove" = 1,"eastabove" = 1,"westabove" = 0,"nturn" = 0,"sturn" = 0,"wturn" = -2,"eturn" = -2,"nflip" = 8,"sflip" = 8,"wflip" = 8,"eflip" = 0)
			if("onbelt")
				return list("shrink" = 0.3,"sx" = -2,"sy" = -5,"nx" = 4,"ny" = -5,"wx" = 0,"wy" = -5,"ex" = 2,"ey" = -5,"nturn" = 0,"sturn" = 0,"wturn" = 0,"eturn" = 0,"nflip" = 0,"sflip" = 0,"wflip" = 0,"eflip" = 0,"northabove" = 0,"southabove" = 1,"eastabove" = 1,"westabove" = 0)

/obj/item/rogue/instrument/Initialize()
	soundloop = new(src, FALSE)
	. = ..()

/obj/item/rogue/instrument/Destroy()
	qdel(soundloop)
	. = ..()

/obj/item/rogue/instrument/dropped(mob/living/user, silent)
	..()
	groupplaying = FALSE
	playing = FALSE
	if(soundloop)
		soundloop.stop()
		user.remove_status_effect(/datum/status_effect/buff/playing_music)

/obj/item/rogue/instrument/proc/check_file(infile, filename, user)
	var/file_ext = lowertext(copytext(filename, -4))
	var/file_size = length(infile)

	if(file_ext != ".ogg")
		return "SONG MUST BE AN OGG."
	if(file_size > 4 * 1024 * 1024)
		return "TOO BIG. 4 MEGS OR LESS."

	message_admins("[ADMIN_LOOKUPFLW(user)] uploaded a song [filename] of size [file_size / 1000000] (~MB).")
	return null

/obj/item/rogue/instrument/attack_self(mob/living/user)
	var/stressevent = /datum/stressevent/music
	. = ..()
	if(.)
		return
	user.changeNext_move(CLICK_CD_MELEE)
	if(playing)
		playing = FALSE
		groupplaying = FALSE
		soundloop.stop()
		user.remove_status_effect(/datum/status_effect/buff/playing_music)
		return
	else
		var/playdecision = alert(user, "Would you like to start a band?", "Band Play", "Yes", "No")
		switch(playdecision)
			if("Yes")
				groupplaying = TRUE
			if("No")
				groupplaying = FALSE
		if(!groupplaying)
			var/list/options = song_list.Copy()
			if(user.mind && user.get_skill_level(/datum/skill/misc/music) >= 4)
				options["Upload New Song"] = "upload"

			var/choice = input(user, "Which song?", "Music", name) as null|anything in options
			if(!choice || !user)
				return

			if(playing || !(src in user.held_items) || user.get_inactive_held_item())
				return

			if(choice == "Upload New Song")
				if(lastfilechange && world.time < lastfilechange + 3 MINUTES)
					say("NOT YET!")
					return
				playsound(loc, 'sound/misc/beep.ogg', 100, FALSE, -1)
				var/infile = input(user, "CHOOSE A NEW SONG", src) as null|file

				if(!infile)
					return
				if(playing || !(src in user.held_items) || user.get_inactive_held_item())
					return

				var/filename = "[infile]"
				var/file_error = check_file(infile, filename, user)
				if(file_error)
					to_chat(user, span_warning(file_error))
					return

				lastfilechange = world.time
				fcopy(infile,"data/jukeboxuploads/[user.ckey]/[filename]")
				curfile = file("data/jukeboxuploads/[user.ckey]/[filename]")

				var/songname = input(user, "Name your song:", "Song Name") as text|null
				if(songname)
					song_list[songname] = curfile
				return

			curfile = song_list[choice]
			if(!user || playing || !(src in user.held_items))
				return
			if(user.mind)
				switch(user.get_skill_level(/datum/skill/misc/music))
					if(1)
						stressevent = /datum/stressevent/music
						soundloop.stress2give = stressevent
					if(2)
						note_color = "#ffffff"
						stressevent = /datum/stressevent/music/two
						soundloop.stress2give = stressevent
					if(3)
						note_color = "#1eff00"
						stressevent = /datum/stressevent/music/three
						soundloop.stress2give = stressevent
					if(4)
						note_color = "#0070dd"
						stressevent = /datum/stressevent/music/four
						soundloop.stress2give = stressevent
					if(5)
						note_color = "#a335ee"
						stressevent = /datum/stressevent/music/five
						soundloop.stress2give = stressevent
					if(6)
						note_color = "#ff8000"
						stressevent = /datum/stressevent/music/six
						soundloop.stress2give = stressevent
					else
						soundloop.stress2give = stressevent
			if(!(src in user.held_items))
				return
			if(user.get_inactive_held_item())
				playing = FALSE
				soundloop.stop()
				user.remove_status_effect(/datum/status_effect/buff/playing_music)
				return
			if(curfile)
				playing = TRUE
				soundloop.mid_sounds = list(curfile)
				soundloop.cursound = null
				soundloop.start()
				user.apply_status_effect(/datum/status_effect/buff/playing_music, stressevent, note_color)
				record_round_statistic(STATS_SONGS_PLAYED)
			else
				playing = FALSE
				groupplaying = FALSE
				soundloop.stop()
				user.remove_status_effect(/datum/status_effect/buff/playing_music)
		if(groupplaying)
			var/pplnearby =view(7,loc)
			var/list/instrumentsintheband = list()
			var/list/bandmates = list()
			for(var/mob/living/carbon/human/potentialbandmates in pplnearby)
				var/list/thisguyinstrument = list()
				var/obj/item/iteminhand = potentialbandmates.get_active_held_item()
				if(istype(iteminhand, /obj/item/rogue/instrument))
					var/decision = alert(potentialbandmates, "Would you like to perform in a band?", "Band Play", "Yes", "No")
					switch(decision)
						if("No")
							return
						else
							bandmates += potentialbandmates
							instrumentsintheband += iteminhand
							thisguyinstrument += iteminhand
							for(var/obj/item/rogue/instrument/bandinstrumentspersonal in thisguyinstrument)
								if(bandinstrumentspersonal.playing)
									return
								bandinstrumentspersonal.curfile = input(potentialbandmates, "Which song shall [potentialbandmates] perform?", "Music", name) as null|anything in bandinstrumentspersonal.song_list
								bandinstrumentspersonal.curfile = bandinstrumentspersonal.song_list[bandinstrumentspersonal.curfile]
			if(do_after(user, 1))
				for(var/obj/item/rogue/instrument/bandinstrumentsband in instrumentsintheband)
					if(!curfile)
						return
					bandinstrumentsband.playing = TRUE
					bandinstrumentsband.groupplaying = TRUE
					bandinstrumentsband.soundloop.mid_sounds = bandinstrumentsband.curfile
					bandinstrumentsband.soundloop.cursound = null
					bandinstrumentsband.soundloop.start()
					for(var/mob/living/carbon/human/A in bandmates)
						A.apply_status_effect(/datum/status_effect/buff/playing_music, stressevent, note_color)

/obj/item/rogue/instrument/lute
	name = "lute"
	desc = "Its graceful curves were designed to weave joyful melodies."
	icon_state = "lute"
	song_list = list("A Knight's Return" = 'sound/music/instruments/lute (1).ogg',
	"Amongst Fare Friends" = 'sound/music/instruments/lute (2).ogg',
	"The Road Traveled by Few" = 'sound/music/instruments/lute (3).ogg',
	"Tip Thine Tankard" = 'sound/music/instruments/lute (4).ogg',
	"A Reed On the Wind" = 'sound/music/instruments/lute (5).ogg',
	"Jests On Steel Ears" = 'sound/music/instruments/lute (6).ogg',
	"Merchant in the Mire" = 'sound/music/instruments/lute (7).ogg',
	"The Power" = 'sound/music/instruments/lute (8).ogg', //Baldur's Gate 3 Song
	"Bard Dance" = 'sound/music/instruments/lute (9).ogg', //Baldur's Gate 3 Song
	"Old Time Battles" = 'sound/music/instruments/lute (10).ogg') //Baldur's Gate 3 Song

/obj/item/rogue/instrument/accord
	name = "accordion"
	desc = "A harmonious vessel of nostalgia and celebration."
	icon_state = "accordion"
	song_list = list("Her Healing Tears" = 'sound/music/instruments/accord (1).ogg',
	"Peddler's Tale" = 'sound/music/instruments/accord (2).ogg',
	"We Toil Together" = 'sound/music/instruments/accord (3).ogg',
	"Just One More, Tavern Wench" = 'sound/music/instruments/accord (4).ogg',
	"Moonlight Carnival" = 'sound/music/instruments/accord (5).ogg',
	"'Ye Best Be Goin'" = 'sound/music/instruments/accord (6).ogg',
	"Beloved Blue" = 'sound/music/instruments/accord (7).ogg')

/obj/item/rogue/instrument/guitar
	name = "guitar"
	desc = "This is a guitar, chosen instrument of wanderers and the heartbroken." // YIPPEE I LOVE GUITAR
	icon_state = "guitar"
	song_list = list("Fire-Cast Shadows" = 'sound/music/instruments/guitar (1).ogg',
	"The Forced Hand" = 'sound/music/instruments/guitar (2).ogg',
	"Regrets Unpaid" = 'sound/music/instruments/guitar (3).ogg',
	"'Took the Mammon and Ran'" = 'sound/music/instruments/guitar (4).ogg',
	"Poor Man's Tithe" = 'sound/music/instruments/guitar (5).ogg',
	"In His Arms Ye'll Find Me" = 'sound/music/instruments/guitar (6).ogg',
	"El Odio" = 'sound/music/instruments/guitar (7).ogg',
	"Danza De Las Lanzas" = 'sound/music/instruments/guitar (8).ogg',
	"The Feline, Forever Returning" = 'sound/music/instruments/guitar (9).ogg',
	"El Beso Carmesí" = 'sound/music/instruments/guitar (10).ogg',
	"The Queen's High Seas" = 'sound/music/instruments/guitar (11).ogg',
	"Harsh Testimony" = 'sound/music/instruments/guitar (12).ogg',
	"Someone Fair" = 'sound/music/instruments/guitar (13).ogg',
	"Daisies in Bloom" = 'sound/music/instruments/guitar (14).ogg')

/obj/item/rogue/instrument/harp
	name = "harp"
	desc = "A harp of elven craftsmanship."
	icon_state = "harp"
	song_list = list("Through Thine Window, He Glanced" = 'sound/music/instruments/harb (1).ogg',
	"The Lady of Red Silks" = 'sound/music/instruments/harb (2).ogg',
	"Eora Doth Watches" = 'sound/music/instruments/harb (3).ogg',
	"On the Breeze" = 'sound/music/instruments/harb (4).ogg',
	"Never Enough" = 'sound/music/instruments/harb (5).ogg',
	"Sundered Heart" = 'sound/music/instruments/harb (6).ogg',
	"Corridors of Time" = 'sound/music/instruments/harb (7).ogg',
	"Determination" = 'sound/music/instruments/harb (8).ogg')

/obj/item/rogue/instrument/flute
	name = "flute"
	desc = "A row of slender hollow tubes of varying lengths that produce a light airy sound when blown across."
	icon_state = "flute"
	song_list = list("Half-Dragon's Ten Mammon" = 'sound/music/instruments/flute (1).ogg',
	"'The Local Favorite'" = 'sound/music/instruments/flute (2).ogg',
	"Rous in the Cellar" = 'sound/music/instruments/flute (3).ogg',
	"Her Boots, So Incandescent" = 'sound/music/instruments/flute (4).ogg',
	"Moondust Minx" = 'sound/music/instruments/flute (5).ogg',
	"Quest to the Ends" = 'sound/music/instruments/flute (6).ogg',
	"Spit Shine" = 'sound/music/instruments/flute (7).ogg',
	"The Power" = 'sound/music/instruments/flute (8).ogg', //Baldur's Gate 3 Song
	"Bard Dance" = 'sound/music/instruments/flute (9).ogg', //Baldur's Gate 3 Song
	"Old Time Battles" = 'sound/music/instruments/flute (10).ogg') //Baldur's Gate 3 Song

/obj/item/rogue/instrument/drum
	name = "drum"
	desc = "Fashioned from taut skins across a sturdy frame, pulses like a giant heartbeat."
	icon_state = "drum"
	song_list = list("Barbarian's Moot" = 'sound/music/instruments/drum (1).ogg',
	"Muster the Wardens" = 'sound/music/instruments/drum (2).ogg',
	"The Earth That Quakes" = 'sound/music/instruments/drum (3).ogg',
	"The Power" = 'sound/music/instruments/drum (4).ogg', //BG3 Song
	"Bard Dance" = 'sound/music/instruments/drum (5).ogg', // BG3 Song
	"Old Time Battles" = 'sound/music/instruments/drum (6).ogg') // BG3 Song

/obj/item/rogue/instrument/hurdygurdy
	name = "hurdy-gurdy"
	desc = "A knob-driven, wooden string instrument that reminds you of the oceans far."
	icon_state = "hurdygurdy"
	song_list = list("Ruler's One Ring" = 'sound/music/instruments/hurdy (1).ogg',
	"Tangled Trod" = 'sound/music/instruments/hurdy (2).ogg',
	"Motus" = 'sound/music/instruments/hurdy (3).ogg',
	"Becalmed" = 'sound/music/instruments/hurdy (4).ogg',
	"The Bloody Throne" = 'sound/music/instruments/hurdy (5).ogg',
	"We Shall Sail Together" = 'sound/music/instruments/hurdy (6).ogg')

/obj/item/rogue/instrument/viola
	name = "viola"
	desc = "The prim and proper Viola, every prince's first instrument taught."
	icon_state = "viola"
	song_list = list("Far Flung Tale" = 'sound/music/instruments/viola (1).ogg',
	"G Major Cello Suite No. 1" = 'sound/music/instruments/viola (2).ogg',
	"Ursine's Home" = 'sound/music/instruments/viola (3).ogg',
	"Mead, Gold and Blood" = 'sound/music/instruments/viola (4).ogg',
	"Gasgow's Reel" = 'sound/music/instruments/viola (5).ogg',
	"The Power" = 'sound/music/instruments/viola (6).ogg', //BG3 Song, I KNOW THIS ISNT A VIOLIN, LEAVE ME ALONE
	"Bard Dance" = 'sound/music/instruments/viola (7).ogg', // BG3 Song
	"Old Time Battles" = 'sound/music/instruments/viola (8).ogg') // BG3 Song


/obj/item/rogue/instrument/vocals
	name = "vocalist's talisman"
	desc = "This talisman emanates a soft shimmer of light. When held, it can amplify and even change a bard's voice."
	icon_state = "vtalisman"
	song_list = list("Harpy's Call (Feminine)" = 'sound/music/instruments/vocalsf (1).ogg',
	"Necra's Lullaby (Feminine)" = 'sound/music/instruments/vocalsf (2).ogg',
	"Death Touched Aasimar (Feminine)" = 'sound/music/instruments/vocalsf (3).ogg',
	"Our Mother, Our Divine (Feminine)" = 'sound/music/instruments/vocalsf (4).ogg',
	"Wed, Forever More (Feminine)" = 'sound/music/instruments/vocalsf (5).ogg',
	"Paper Boats (Feminine + Vocals)" = 'sound/music/instruments/vocalsf (6).ogg',
	"The Dragon's Blood Surges (Masculine)" = 'sound/music/instruments/vocalsm (1).ogg',
	"Timeless Temple (Masculine)" = 'sound/music/instruments/vocalsm (2).ogg',
	"Angel's Earnt Halo (Masculine)" = 'sound/music/instruments/vocalsm (3).ogg',
	"A Fabled Choir (Masculine)" = 'sound/music/instruments/vocalsm (4).ogg',
	"A Pained Farewell (Masculine + Feminine)" = 'sound/music/instruments/vocalsx (1).ogg',
	"The Power (Whistling)" = 'sound/music/instruments/vocalsx (2).ogg',
	"Bard Dance (Whistling)" = 'sound/music/instruments/vocalsx (3).ogg',
	"Old Time Battles (Whistling)" = 'sound/music/instruments/vocalsx (4).ogg')

/obj/item/rogue/instrument/shamisen
	name = "shamisen"
	desc = "The shamisen, or simply «three strings», is an kazengunese stringed instrument with a washer, which is usually played with the help of a bachi."
	icon_state = "shamisen"
	lefthand_file = 'icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items_righthand.dmi'
	song_list = list(
	"A Rambling Tongue" = 'sound/music/instruments/shamisen A Rambling Tongue.ogg',
	"Ashitaka" = 'sound/music/instruments/shamisen The Legend of Ashitaka.ogg',
	"Daimyo Dreamwalker" = 'sound/music/instruments/shamisen Daimyo Dreamwalker.ogg',
	"Emperor of Flame" = 'sound/music/instruments/shamisen Emperor of Flame.ogg',
	"Fire Phoenix" = 'sound/music/instruments/shamisen Fire Phoenix.ogg',
	"Kaiju Islands" = 'sound/music/instruments/shamisen Kaiju Islands.ogg',
	"Lavender Village" = 'sound/music/instruments/shamisen Lavender Village.ogg',
	"Morning Is Coming" = 'sound/music/instruments/shamisen Morning Is Coming.ogg',
	"Pouncing Shadow" = 'sound/music/instruments/shamisen Pouncing Shadow.ogg',
	"Rising Sun" = 'sound/music/instruments/shamisen Rising Sun.ogg',
	"Those Who Fight" = 'sound/music/instruments/shamisen Those Who Fight.ogg',
	"Village in the Mountains" = 'sound/music/instruments/shamisen Village in the Mountains.ogg',
	"Winning the Soul" = 'sound/music/instruments/shamisen Winning the Soul.ogg',
	"Cursed Apple" = 'sound/music/instruments/shamisen (1).ogg',
	"Fire Dance" = 'sound/music/instruments/shamisen (2).ogg',
	"Lute" = 'sound/music/instruments/shamisen (3).ogg',
	"Tsugaru Ripple" = 'sound/music/instruments/shamisen (4).ogg',
	"Tsugaru" = 'sound/music/instruments/shamisen (5).ogg',
	"Season" = 'sound/music/instruments/shamisen (6).ogg',
	"Parade" = 'sound/music/instruments/shamisen (7).ogg',
	"Koshiro" = 'sound/music/instruments/shamisen (8).ogg')



/obj/item/rogue/instrument/psyaltery
	name = "psyaltery"
	desc = "A traditional form of boxed zither or box-harp that may be played plucked, with a plectrum or with hammers. They are particularly associated with divine beings, aasimars and liturgies."
	icon_state = "psyaltery"
	song_list = list(
	"Disciples Tower" = 'sound/music/instruments/psyaltery (1).ogg',
	"Green Sleeves" = 'sound/music/instruments/psyaltery (2).ogg',
	"Midyear Melancholy" = 'sound/music/instruments/psyaltery (3).ogg',
	"Santa Psydonia" = 'sound/music/instruments/psyaltery (4).ogg',
	"Le Venardine" = 'sound/music/instruments/psyaltery (5).ogg',
	"Azurea Fair" = 'sound/music/instruments/psyaltery (6).ogg',
	"Amoroso" = 'sound/music/instruments/psyaltery (7).ogg',
	"Lupian's Lullaby" = 'sound/music/instruments/psyaltery (8).ogg',
	"White Wine Before Breakfast" = 'sound/music/instruments/psyaltery (9).ogg',
	"Chevalier de Naledi" = 'sound/music/instruments/psyaltery (10).ogg')
