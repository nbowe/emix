emix: An Erlang library for interacting with mixpanel
=============================================

For more details on the mixpanel API see the [mixpanel docs](http://mixpanel.com/api/docs/.)

The primary function is emix:track/2. 
This takes an event name and property list and returns true if mixpanel recorded the event, and false if it didnt.

This library requires mochiweb.

Sending an event
----------------
You will want to send "distinct_id", "token", and "time" properties at a minimum.
Something like:

	Logged = emix:track("game_completed", [
		{"distinct_id", UID},
		{"token", ?TOKEN},
		{"time", emix:unixtime() }
	]),


Sending an event asynchronously
-------------------------------
If you do not care whether the event is recorded or not you can use emix:track_asynch/2.

Alternatively you can spawn a process that calls emix:track/2.
In this way you can record stats on successful and unsuccessful events.
For example I use something like the following:

	record_event(UID, EventName, Properties) ->
		spawn( fun() ->
			CommonProperties = [
				{"distinct_id", UID},
				{"token", ?TOKEN},
				{"time", emix:unixtime() }
			],
			% ensure we use the CommonProperties over any passed in.
			AllProperties = lists:ukeymerge(1,
				lists:ukeysort(1, CommonProperties),
				lists:ukeysort(1, Properties)
			),
			Logged = emix:track(EventName, AllProperties),
			case Logged of
				false -> estat:update(mixpanel_failed_events);
				true -> estat:update(mixpanel_events)
			end
		end),
		ok.



