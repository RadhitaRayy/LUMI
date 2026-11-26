<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Lumi Console is for the owner only. Sign-in already refuses everyone else; this also covers
 * other ways in (a passkey, a session from before the role changed, a blocked owner).
 */
class EnsureUserIsSuperadmin
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user !== null && $user->isSuperadmin() && ! $user->is_blocked) {
            return $next($request);
        }

        Auth::guard('web')->logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login')->withErrors([
            'email' => 'Lumi Console hanya untuk pemilik (superadmin).',
        ]);
    }
}
