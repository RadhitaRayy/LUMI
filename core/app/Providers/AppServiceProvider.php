<?php

namespace App\Providers;

use App\Llm\ChatDriver;
use App\Llm\PrismChatDriver;
use Carbon\CarbonImmutable;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Date;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Validation\Rules\Password;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // LLM Gateway driver; tests swap in App\Llm\FakeChatDriver.
        $this->app->bind(ChatDriver::class, PrismChatDriver::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->configureDefaults();
        $this->configureRateLimiting();
    }

    /**
     * Rate limits for the mobile API (see routes/api.php).
     */
    protected function configureRateLimiting(): void
    {
        // Sign in / sign up: per IP, plus per email to slow down password guessing.
        RateLimiter::for('api-auth', fn (Request $request) => [
            Limit::perMinute(20)->by('ip:'.$request->ip()),
            Limit::perMinute(5)->by('email:'.strtolower((string) $request->input('email'))),
        ]);

        // Entering or requesting codes.
        RateLimiter::for('api-codes', fn (Request $request) => [
            Limit::perMinute(10)->by('ip:'.$request->ip()),
            Limit::perMinute(5)->by('who:'.($request->user()->id ?? strtolower((string) $request->input('email')))),
        ]);

        // Chat messages: burst protection for both platform and user keys.
        RateLimiter::for('api-chat', fn (Request $request) => Limit::perMinute(20)->by('chat:'.$request->user()?->id));

        // Saving/testing a personal AI key calls the provider, so keep it slow.
        RateLimiter::for('api-ai-key', fn (Request $request) => Limit::perMinute(5)->by('ai-key:'.$request->user()?->id));

        // Resending the verification email: once a minute per user.
        RateLimiter::for('api-resend', fn (Request $request) => Limit::perMinute(1)->by('resend:'.$request->user()?->id));
    }

    /**
     * Configure default behaviors for production-ready applications.
     */
    protected function configureDefaults(): void
    {
        Date::use(CarbonImmutable::class);

        DB::prohibitDestructiveCommands(
            app()->isProduction(),
        );

        Password::defaults(fn (): ?Password => app()->isProduction()
            ? Password::min(12)
                ->mixedCase()
                ->letters()
                ->numbers()
                ->symbols()
                ->uncompromised()
            : null,
        );
    }
}
