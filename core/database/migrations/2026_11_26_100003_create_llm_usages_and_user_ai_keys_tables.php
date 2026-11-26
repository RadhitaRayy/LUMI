<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // One row per AI request, for the Console usage log and quota.
        Schema::create('llm_usages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignUlid('conversation_id')->nullable()->constrained()->nullOnDelete();
            $table->ulid('message_id')->nullable();
            $table->string('key_source', 20); // platform | user
            $table->string('provider', 60);
            $table->string('model', 150);
            $table->unsignedInteger('input_tokens')->default(0);
            $table->unsignedInteger('output_tokens')->default(0);
            $table->unsignedInteger('latency_ms')->default(0);
            $table->string('status', 20); // complete | error | cancelled
            $table->string('error_code', 50)->nullable();
            $table->timestamps();

            $table->index(['user_id', 'created_at']);
            $table->index('created_at');
        });

        // A user's own AI key (hybrid BYOK). At most one per user.
        Schema::create('user_ai_keys', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            $table->string('driver', 30);
            $table->string('base_url')->nullable();
            $table->text('api_key'); // encrypted cast
            $table->string('key_last4', 4);
            $table->string('model_id', 150);
            $table->boolean('is_active')->default(true);
            $table->timestamp('last_validated_at')->nullable();
            $table->text('last_error')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_ai_keys');
        Schema::dropIfExists('llm_usages');
    }
};
