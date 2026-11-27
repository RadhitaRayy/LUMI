<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tool_policies', function (Blueprint $table) {
            $table->id();
            $table->string('tool_name', 64);
            $table->string('role', 32);
            $table->string('mode', 16)->default('auto');
            $table->boolean('is_enabled')->default(true);
            $table->timestamps();

            $table->unique(['tool_name', 'role']);
        });

        Schema::create('tool_calls', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->foreignUlid('conversation_id')->constrained()->cascadeOnDelete();
            $table->foreignUlid('message_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('tool_name', 64);
            $table->jsonb('arguments')->default('{}');
            $table->text('result_summary')->nullable();
            $table->string('status', 16)->default('ok');
            $table->unsignedInteger('latency_ms')->default(0);
            $table->timestamps();

            $table->index(['message_id', 'created_at']);
            $table->index(['user_id', 'created_at']);
        });

        Schema::create('audit_logs', function (Blueprint $table) {
            $table->ulid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->ulid('conversation_id')->nullable();
            $table->string('tool_name', 64);
            $table->string('mode', 16);
            $table->string('status', 24);
            $table->text('summary')->nullable();
            $table->unsignedInteger('latency_ms')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->index(['user_id', 'created_at']);
            $table->index(['tool_name', 'status', 'created_at']);
        });

        Schema::table('user_ai_keys', function (Blueprint $table) {
            $table->boolean('supports_tools')->default(true)->after('is_active');
        });

        Schema::table('app_settings', function (Blueprint $table) {
            $table->string('web_search_driver', 32)->nullable()->after('system_prompt');
            $table->text('web_search_api_key')->nullable()->after('web_search_driver');
            $table->boolean('web_search_enabled')->default(false)->after('web_search_api_key');
        });
    }

    public function down(): void
    {
        Schema::table('app_settings', function (Blueprint $table) {
            $table->dropColumn(['web_search_driver', 'web_search_api_key', 'web_search_enabled']);
        });

        Schema::table('user_ai_keys', function (Blueprint $table) {
            $table->dropColumn('supports_tools');
        });

        Schema::dropIfExists('audit_logs');
        Schema::dropIfExists('tool_calls');
        Schema::dropIfExists('tool_policies');
    }
};
