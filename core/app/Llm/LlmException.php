<?php

namespace App\Llm;

use RuntimeException;
use Throwable;

/**
 * A provider call failed. `errorCode` is one of the constants below.
 */
class LlmException extends RuntimeException
{
    public const KEY_INVALID = 'key_invalid';

    public const MODEL_NOT_FOUND = 'model_not_found';

    public const RATE_LIMITED = 'provider_rate_limited';

    public const UNAVAILABLE = 'provider_unavailable';

    public const UNREACHABLE = 'provider_unreachable';

    public const ERROR = 'provider_error';

    public function __construct(
        public readonly string $errorCode,
        string $message,
        ?Throwable $previous = null,
    ) {
        parent::__construct($message, 0, $previous);
    }

    /** A short Indonesian message the app can show as-is. */
    public function userMessage(bool $userKey): string
    {
        return match ($this->errorCode) {
            self::KEY_INVALID => $userKey
                ? 'API key kamu ditolak provider. Periksa lagi di Kunci AI saya.'
                : 'Layanan AI sedang bermasalah. Coba lagi nanti.',
            self::MODEL_NOT_FOUND => $userKey
                ? 'Model yang kamu pilih tidak tersedia di provider.'
                : 'Model AI yang diatur admin tidak tersedia.',
            self::RATE_LIMITED => 'Provider AI sedang membatasi permintaan. Coba lagi sebentar.',
            self::UNAVAILABLE, self::UNREACHABLE => 'Provider AI sedang tidak bisa dihubungi. Coba lagi nanti.',
            default => 'Terjadi kesalahan di provider AI. Coba lagi.',
        };
    }
}
