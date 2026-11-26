<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Single-row table holding platform settings editable from Lumi Console.
        Schema::create('app_settings', function (Blueprint $table) {
            $table->id();
            $table->boolean('registration_open')->default(true);
            $table->boolean('require_email_verification')->default(true);
            $table->unsignedInteger('default_daily_quota')->default(30);
            $table->text('system_prompt')->nullable();
            $table->timestamps();
        });

        DB::table('app_settings')->insert([
            'registration_open' => true,
            'require_email_verification' => true,
            'default_daily_quota' => 30,
            'system_prompt' => 'Kamu adalah Lumi, asisten pribadi yang ramah dan ringkas. Jawab dalam bahasa yang dipakai pengguna.',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('app_settings');
    }
};
