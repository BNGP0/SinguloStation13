/*
	Adjacency proc for determining touch range

	This is mostly to determine if a user can enter a square for the purposes of touching something.
	Examples include reaching a square diagonally or reaching something on the other side of a glass window.

	This is calculated by looking for border items, or in the case of clicking diagonally from yourself, dense items.
	This proc will NOT notice if you are trying to attack a window on the other side of a dense object in its turf.  There is a window helper for that.

	Note that in all cases the neighbor is handled simply; this is usually the user's mob, in which case it is up to you
	to check that the mob is not inside of something
*/
/atom/proc/Adjacent(atom/neighbor, atom/target, atom/movable/mover) // basic inheritance, unused
	return

// Not a sane use of the function and (for now) indicative of an error elsewhere
/area/Adjacent(atom/neighbor, atom/target, atom/movable/mover)
	CRASH("Call to /area/Adjacent(), unimplemented proc")


/*
	Adjacency (to turf):
	* If you are in the same turf, always true
	* If you are vertically/horizontally adjacent, ensure there are no border objects
	* If you are diagonally adjacent, ensure you can pass through at least one of the mutually adjacent square.
		* Passing through in this case ignores anything with the LETPASSTHROW pass flag, such as tables, racks, and morgue trays.
*/
/turf/Adjacent(atom/neighbor, atom/target, atom/movable/mover)
	var/turf/T0 = get_turf(neighbor)

	if(T0 == src) //same turf
		return TRUE

	if(get_dist(src, T0) > 1 || z != T0.z) //too far
		return FALSE

	// Non diagonal case
	if(T0.x == x || T0.y == y)
		// Check for border blockages
		return T0.ClickCross(get_dir(T0, src), TRUE, target, mover) && ClickCross(get_dir(src, T0), TRUE, target, mover)

	// Diagonal case
	var/in_dir = get_dir(T0,src) // eg. northwest (1+8) = 9 (00001001)
	var/d1 = in_dir&3		     // eg. north	  (1+8)&3 (0000 0011) = 1 (0000 0001)
	var/d2 = in_dir&12			 // eg. west	  (1+8)&12 (0000 1100) = 8 (0000 1000)

	for(var/d in list(d1,d2))
		if(!T0.ClickCross(d, TRUE, target, mover))
			continue // could not leave T0 in that direction

		var/turf/T1 = get_step(T0,d)
		if(!T1 || T1.density)
			continue
		if(!T1.ClickCross(get_dir(T1, src), FALSE, target, mover) || !T1.ClickCross(get_dir(T1, T0), FALSE, target, mover))
			continue // couldn't enter or couldn't leave T1

		if(!ClickCross(get_dir(src, T1), TRUE, target, mover))
			continue // could not enter src

		return TRUE // we don't care about our own density

	return FALSE

/*
	Adjacency (to anything else):
	* Must be on a turf
*/
/atom/movable/Adjacent(atom/neighbor, atom/target, atom/movable/mover)
	if(neighbor == loc)
		return TRUE
	var/turf/T = loc
	if(!istype(T))
		return FALSE
	if(T.Adjacent(neighbor,target = neighbor, mover = src))
		return TRUE
	return FALSE

// This is necessary for storage items not on your person.
/obj/item/Adjacent(atom/neighbor, atom/target, atom/movable/mover, recurse = 1)
	if(neighbor == loc)
		return TRUE
	if(isitem(loc))
		if(recurse > 0)
			return loc.Adjacent(neighbor, target, mover, recurse - 1)
		return FALSE
	return ..()

/*
	This checks if you there is uninterrupted airspace between that turf and this one.
	This is defined as any dense ON_BORDER_1 object, or any dense object without LETPASSTHROW.
	The border_only flag allows you to not objects (for source and destination squares)
*/
/turf/proc/ClickCross(target_dir, border_only, atom/target, atom/movable/mover)
	for(var/obj/O in src)
		if((mover && O.CanPass(mover, target_dir)) || (!mover && !O.density))
			continue
		if(O == target || O == mover || (O.pass_flags_self & LETPASSTHROW)) //check if there's a dense object present on the turf
			continue // LETPASSTHROW is used for anything you can click through (or the firedoor special case, see above)

		if( O.flags_1&ON_BORDER_1) // windows are on border, check them first
			if( O.dir & target_dir || O.dir & (O.dir-1) ) // full tile windows are just diagonals mechanically
				return FALSE //O.dir&(O.dir-1) is false for any cardinal direction, but true for diagonal ones
		else if( !border_only ) // dense, not on border, cannot pass over
			return FALSE
	return TRUE
