<?php

namespace App\Http\Middleware;

use App\Exceptions\ApiException;
use App\Models\AppSetting;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Blocks features (like chat) until the email is verified, when the platform requires it.
 */
class EnsureEmailIsVerifiedForApi
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user && ! $user->hasVerifiedEmail() && AppSetting::current()->require_email_verification) {
            throw new ApiException('email_unverified', 'Verifikasi email kamu dulu.', 403);
        }

        return $next($request);
    }
}
