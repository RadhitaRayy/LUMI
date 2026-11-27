<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_memories', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('category', 24)->default('fact');
            $table->string('content', 300);
            $table->string('source', 16)->default('user');
            $table->timestamps();

            $table->index(['user_id', 'updated_at']);
        });

        Schema::create('user_notes', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('title', 120);
            $table->text('content');
            $table->jsonb('tags')->default('[]');
            $table->timestamps();

            $table->index(['user_id', 'updated_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_notes');
        Schema::dropIfExists('user_memories');
    }
};
