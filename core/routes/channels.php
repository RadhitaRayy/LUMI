<?php

use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

/*
| Each user has one private channel; every device signed in to that account subscribes to it
| (as "private-user.{id}") and receives conversation, message and session events.
*/
Broadcast::channel('user.{id}', fn (User $user, string $id) => (string) $user->id === $id);
