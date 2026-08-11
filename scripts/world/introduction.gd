class_name Introduction
extends RefCounted
## The scene that plays in the yard when somebody new has arrived: Aldric turns,
## says who they are, they answer, and the camera looks where he is looking.
##
## Three pieces, none of which knows about the other two:
##
##   * `StoryDb.INTRODUCTIONS` -- the words, and whose they are.
##   * `DialogueBox.open_scene` -- the box. It types the pages and announces the
##     speaker; it has never heard of a camera.
##   * `ConvoCamera` -- the shot. It turns to a `Node3D`; it has never heard of
##     the dialogue system.
##
## **This file is the twenty lines that join them**, and it is a `RefCounted` with
## one static coroutine rather than a node, because there is no state to keep: the
## scene either finishes or the box goes away, and both end here.
##
## ## Why the flag is set on `finished` and not on the last page
##
## Escaping out of an introduction still leaves you standing in a yard with a new
## person in it, so replaying it on the next visit would be a cutscene you cannot
## refuse. That is the opposite of the elder's briefing, which is INFORMATION and
## is still owed if you skipped it (`DialogueBox.open`'s `on_read`). Two kinds of
## text, two rules, on purpose.
##
## ## What happens with no camera
##
## `ConvoCamera.stage` returns null in any scene with no hero in it -- a lookdev
## harness, a lobby -- and the words still play. A conversation that refused to
## happen because the shot could not be set up would fail closed in exactly the
## place a director is trying to read the text.


## Play the introduction for `who`, and mark it seen. Awaits the whole scene, so
## a caller with several pending can simply loop.
static func play(host: Node, who: StringName) -> void:
	var lines := StoryDb.introduction(who)
	if lines.is_empty():
		# Somebody arrived that nobody wrote a scene for. Mark them met anyway --
		# the alternative is a yard that tries to introduce them on every single
		# return home, forever.
		StoryDb.mark_introduced(who)
		return

	var box := DialogueBox.open_scene(host, lines)
	if box == null:
		StoryDb.mark_introduced(who)
		return

	var cam := ConvoCamera.stage(host)
	if cam != null:
		# The FIRST framing is read off the box rather than waited for. `_ready`
		# runs inside `add_child` and has already shown page one by the time
		# `open_scene` returns, so `speaker_changed` for the opening line fired
		# before this line could possibly have connected to it -- see the note on
		# `DialogueBox._stage`. Every LATER change is a signal.
		_aim(cam, host, box.speaker)
		box.speaker_changed.connect(func(s: StringName) -> void: _aim(cam, host, s))

	await box.finished
	# `finished` comes out of `_exit_tree`, so the box is on its way out and the
	# camera has to go with it or the yard is left looking at a shopkeeper with no
	# way to move.
	if cam != null and is_instance_valid(cam):
		cam.release()
	StoryDb.mark_introduced(who)


## Point the camera at whoever is talking. Silently does nothing for a speaker
## with no body in this scene -- the narrator has lines and no legs, and a
## conversation that named him should keep the frame it had rather than snap to
## the origin.
static func _aim(cam: ConvoCamera, host: Node, who: StringName) -> void:
	var person := person_of(host, who)
	if person == null:
		return
	cam.watch(person, person.head_y())


## The body in this scene belonging to a `StoryDb`/`DialogueDb` person id.
##
## Walks the tree rather than asking `Garrison` for its `smith` field, and that is
## deliberate in both directions: the yard's five fields are null until each
## keeper arrives (`Garrison._build_people`), which is precisely the case this
## system exists to handle, and a harness scene that stands two `Npc`s on a plane
## gets the same lookup for free.
static func person_of(host: Node, who: StringName) -> Npc:
	if who == &"":
		return null
	var scene := host.get_tree().current_scene
	if scene == null:
		return null
	for node: Node in scene.find_children("*", "Npc", true, false):
		var npc := node as Npc
		if npc != null and npc.voice_id() == who:
			return npc
	return null
