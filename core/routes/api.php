<?php

use App\Http\Controllers\Api\V1\AiKeyController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\ConversationController;
use App\Http\Controllers\Api\V1\DeviceController;
use App\Http\Controllers\Api\V1\EmailVerificationController;
use App\Http\Controllers\Api\V1\MeController;
use App\Http\Controllers\Api\V1\MemoryController;
use App\Http\Controllers\Api\V1\MessageController;
use App\Http\Controllers\Api\V1\NoteController;
use App\Http\Controllers\Api\V1\PasswordResetController;
use App\Http\Controllers\Api\V1\PersonaController;
use Illuminate\Support\Facades\Route;

/*
| Lumi App API (mobile). Every route lives under /api/v1.
| Errors are JSON: { "code": "...", "message": "..." }.
*/

Route::prefix('v1')->group(function () {
    // Public health check for the app's server connection tester
    Route::get('health', fn () => response()->json([
        'status' => 'ok',
        'app' => 'Lumi Core',
        'time' => now()->toIso8601String(),
    ]))->middleware('throttle:60,1');

    // Guests
    Route::middleware('throttle:api-auth')->group(function () {
        Route::post('auth/register', [AuthController::class, 'register']);
        Route::post('auth/login', [AuthController::class, 'login']);
    });

    Route::middleware('throttle:api-codes')->group(function () {
        Route::post('auth/password/forgot', [PasswordResetController::class, 'forgot']);
        Route::post('auth/password/reset', [PasswordResetController::class, 'reset']);
    });

    // Signed-in devices
    Route::middleware(['auth:sanctum', 'not-blocked'])->group(function () {
        Route::post('auth/logout', [AuthController::class, 'logout']);

        Route::post('auth/email/verify', [EmailVerificationController::class, 'verify'])
            ->middleware('throttle:api-codes');
        Route::post('auth/email/resend', [EmailVerificationController::class, 'resend'])
            ->middleware('throttle:api-resend');

        Route::get('me', [MeController::class, 'show']);
        Route::patch('me', [MeController::class, 'update']);
        Route::put('me/password', [MeController::class, 'updatePassword']);
        Route::get('me/persona', [PersonaController::class, 'show']);
        Route::put('me/persona', [PersonaController::class, 'update']);

        Route::get('devices', [DeviceController::class, 'index']);
        Route::delete('devices/{device}', [DeviceController::class, 'destroy'])->whereNumber('device');

        // Kunci AI saya (hybrid BYOK)
        Route::get('me/ai-key', [AiKeyController::class, 'show']);
        Route::put('me/ai-key', [AiKeyController::class, 'upsert'])->middleware('throttle:api-ai-key');
        Route::post('me/ai-key/test', [AiKeyController::class, 'test'])->middleware('throttle:api-ai-key');
        Route::patch('me/ai-key', [AiKeyController::class, 'update']);
        Route::delete('me/ai-key', [AiKeyController::class, 'destroy']);

        // Chat (needs a verified email when the platform requires it)
        Route::middleware('verified.api')->group(function () {
            Route::get('conversations', [ConversationController::class, 'index']);
            Route::post('conversations', [ConversationController::class, 'store']);
            Route::get('conversations/{conversation}', [ConversationController::class, 'show']);
            Route::patch('conversations/{conversation}', [ConversationController::class, 'update']);
            Route::delete('conversations/{conversation}', [ConversationController::class, 'destroy']);
            Route::post('conversations/{conversation}/messages', [MessageController::class, 'store'])
                ->middleware('throttle:api-chat');

            // Agent memory & personal notes
            Route::get('memories', [MemoryController::class, 'index']);
            Route::post('memories', [MemoryController::class, 'store']);
            Route::patch('memories/{memory}', [MemoryController::class, 'update']);
            Route::delete('memories/{memory}', [MemoryController::class, 'destroy']);

            Route::get('notes', [NoteController::class, 'index']);
            Route::post('notes', [NoteController::class, 'store']);
            Route::patch('notes/{note}', [NoteController::class, 'update']);
            Route::delete('notes/{note}', [NoteController::class, 'destroy']);
        });
    });
});
