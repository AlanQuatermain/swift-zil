<VERSION ZIP>

<CONSTANT RELEASEID 1>

<OBJECT ROOMS
	(DESC "container for rooms")
	(IN ROOMS)>

<OBJECT LIVING-ROOM
	(IN ROOMS)
	(DESC "living room")
	(LDESC "You are in the living room. There is a doorway to the east.")
	(SYNONYM LIVING ROOM)
	(ADJECTIVE LIVING)
	(EAST TO KITCHEN)
	(PROPERTY LIGHT)>

<OBJECT KITCHEN
	(IN ROOMS)
	(DESC "kitchen")
	(LDESC "You are in the kitchen. There is a doorway to the west.")
	(SYNONYM KITCHEN)
	(WEST TO LIVING-ROOM)
	(PROPERTY LIGHT)>

<OBJECT LANTERN
	(IN LIVING-ROOM)
	(DESC "brass lantern")
	(SYNONYM LANTERN LAMP LIGHT)
	(ADJECTIVE BRASS)
	(PROPERTY TAKEBIT LIGHTBIT)
	(ACTION LANTERN-F)>

<ROUTINE LANTERN-F ()
	<COND (<VERB? TAKE>
	       <MOVE ,LANTERN ,PLAYER>
	       <TELL "Taken." CR>)
	      (<VERB? LIGHT>
	       <COND (<FSET? ,LANTERN ,ONBIT>
		      <TELL "It is already on." CR>)
		     (T
		      <FSET ,LANTERN ,ONBIT>
		      <TELL "The lantern is now on." CR>)>)
	      (<VERB? EXTINGUISH>
	       <COND (<FSET? ,LANTERN ,ONBIT>
		      <FCLEAR ,LANTERN ,ONBIT>
		      <TELL "The lantern is now off." CR>)
		     (T
		      <TELL "It is already off." CR>)>)>>

<ROUTINE LOOK-AROUND ()
	<COND (<EQUAL? ,HERE ,LIVING-ROOM>
	       <TELL "Living Room" CR>
	       <TELL "You are in the living room." CR>
	       <COND (<IN? ,LANTERN ,HERE>
		      <TELL "There is a brass lantern here." CR>)>)
	      (<EQUAL? ,HERE ,KITCHEN>
	       <TELL "Kitchen" CR>
	       <TELL "You are in the kitchen." CR>)>>

<ROUTINE GO (DIR "OPT" (TELL-FLAG T))
	<COND (<EQUAL? ,DIR ,P?EAST>
	       <COND (<EQUAL? ,HERE ,LIVING-ROOM>
		      <SETG HERE ,KITCHEN>
		      <COND (,TELL-FLAG <LOOK-AROUND>)>)
		     (T
		      <TELL "You can't go that way." CR>)>)
	      (<EQUAL? ,DIR ,P?WEST>
	       <COND (<EQUAL? ,HERE ,KITCHEN>
		      <SETG HERE ,LIVING-ROOM>
		      <COND (,TELL-FLAG <LOOK-AROUND>)>)
		     (T
		      <TELL "You can't go that way." CR>)>)
	      (T
	       <TELL "You can't go that way." CR>)>>

<ROUTINE MAIN ()
	<SETG HERE ,LIVING-ROOM>
	<TELL "Simple Adventure Game" CR CR>
	<LOOK-AROUND>
	<REPEAT ()
		<TELL CR ">">
		<CRLF>
		<COND (<EQUAL? 1 1>  ; Always true for now
		       <TELL "Game over." CR>
		       <QUIT>)>>>