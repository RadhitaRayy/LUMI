<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Platform AI providers (BYOK of the owner), managed from Lumi Console.
        Schema::create('llm_providers', function (Blueprint $table) {
            $table->id();
            $table->string('name', 60);
            $table->string('driver', 30); // openrouter | openai_compatible
            $table->string('base_url')->nullable();
            $table->text('api_key')->nullable(); // encrypted cast
            $table->boolean('is_enabled')->default(true);
            $table->timestamps();
        });

        Schema::create('llm_models', function (Blueprint $table) {
            $table->id();
            $table->foreignId('llm_provider_id')->constrained()->cascadeOnDelete();
            $table->string('model_id', 150);
            $table->string('label', 80);
            $table->boolean('is_default')->default(false);
            $table->boolean('supports_tools')->default(false);
            $table->boolean('is_enabled')->default(true);
            $table->timestamps();

            $table->unique(['llm_provider_id', 'model_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('llm_models');
        Schema::dropIfExists('llm_providers');
    }
};
