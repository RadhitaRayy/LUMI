<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Answers API requests in the language the app asks for with `Accept-Language`.
 * Falls back to the app's default locale when the header names no supported language.
 */
class SetLocaleFromRequest
{
    public function handle(Request $request, Closure $next): Response
    {
        app()->setLocale(self::pick($request));

        return $next($request);
    }

    public static function pick(Request $request): string
    {
        /** @var list<string> $supported */
        $supported = config('app.supported_locales');
        $default = config('app.locale');

        if (! $request->headers->has('Accept-Language')) {
            return $default;
        }

        $wanted = $request->getPreferredLanguage(array_values(array_unique([$default, ...$supported])));

        return in_array($wanted, $supported, true) ? $wanted : $default;
    }
}
