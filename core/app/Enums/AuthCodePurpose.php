<?php

namespace App\Enums;

enum AuthCodePurpose: string
{
    case VerifyEmail = 'verify_email';
    case ResetPassword = 'reset_password';

    public function subject(): string
    {
        return match ($this) {
            self::VerifyEmail => __('Your Lumi email verification code'),
            self::ResetPassword => __('Your Lumi password reset code'),
        };
    }
}
