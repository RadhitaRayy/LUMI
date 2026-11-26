<?php

namespace App\Enums;

enum AuthCodePurpose: string
{
    case VerifyEmail = 'verify_email';
    case ResetPassword = 'reset_password';

    public function subject(): string
    {
        return match ($this) {
            self::VerifyEmail => 'Kode verifikasi email Lumi',
            self::ResetPassword => 'Kode reset password Lumi',
        };
    }
}
