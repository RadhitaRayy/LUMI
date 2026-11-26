<?php

use App\Http\Controllers\Console\DashboardController;
use App\Http\Controllers\Console\LogController;
use App\Http\Controllers\Console\ModelController;
use App\Http\Controllers\Console\ProviderController;
use App\Http\Controllers\Console\SettingsController;
use App\Http\Controllers\Console\UserController;
use Illuminate\Support\Facades\Route;

Route::redirect('/', '/console')->name('home');

// Lumi Console: the owner's dashboard (superadmin only).
Route::middleware(['auth', 'superadmin'])->prefix('console')->name('console.')->group(function () {
    Route::get('/', DashboardController::class)->name('dashboard');

    Route::get('users', [UserController::class, 'index'])->name('users.index');
    Route::patch('users/{user}/quota', [UserController::class, 'updateQuota'])->name('users.quota');
    Route::post('users/{user}/block', [UserController::class, 'block'])->name('users.block');
    Route::delete('users/{user}/block', [UserController::class, 'unblock'])->name('users.unblock');
    Route::delete('users/{user}/devices/{token}', [UserController::class, 'revokeDevice'])
        ->whereNumber('token')->name('users.devices.destroy');

    Route::get('providers', [ProviderController::class, 'index'])->name('providers.index');
    Route::post('providers', [ProviderController::class, 'store'])->name('providers.store');
    Route::patch('providers/{provider}', [ProviderController::class, 'update'])->name('providers.update');
    Route::delete('providers/{provider}', [ProviderController::class, 'destroy'])->name('providers.destroy');
    Route::put('providers/{provider}/key', [ProviderController::class, 'updateKey'])->name('providers.key');
    Route::post('providers/{provider}/test', [ProviderController::class, 'test'])->name('providers.test');
    Route::post('providers/{provider}/models', [ModelController::class, 'store'])->name('models.store');

    Route::patch('models/{model}', [ModelController::class, 'update'])->name('models.update');
    Route::post('models/{model}/default', [ModelController::class, 'makeDefault'])->name('models.default');
    Route::delete('models/{model}', [ModelController::class, 'destroy'])->name('models.destroy');

    Route::get('logs', [LogController::class, 'index'])->name('logs.index');

    Route::get('settings', [SettingsController::class, 'edit'])->name('settings.edit');
    Route::put('settings', [SettingsController::class, 'update'])->name('settings.update');
});

require __DIR__.'/settings.php';
