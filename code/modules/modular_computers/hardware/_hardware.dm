/obj/item/weapon/computer_hardware/
	name = "Hardware"
	desc = "Unknown Hardware."
	icon = 'icons/obj/modular_components.dmi'
	var/obj/item/modular_computer/holder2 = null
	var/power_usage = 0 			// If the hardware uses extra power, change this.
	var/enabled = 1					// If the hardware is turned off set this to 0.
	var/critical = 1				// Prevent disabling for important component, like the HDD.
	var/hardware_size = 1			// Limits which devices can contain this component. 1: Tablets/Laptops/Consoles, 2: Laptops/Consoles, 3: Consoles only
	var/damage = 0					// Current damage level
	var/max_damage = 100			// Maximal damage level.
	var/damage_malfunction = 20		// "Malfunction" threshold. When damage exceeds this value the hardware piece will semi-randomly fail and do !!FUN!! things
	var/damage_failure = 50			// "Failure" threshold. When damage exceeds this value the hardware piece will not work at all.
	var/malfunction_probability = 10// Chance of malfunction when the component is damaged
	var/usage_flags = PROGRAM_ALL

/obj/item/weapon/computer_hardware/attackby(var/obj/item/W as obj, var/mob/living/user as mob)
	// Multitool. Runs diagnostics
	if(isMultitool(W))
		to_chat(user, "***** DIAGNOSTICS REPORT *****")
		diagnostics(user)
		to_chat(user, "******************************")
		return 1
	// Nanopaste. Repair all damage if present for a single unit.
	var/obj/item/stack/S = W
	if(istype(S, /obj/item/stack/nanopaste))
		if(!damage)
			to_chat(user, "\The [src] doesn't seem to require repairs.")
			return 1
		if(S.use(1))
			to_chat(user, "You apply a bit of \the [W] to \the [src]. It immediately repairs all damage.")
			damage = 0
		return 1
	// Cable coil. Works as repair method, but will probably require multiple applications and more cable.
	if(isCoil(S))
		if(!damage)
			to_chat(user, "\The [src] doesn't seem to require repairs.")
			return 1
		if(S.use(1))
			to_chat(user, "You patch up \the [src] with a bit of \the [W].")
			take_damage(-10)
		return 1
	return ..()


// Called on multitool click, prints diagnostic information to the user.
/obj/item/weapon/computer_hardware/proc/diagnostics(var/mob/user)
	to_chat(user, "Hardware Integrity Test... (Corruption: [damage]/[max_damage]) [damage > damage_failure ? "FAIL" : damage > damage_malfunction ? "WARN" : "PASS"]")

/obj/item/weapon/computer_hardware/New(var/obj/L)
	.=..()
	w_class = hardware_size
	if(istype(L, /obj/item/modular_computer))
		holder2 = L
		return

/obj/item/weapon/computer_hardware/Destroy()
	holder2 = null
	return ..()

// Handles damage checks
/obj/item/weapon/computer_hardware/proc/check_functionality()
	// Turned off
	if(!enabled)
		return 0
	// Too damaged to work at all.
	if(damage >= damage_failure)
		return 0
	// Still working. Well, sometimes...
	if(damage >= damage_malfunction)
		if(prob(malfunction_probability))
			return 0
	// Good to go.
	return 1

/obj/item/weapon/computer_hardware/examine(var/mob/user)
	. = ..()
	if(damage > damage_failure)
		to_chat(user, "<span class='danger'>It seems to be severely damaged!</span>")
	else if(damage > damage_malfunction)
		to_chat(user, "<span class='notice'>It seems to be damaged!</span>")
	else if(damage)
		to_chat(user, "It seems to be slightly damaged.")

// Damages the component. Contains necessary checks. Negative damage "heals" the component.
/obj/item/weapon/computer_hardware/take_damage(var/amount)
	damage += round(amount) 					// We want nice rounded numbers here.
	damage = between(0, damage, max_damage)		// Clamp the value.

// This is called whenever hardware is inserted into a modular computer.
// Currently only has a use for 'manual' flash drives
/obj/item/weapon/computer_hardware/proc/installed(var/obj/item/modular_computer/M)
	if(istype(src, /obj/item/weapon/computer_hardware/hard_drive/portable/manual))
		//Define the src as a portable flash drive
		var/obj/item/weapon/computer_hardware/hard_drive/portable/flash = src
		//Find the word processor
		var/datum/computer_file/program/wordprocessor/WP = M.hard_drive.find_file_by_name("wordprocessor")
		//List of added programs
		var/list/addedProgs = list()
		//Find all stored guides in the flash drive and transfer them over
		for(var/datum/computer_file/data/text/manual/F in flash.stored_files)
			//Don't add unnecessary copies
			if(!M.hard_drive.stored_files.Find(F))
				M.hard_drive.store_file(F)
			addedProgs.Add(F.filename)
		//Reset the word processors data in case anything is currently inside it.
		//This generates a 'changelog' to show whats been added
		WP.open_file = "Added files"
		WP.loaded_data = "Files added from \the [src]\[br\]\[list\]"
		for(var/f in addedProgs)
			WP.loaded_data += "- [f]"
		WP.loaded_data += "\[/list\]"
		usr.audible_message("\The [src] beeps and flashes as it transfers [flash.stored_files.len > 1 ? "several files" : "a file"] to \the [usr]'s \the [M]",
							"\The [src] beeps and flashes as it transfers [flash.stored_files.len > 1 ? "several files" : "a file"] to \the [M]")
		M.portable_drive = null
		if(!usr.put_in_hands(src))
			M.uninstall_component(null, src)
		M.run_program("wordprocessor")