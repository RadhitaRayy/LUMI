<?php

namespace App\Services\Agent;

use App\Models\PendingAction;

final readonly class OrchestratorResult
{
    public function __construct(
        public string $text,
        public int $inputTokens,
        public int $outputTokens,
        public string $status,
        public ?string $errorCode = null,
        public ?PendingAction $pendingAction = null,
    ) {}
}
