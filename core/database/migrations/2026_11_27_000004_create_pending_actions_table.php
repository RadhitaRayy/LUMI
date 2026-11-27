<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pending_actions', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignUlid('conversation_id')->constrained()->cascadeOnDelete();
            $table->foreignUlid('message_id')->constrained()->cascadeOnDelete();
            $table->string('tool_call_id', 120);
            $table->string('tool_name', 64);
            $table->jsonb('arguments')->default('{}');
            $table->string('title', 160);
            $table->text('summary');
            $table->text('continuation'); // encrypted JSON state to resume the orchestrator loop
            $table->string('status', 16)->default('pending');
            $table->timestamp('expires_at');
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'status', 'expires_at']);
            $table->index(['conversation_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pending_actions');
    }
};
