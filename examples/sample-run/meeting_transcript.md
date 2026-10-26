[00:00 - 00:14] Tech lead: Yes, I think it's already recording. OK, so as far as I understand, we need to build something for the back office, which is... this thing here...
(The tech lead starts sharing their screen)

[00:15 - 00:43] Tech lead: ...we need to build... actually I need to share it... Can you see it?

[00:44 - 00:44] Developer: Yes.

[00:45 - 01:00] Tech lead: So in the back office we need to build an audit history, similar to the one that already exists in reference-app. Here in reference-app, on this button... and the logs are shown.

[01:01 - 01:45] Tech lead: As far as I understand, they have to be understandable to an ordinary user, meaning in plain language. For example, like here: "discount-10 was added", "was deleted" and so on. In our case, for example... the most complex one would be that the status of an item on some order was updated, and, say, the status changed from "on hold" to "pending" or something like that.

[01:46 - 02:07] Tech lead: So, now, as far as I understand, the fields... we shouldn't log every single user action, only specific things. In this case one of them is the update of the order item status. Right?

[02:08 - 02:09] Developer: Yes.

[02:10 - 02:45] Tech lead: OK. So, for example, here I've selected a store, a group, this order. The update is here: if we cancel it, then it... it changes. In this case both the order status and the status of that specific item will change. And here, when I restore it, it changes again, from cancelled back to pending. And if I fulfil it... when it changes to fulfilled... we log that as well. That's the first one.

[02:46 - 03:10] Tech lead: Next, creating a group. Here from... create group, right, right... we log that too. We also have a function for importing external groups, so we need to do that one as well.

[03:11 - 03:29] Tech lead: Updating a group. Meaning, if we change, for example, the order type here from retail... to retail and wholesale... that also gets logged. Deleting the group...

[03:30 - 03:50] Tech lead: Creating a store. Here, in the backend it's a store, but in the interface it's a shop. Creating, deleting and updating a store.

[03:51 - 04:37] Tech lead: And as far as I understand, those are the main things we need to log. And all of this has to happen after we've already done... after it's absolutely clear that the record itself has been created in the database. Or deleted, or whatever is done to that specific record. The log has to happen on a clear manipulation in the database, not log something in advance and then it's not clear whether something will go wrong and it won't reach the database.

[04:38 - 05:04] Tech lead: And here we'll most likely have to play with Doctrine's features... and we have to avoid unnecessary connections to the database, constant opening and closing of connections and so on.

[05:05 - 05:20] Tech lead: And... anything you'd like to add? In general, right, I assume we should look at reference-app for roughly the logging principle. So the code there needs to be reviewed.

[05:21 - 05:22] Developer: Yes.

[05:23 - 06:10] Tech lead: But yes, for the frontend the important thing is... here next to "extend all", on the right side, one small button just like this one needs to be added... and in the same way it should open a window like this one, which on this side shows... in plain text what happened, and here the date, plus who made... which user made the change. The middle field here doesn't concern us, because it's specific to reference-app. But in general this has to be followed as the standard in the frontend.

[06:11 - 06:22] Tech lead: And for the backend we've already discussed what needs to be done. I think those are roughly the things that need to happen.

[06:23 - 06:25] Developer: Yes, great.

[06:26 - 06:29] Tech lead: OK, so if there's nothing else, let's go.

[06:30 - 06:31] Developer: Yes, let's go.

[06:32 - 06:35] Tech lead: Well, good, OK then.