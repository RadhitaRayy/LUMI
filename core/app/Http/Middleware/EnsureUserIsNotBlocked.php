<?php

namespace App\Http\Middleware;

use App\Exceptions\ApiException;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserIsNotBlocked
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->user()?->is_blocked) {
            throw new ApiException('account_blocked', 'Akun kamu diblokir. Hubungi admin Lumi.', 403);
        }

        return $next($request);
    }
}
