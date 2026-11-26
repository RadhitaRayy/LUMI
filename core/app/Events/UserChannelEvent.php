<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * Something every device of one user should know about, sent on "private-user.{id}".
 *
 * The payload is built when the event is created (not when the queue sends it), so a later
 * change or delete cannot make the broadcast fail or show newer data than the moment it describes.
 */
abstract class UserChannelEvent implements ShouldBroadcast, ShouldDispatchAfterCommit
{
    use Dispatchable, InteractsWithSockets;

    /**
     * @param  array<string, mixed>  $payload
     */
    public function __construct(
        public readonly int $userId,
        public readonly array $payload,
    ) {}

    /** Event name the app listens for, e.g. "conversation.created". */
    abstract public function broadcastAs(): string;

    public function broadcastOn(): PrivateChannel
    {
        return new PrivateChannel("user.{$this->userId}");
    }

    /** @return array<string, mixed> */
    public function broadcastWith(): array
    {
        return $this->payload;
    }
}
